import Foundation
import Testing
@testable import agenda

// MARK: - Test doubles

private final class StubTransport: HTTPTransport {
    var responses: [(status: Int, body: String)] = []
    var failure: Error?
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let failure { throw failure }
        let next = responses.isEmpty ? (status: 500, body: "{}") : responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: nil, headerFields: nil)!
        return (Data(next.body.utf8), response)
    }
}

private final class StubAuthorizer: WebAuthorizer {
    /// Builds the callback from the authorization URL, so it can echo the state back.
    var respond: (URL) throws -> URL
    private(set) var calls: [(url: URL, scheme: String)] = []

    init(respond: @escaping (URL) throws -> URL) {
        self.respond = respond
    }

    func authorize(url: URL, callbackScheme: String) async throws -> URL {
        calls.append((url, callbackScheme))
        return try respond(url)
    }
}

private final class MemoryTokenStore: GoogleTokenStore {
    var tokens: GoogleTokens?
    init(_ tokens: GoogleTokens? = nil) { self.tokens = tokens }
    func load() -> GoogleTokens? { tokens }
    func save(_ tokens: GoogleTokens) throws { self.tokens = tokens }
    func clear() { tokens = nil }
}

private enum Fixture {
    static let config = GoogleOAuthConfig(clientID: "1234-abc.apps.googleusercontent.com")
    static let now = TestClock.now
    static let pkce = PKCE(verifier: "dBjftJeZ4CVP-mJ92K9qkk8C8w2y4Lm_SVWlLHcRmSM")
    static let space = #"{"name":"spaces/x1","meetingUri":"https://meet.google.com/abc-mnop-xyz","meetingCode":"abc-mnop-xyz"}"#
    static let signedIn = #"{"access_token":"access-1","refresh_token":"refresh-1","expires_in":3599,"token_type":"Bearer"}"#
    static let refreshed = #"{"access_token":"access-2","expires_in":3599,"token_type":"Bearer"}"#

    static func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    static func form(_ request: URLRequest) -> [String: String] {
        var components = URLComponents()
        components.percentEncodedQuery = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        let items = components.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    /// Answers the sign-in sheet with a code and the state it was given.
    static func approvingAuthorizer() -> StubAuthorizer {
        StubAuthorizer { url in
            let state = query(url)["state"] ?? ""
            return URL(string: "\(config.redirectURI)?state=\(state)&code=code-1")!
        }
    }

    static func service(
        store: MemoryTokenStore = MemoryTokenStore(),
        transport: StubTransport = StubTransport(),
        authorizer: StubAuthorizer = approvingAuthorizer(),
        config: GoogleOAuthConfig = config
    ) -> GoogleMeetService {
        GoogleMeetService(
            config: config,
            store: store,
            transport: transport,
            authorizer: authorizer,
            now: { now },
            makePKCE: { pkce },
            makeState: { "state-1" }
        )
    }
}

// MARK: - OAuth pieces

@Suite("Google OAuth")
struct GoogleOAuthTests {
    @Test func pkceChallengeIsTheBase64URLHashOfTheVerifier() {
        #expect(Fixture.pkce.challenge == "WRFwnLFXc-ZinZEZAeqBucuqfyqninT-yJf4w0is6rU")
    }

    @Test func randomVerifiersAreLongAndURLSafe() {
        let first = PKCE.random()
        let second = PKCE.random()
        #expect((43...128).contains(first.verifier.count))
        #expect(first.verifier.allSatisfy { $0.isLetter || $0.isNumber || "-._~".contains($0) })
        #expect(first.verifier != second.verifier)
    }

    @Test func redirectUsesTheReversedClientID() {
        #expect(Fixture.config.callbackScheme == "com.googleusercontent.apps.1234-abc")
        #expect(Fixture.config.redirectURI == "com.googleusercontent.apps.1234-abc:/oauthredirect")
        #expect(Fixture.config.isConfigured)
        #expect(!GoogleOAuthConfig(clientID: "").isConfigured)
    }

