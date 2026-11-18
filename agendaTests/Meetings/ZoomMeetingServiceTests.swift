import Foundation
import Testing
@testable import agenda

private enum Fixture {
    static let config = ZoomOAuthConfig(clientID: "zoomClient123")
    static let now = OAuthFixture.now
    static let signedIn = #"{"access_token":"zoom-access-1","refresh_token":"zoom-refresh-1","expires_in":3599,"token_type":"bearer","scope":"meeting:write:meeting"}"#
    static let refreshed = #"{"access_token":"zoom-access-2","refresh_token":"zoom-refresh-2","expires_in":3599,"token_type":"bearer"}"#
    static let meeting = #"{"id":81234567890,"join_url":"https://us05web.zoom.us/j/81234567890?pwd=AbC123.1","topic":"Standup"}"#

    static func service(
        store: MemoryTokenStore = MemoryTokenStore(),
        transport: StubTransport = StubTransport(),
        authorizer: StubAuthorizer = .approving(redirectURI: config.redirectURI),
        config: ZoomOAuthConfig = config
    ) -> ZoomMeetingService {
        ZoomMeetingService(
            config: config,
            store: store,
            transport: transport,
            authorizer: authorizer,
            now: { now },
            makePKCE: { OAuthFixture.pkce },
            makeState: { "state-1" }
        )
    }
}

@Suite("Zoom OAuth")
struct ZoomOAuthTests {
    @Test func signInUsesZoomsPublicClientFlow() {
        let url = OAuth.authorizationURL(config: Fixture.config, pkce: OAuthFixture.pkce, state: "state-1")
        let query = OAuthFixture.query(url)

        #expect(url.absoluteString.hasPrefix("https://zoom.us/oauth/authorize?"))
        #expect(query == [
            "client_id": "zoomClient123",
            "redirect_uri": "http://127.0.0.1:47823/callback",
            "response_type": "code",
            "code_challenge": OAuthFixture.pkce.challenge,
            "code_challenge_method": "S256",
            "state": "state-1",
        ])
    }

    @Test func zoomUsesTheRegisteredPublicClient() {
        #expect(ZoomOAuthConfig.app.clientID == "D8b6gHTwRe62LTWG3OF7OQ")
        #expect(ZoomOAuthConfig.app.redirectURI == "http://127.0.0.1:47823/callback")
    }

    @Test func aClientIDIsNeeded() {
        #expect(Fixture.config.isConfigured)
        #expect(!ZoomOAuthConfig(clientID: "").isConfigured)
    }
}

@MainActor
@Suite("Zoom meeting service")
struct ZoomMeetingServiceTests {
    @Test func firstMeetingSignsInThenSchedulesItAtTheTasksTime() async throws {
        let store = MemoryTokenStore()
        let transport = StubTransport()
        transport.responses = [(200, Fixture.signedIn), (201, Fixture.meeting)]
        let authorizer = StubAuthorizer.approving(redirectURI: Fixture.config.redirectURI)
        let service = Fixture.service(store: store, transport: transport, authorizer: authorizer)

        let meeting = try await service.createMeeting(
            topic: "Standup",
            start: TestClock.date(2026, 11, 17, 9, 30),
            duration: 45 * 60
        )

        #expect(meeting.provider == .zoom)
        #expect(meeting.url.absoluteString == "https://us05web.zoom.us/j/81234567890?pwd=AbC123.1")
        #expect(authorizer.calls.count == 1)

        let exchange = transport.requests[0]
        #expect(exchange.url?.absoluteString == "https://zoom.us/oauth/token")
        #expect(exchange.value(forHTTPHeaderField: "Authorization") == nil) // No client secret.
        #expect(OAuthFixture.form(exchange) == [
            "grant_type": "authorization_code",
            "code": "code-1",
            "client_id": "zoomClient123",
            "redirect_uri": "http://127.0.0.1:47823/callback",
            "code_verifier": OAuthFixture.pkce.verifier,
        ])

        let create = transport.requests[1]
        #expect(create.url?.absoluteString == "https://api.zoom.us/v2/users/me/meetings")
        #expect(create.httpMethod == "POST")
        #expect(create.value(forHTTPHeaderField: "Authorization") == "Bearer zoom-access-1")
        #expect(create.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = OAuthFixture.json(create)
        #expect(body["topic"] as? String == "Standup")
        #expect(body["type"] as? Int == 2)
        #expect(body["start_time"] as? String == "2026-11-17T09:30:00Z")
        #expect(body["duration"] as? Int == 45)

        #expect(store.tokens == OAuthTokens(accessToken: "zoom-access-1", refreshToken: "zoom-refresh-1", expiresAt: Fixture.now.addingTimeInterval(3599)))
        #expect(service.isConnected)
    }

    @Test func aTaskWithoutATimeGetsAMeetingWithNoFixedTime() async throws {
        let store = MemoryTokenStore(OAuthTokens(accessToken: "zoom-access-1", refreshToken: "zoom-refresh-1", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.responses = [(201, Fixture.meeting)]
        let service = Fixture.service(store: store, transport: transport)

        _ = try await service.createMeeting(topic: "  ", start: nil, duration: 60 * 60)

        let body = OAuthFixture.json(transport.requests[0])
        #expect(body["topic"] as? String == "Meeting")
        #expect(body["type"] as? Int == 3)
        #expect(body["start_time"] == nil)
        #expect(body["duration"] == nil)
    }

    @Test func refreshingSavesZoomsNewRefreshToken() async throws {
        let store = MemoryTokenStore(OAuthTokens(accessToken: "zoom-access-1", refreshToken: "zoom-refresh-1", expiresAt: Fixture.now.addingTimeInterval(-5)))
        let transport = StubTransport()
        transport.responses = [(200, Fixture.refreshed), (201, Fixture.meeting)]
        let service = Fixture.service(store: store, transport: transport)

        _ = try await service.createMeeting(topic: "Standup", start: nil, duration: 3600)

        #expect(OAuthFixture.form(transport.requests[0]) == [
            "grant_type": "refresh_token",
            "refresh_token": "zoom-refresh-1",
            "client_id": "zoomClient123",
        ])
        #expect(store.tokens?.refreshToken == "zoom-refresh-2")
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer zoom-access-2")
    }

    @Test func aRefusedMeetingReportsZoomsStatus() async {
        let store = MemoryTokenStore(OAuthTokens(accessToken: "zoom-access-1", refreshToken: "zoom-refresh-1", expiresAt: Fixture.now.addingTimeInterval(600)))
        let transport = StubTransport()
        transport.responses = [(400, #"{"code":4711,"message":"Invalid access token, does not contain scopes"}"#)]
        let service = Fixture.service(store: store, transport: transport)

        await #expect(throws: MeetingServiceError.requestFailed(service: "Zoom", status: 400)) {
            try await service.createMeeting(topic: "Standup", start: nil, duration: 3600)
        }
    }

    @Test func withoutAClientIDNothingIsSent() async {
        let transport = StubTransport()
        let service = Fixture.service(transport: transport, config: ZoomOAuthConfig(clientID: ""))

        await #expect(throws: MeetingServiceError.notConfigured(service: "Zoom")) {
            try await service.createMeeting(topic: "Standup", start: nil, duration: 3600)
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func zoomKeepsItsOwnKeychainItem() {
        #expect(KeychainTokenStore.zoom.service == "com.juancasanueva.agenda.zoom-oauth")
        #expect(KeychainTokenStore.zoom.service != KeychainTokenStore.google.service)
    }
}
