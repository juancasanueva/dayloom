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
        guard let http = response as? HTTPURLResponse else { throw GoogleMeetError.invalidResponse }
        return (data, http)
    }
}

/// Shows the sign-in page and returns the redirect it ends on.
protocol WebAuthorizer {
    func authorize(url: URL, callbackScheme: String) async throws -> URL
}

/// Where the Google sign-in is kept between launches.
protocol GoogleTokenStore {
    func load() -> GoogleTokens?
    func save(_ tokens: GoogleTokens) throws
    func clear()
}

/// Creates Google Meet meetings, signing in to Google the first time.
@Observable
final class GoogleMeetService {
    static let shared = GoogleMeetService(
        config: .app,
        store: KeychainGoogleTokenStore(),
        transport: URLSessionTransport(),
        authorizer: WebAuthenticationSessionAuthorizer()
    )

    static let spacesEndpoint = URL(string: "https://meet.googleapis.com/v2/spaces")!

    private(set) var isConnected: Bool

    private let config: GoogleOAuthConfig
    private let store: GoogleTokenStore
    private let transport: HTTPTransport
    private let authorizer: WebAuthorizer
    private let now: () -> Date
    private let makePKCE: () -> PKCE
    private let makeState: () -> String

    init(
        config: GoogleOAuthConfig,
        store: GoogleTokenStore,
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

    /// A new Meet space, ready to join; it isn't added to any calendar.
    func createMeeting() async throws -> MeetingLink {
        do {
            return try await createSpace(token: accessToken())
        } catch GoogleMeetError.requestFailed(status: 401) {
            // Access was removed at Google before the token expired: forget it and sign in once more.
            forget()
            return try await createSpace(token: accessToken())
        }
    }

    private func createSpace(token: String) async throws -> MeetingLink {
        var request = URLRequest(url: Self.spacesEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await transport.send(request)
        guard response.statusCode == 200 else { throw GoogleMeetError.requestFailed(status: response.statusCode) }

        struct Space: Decodable { let meetingUri: String }
        guard let space = try? JSONDecoder().decode(Space.self, from: data),
              let meeting = MeetingLink(space.meetingUri) else { throw GoogleMeetError.invalidResponse }
        return meeting
    }

    /// Revokes the sign-in at Google when it can, and forgets it either way.
    func disconnect() async {
        if let tokens = store.load() {
            _ = try? await transport.send(GoogleOAuth.revokeRequest(token: tokens.refreshToken ?? tokens.accessToken))
        }
        forget()
    }

    // MARK: Sign-in

    /// The saved token while it's fresh, otherwise a refreshed one, otherwise a new sign-in.
    private func accessToken() async throws -> String {
        guard config.isConfigured else { throw GoogleMeetError.notConfigured }

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

    /// Nil when Google refuses the refresh token, so the caller signs in again.
    private func refresh(_ refreshToken: String) async throws -> GoogleTokens? {
        let (data, response) = try await transport.send(GoogleOAuth.refreshRequest(refreshToken: refreshToken, config: config))
        if response.statusCode == 400 || response.statusCode == 401 { return nil }
        guard response.statusCode == 200 else { throw GoogleMeetError.requestFailed(status: response.statusCode) }
        let tokens = try GoogleOAuth.tokens(from: data, keeping: refreshToken, now: now())
        try remember(tokens)
        return tokens
    }

    private func signIn() async throws -> GoogleTokens {
        let pkce = makePKCE()
        let state = makeState()
        let url = GoogleOAuth.authorizationURL(config: config, pkce: pkce, state: state)

        let callback = try await authorizer.authorize(url: url, callbackScheme: config.callbackScheme)
        let code = try GoogleOAuth.code(fromCallback: callback, state: state)

        let (data, response) = try await transport.send(GoogleOAuth.tokenRequest(code: code, config: config, pkce: pkce))
        guard response.statusCode == 200 else { throw GoogleMeetError.signInFailed("error \(response.statusCode)") }
        let tokens = try GoogleOAuth.tokens(from: data, keeping: nil, now: now())
        try remember(tokens)
        return tokens
    }

    private func remember(_ tokens: GoogleTokens) throws {
        try store.save(tokens)
        isConnected = true
    }

    private func forget() {
        store.clear()
        isConnected = false
    }
}
