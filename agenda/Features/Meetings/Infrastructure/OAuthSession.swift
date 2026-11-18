import Foundation
import Observation

/// Sends an HTTP request; swapped for a stub in tests.
protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    var session: URLSession = .shared

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Shows the sign-in page and returns the redirect it ends on.
protocol WebAuthorizer {
    func authorize(url: URL, callbackScheme: String) async throws -> URL
}

/// Where a sign-in is kept between launches.
protocol TokenStore {
    func load() -> OAuthTokens?
    func save(_ tokens: OAuthTokens) throws
    func clear()
}

/// One service's sign-in: reuses the saved one, refreshes it, or asks the user to sign in.
@Observable
final class OAuthSession {
    private(set) var isConnected: Bool

    let config: any OAuthClientConfig
    private let store: TokenStore
    private let transport: HTTPTransport
    private let authorizer: WebAuthorizer
    private let now: () -> Date
    private let makePKCE: () -> PKCE
    private let makeState: () -> String

    init(
        config: any OAuthClientConfig,
        store: TokenStore,
        transport: HTTPTransport,
        authorizer: WebAuthorizer,
        now: @escaping () -> Date = Date.init,
        makePKCE: @escaping () -> PKCE = PKCE.random,
        makeState: @escaping () -> String = PKCE.randomToken
    ) {
        self.config = config
        self.store = store
        self.transport = transport
        self.authorizer = authorizer
        self.now = now
        self.makePKCE = makePKCE
        self.makeState = makeState
        self.isConnected = store.load() != nil
    }

    var isConfigured: Bool { config.isConfigured }
    var serviceName: String { config.serviceName }

    /// Sends a request built with the user's access token. If the service says the token is no
    /// longer valid (401), for example because access was removed, the user signs in once more.
    func send(_ makeRequest: (_ accessToken: String) -> URLRequest) async throws -> (Data, HTTPURLResponse) {
        let first = try await transport.send(makeRequest(accessToken()))
        guard first.1.statusCode == 401 else { return first }
        forget()
        return try await transport.send(makeRequest(accessToken()))
    }

    /// Revokes the sign-in at the service when it can, and forgets it either way.
    func disconnect() async {
        if let tokens = store.load(), let endpoint = config.revokeEndpoint {
            _ = try? await transport.send(OAuth.revokeRequest(token: tokens.refreshToken ?? tokens.accessToken, endpoint: endpoint))
        }
        forget()
    }

    // MARK: Sign-in

    /// The saved token while it's fresh, otherwise a refreshed one, otherwise a new sign-in.
    private func accessToken() async throws -> String {
        guard config.isConfigured else { throw MeetingServiceError.notConfigured(service: serviceName) }

        if let saved = store.load() {
            if saved.isFresh(at: now()) { return saved.accessToken }
            if let refreshToken = saved.refreshToken, let refreshed = try await refresh(refreshToken) {
                return refreshed.accessToken
            }
            // The refresh token was revoked or expired: start over.
            forget()
        }
        return try await signIn().accessToken
    }

    /// Nil when the service refuses the refresh token, so the caller signs in again.
    private func refresh(_ refreshToken: String) async throws -> OAuthTokens? {
        let (data, response) = try await transport.send(OAuth.refreshRequest(refreshToken: refreshToken, config: config))
        if response.statusCode == 400 || response.statusCode == 401 { return nil }
        guard response.statusCode == 200 else {
            throw MeetingServiceError.requestFailed(service: serviceName, status: response.statusCode)
        }
        let tokens = try OAuth.tokens(from: data, keeping: refreshToken, now: now(), service: serviceName)
        try remember(tokens)
        return tokens
    }

    private func signIn() async throws -> OAuthTokens {
        let pkce = makePKCE()
        let state = makeState()
        let url = OAuth.authorizationURL(config: config, pkce: pkce, state: state)

        let callback: URL
        do {
            callback = try await authorizer.authorize(url: url, callbackScheme: config.callbackScheme)
        } catch MeetingServiceError.signInSheetFailed(let reason) {
            // Name the service, as before the sign-in code was shared.
            throw MeetingServiceError.signInFailed(service: serviceName, reason: reason)
        }
        let code = try OAuth.code(fromCallback: callback, state: state, service: serviceName)

        let (data, response) = try await transport.send(OAuth.tokenRequest(code: code, config: config, pkce: pkce))
        guard response.statusCode == 200 else {
            throw MeetingServiceError.signInFailed(service: serviceName, reason: "error \(response.statusCode)")
        }
        let tokens = try OAuth.tokens(from: data, keeping: nil, now: now(), service: serviceName)
        try remember(tokens)
        return tokens
    }

    private func remember(_ tokens: OAuthTokens) throws {
        try store.save(tokens)
        isConnected = true
    }

    private func forget() {
        store.clear()
        isConnected = false
    }
}