    @Test func authorizationURLAsksOnlyToCreateMeetings() {
        let url = GoogleOAuth.authorizationURL(config: Fixture.config, pkce: Fixture.pkce, state: "state-1")
        let query = Fixture.query(url)

        #expect(url.absoluteString.hasPrefix("https://accounts.google.com/o/oauth2/v2/auth?"))
        #expect(query["client_id"] == "1234-abc.apps.googleusercontent.com")
        #expect(query["redirect_uri"] == "com.googleusercontent.apps.1234-abc:/oauthredirect")
        #expect(query["response_type"] == "code")
        #expect(query["scope"] == "https://www.googleapis.com/auth/meetings.space.created")
        #expect(query["code_challenge"] == Fixture.pkce.challenge)
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["state"] == "state-1")
    }

    @Test func callbackGivesTheCodeWhenTheStateMatches() throws {
        let callback = URL(string: "\(Fixture.config.redirectURI)?state=state-1&code=code-1")!
        #expect(try GoogleOAuth.code(fromCallback: callback, state: "state-1") == "code-1")
    }

    @Test func callbackWithAnotherStateIsRejected() {
        let callback = URL(string: "\(Fixture.config.redirectURI)?state=forged&code=code-1")!
        #expect(throws: GoogleMeetError.stateMismatch) {
            try GoogleOAuth.code(fromCallback: callback, state: "state-1")
        }
    }

    @Test func declinedConsentCountsAsCancelled() {
        let callback = URL(string: "\(Fixture.config.redirectURI)?state=state-1&error=access_denied")!
        #expect(throws: GoogleMeetError.signInCancelled) {
            try GoogleOAuth.code(fromCallback: callback, state: "state-1")
        }
    }
}

// MARK: - Creating meetings

@MainActor
@Suite("Google Meet service")
struct GoogleMeetServiceTests {
    @Test func firstMeetingSignsInThenCreatesASpace() async throws {
        let store = MemoryTokenStore()
        let transport = StubTransport()
        transport.responses = [(200, Fixture.signedIn), (200, Fixture.space)]
        let authorizer = Fixture.approvingAuthorizer()
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)
        #expect(!service.isConnected)

        let meeting = try await service.createMeeting()

        #expect(meeting.provider == .googleMeet)
        #expect(meeting.url.absoluteString == "https://meet.google.com/abc-mnop-xyz")

        #expect(authorizer.calls.count == 1)
        #expect(authorizer.calls.first?.scheme == "com.googleusercontent.apps.1234-abc")

        #expect(transport.requests.count == 2)
        let exchange = transport.requests[0]
        #expect(exchange.url?.absoluteString == "https://oauth2.googleapis.com/token")
        #expect(exchange.httpMethod == "POST")
        #expect(exchange.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(Fixture.form(exchange) == [
            "grant_type": "authorization_code",
            "code": "code-1",
            "client_id": "1234-abc.apps.googleusercontent.com",
            "redirect_uri": "com.googleusercontent.apps.1234-abc:/oauthredirect",
            "code_verifier": Fixture.pkce.verifier,
        ])

        let create = transport.requests[1]
        #expect(create.url?.absoluteString == "https://meet.googleapis.com/v2/spaces")
        #expect(create.httpMethod == "POST")
        #expect(create.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")

        #expect(store.tokens == GoogleTokens(
            accessToken: "access-1",
            refreshToken: "refresh-1",
            expiresAt: Fixture.now.addingTimeInterval(3599)
        ))
        #expect(service.isConnected)
    }

    @Test func aSavedSignInIsReused() async throws {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.responses = [(200, Fixture.space)]
        let authorizer = Fixture.approvingAuthorizer()
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)
        #expect(service.isConnected)

        _ = try await service.createMeeting()

        #expect(authorizer.calls.isEmpty)
        #expect(transport.requests.map(\.url?.absoluteString) == ["https://meet.googleapis.com/v2/spaces"])
    }

    @Test func anExpiredSignInIsRefreshedAndKeepsItsRefreshToken() async throws {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: Fixture.now.addingTimeInterval(-5)))
        let transport = StubTransport()
        transport.responses = [(200, Fixture.refreshed), (200, Fixture.space)]
        let authorizer = Fixture.approvingAuthorizer()
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)

        _ = try await service.createMeeting()

        #expect(authorizer.calls.isEmpty)
        #expect(Fixture.form(transport.requests[0]) == [
            "grant_type": "refresh_token",
            "refresh_token": "refresh-1",
            "client_id": "1234-abc.apps.googleusercontent.com",
        ])
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer access-2")
        #expect(store.tokens == GoogleTokens(accessToken: "access-2", refreshToken: "refresh-1", expiresAt: Fixture.now.addingTimeInterval(3599)))
    }

    @Test func aRevokedSignInAsksToSignInAgain() async throws {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "access-0", refreshToken: "revoked", expiresAt: Fixture.now.addingTimeInterval(-5)))
        let transport = StubTransport()
        transport.responses = [(400, #"{"error":"invalid_grant"}"#), (200, Fixture.signedIn), (200, Fixture.space)]
        let authorizer = Fixture.approvingAuthorizer()
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)

        _ = try await service.createMeeting()

        #expect(authorizer.calls.count == 1)
        #expect(store.tokens?.refreshToken == "refresh-1")
    }

    @Test func accessRemovedAtGoogleAsksToSignInAgain() async throws {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "removed", refreshToken: "removed", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.responses = [(401, #"{"error":{"status":"UNAUTHENTICATED"}}"#), (200, Fixture.signedIn), (200, Fixture.space)]
        let authorizer = Fixture.approvingAuthorizer()
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)

        let meeting = try await service.createMeeting()

        #expect(meeting.provider == .googleMeet)
        #expect(authorizer.calls.count == 1)
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
        #expect(store.tokens?.accessToken == "access-1")
    }

    @Test func cancellingSignInChangesNothing() async {
        let store = MemoryTokenStore()
        let transport = StubTransport()
        let authorizer = StubAuthorizer { _ in throw GoogleMeetError.signInCancelled }
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)

        await #expect(throws: GoogleMeetError.signInCancelled) {
            try await service.createMeeting()
        }
        #expect(transport.requests.isEmpty)
        #expect(store.tokens == nil)
        #expect(!service.isConnected)
    }

    @Test func withoutAClientIDNothingIsSent() async {
        let transport = StubTransport()
        let authorizer = Fixture.approvingAuthorizer()
        let service = Fixture.service(transport: transport, authorizer: authorizer, config: GoogleOAuthConfig(clientID: ""))

        #expect(!service.isConfigured)
        await #expect(throws: GoogleMeetError.notConfigured) {
            try await service.createMeeting()
        }
        #expect(authorizer.calls.isEmpty)
        #expect(transport.requests.isEmpty)
    }

    @Test func aRefusedRequestReportsItsStatus() async {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.responses = [(403, #"{"error":{"status":"PERMISSION_DENIED"}}"#)]
        let service = Fixture.service(store: store, transport: transport)

        await #expect(throws: GoogleMeetError.requestFailed(status: 403)) {
            try await service.createMeeting()
        }
        #expect(store.tokens != nil) // A refused request isn't a sign-out.
    }

    @Test func disconnectRevokesAndForgetsTheSignIn() async {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.responses = [(200, "")]
        let service = Fixture.service(store: store, transport: transport)

        await service.disconnect()

        #expect(transport.requests.first?.url?.absoluteString == "https://oauth2.googleapis.com/revoke")
        #expect(Fixture.form(transport.requests[0]) == ["token": "refresh-1"])
        #expect(store.tokens == nil)
        #expect(!service.isConnected)
    }

    @Test func disconnectForgetsTheSignInEvenOffline() async {
        let store = MemoryTokenStore(GoogleTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.failure = URLError(.notConnectedToInternet)
        let service = Fixture.service(store: store, transport: transport)

        await service.disconnect()

        #expect(store.tokens == nil)
        #expect(!service.isConnected)
    }
}

// MARK: - Keychain

@MainActor
@Suite("Google sign-in Keychain storage")
struct KeychainGoogleTokenStoreTests {
    @Test func savesLoadsAndClears() throws {
        let store = KeychainGoogleTokenStore(service: "com.juancasanueva.agenda.tests.\(UUID().uuidString)")
        defer { store.clear() }
        let tokens = GoogleTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(store.load() == nil)
        try store.save(tokens)
        #expect(store.load() == tokens)
        try store.save(GoogleTokens(accessToken: "access-2", refreshToken: "refresh-1", expiresAt: tokens.expiresAt))
        #expect(store.load()?.accessToken == "access-2")
        store.clear()
        #expect(store.load() == nil)
    }
}
