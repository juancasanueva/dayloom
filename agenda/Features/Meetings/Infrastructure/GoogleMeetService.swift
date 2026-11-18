import Foundation

/// Creates Google Meet meetings, signing in to Google the first time.
final class GoogleMeetService {
    static let shared = GoogleMeetService(session: OAuthSession(
        config: GoogleOAuthConfig.app,
        store: KeychainTokenStore.google,
        transport: URLSessionTransport(),
        authorizer: WebAuthenticationSessionAuthorizer()
    ))

    static let spacesEndpoint = URL(string: "https://meet.googleapis.com/v2/spaces")!

    let session: OAuthSession

    init(session: OAuthSession) {
        self.session = session
    }

    convenience init(
        config: GoogleOAuthConfig,
        store: TokenStore,
        transport: HTTPTransport,
        authorizer: WebAuthorizer,
        now: @escaping () -> Date = Date.init,
        makePKCE: @escaping () -> PKCE = PKCE.random,
        makeState: @escaping () -> String = PKCE.randomToken
    ) {
        self.init(session: OAuthSession(
            config: config, store: store, transport: transport, authorizer: authorizer,
            now: now, makePKCE: makePKCE, makeState: makeState
        ))
    }

    var isConfigured: Bool { session.isConfigured }
    var isConnected: Bool { session.isConnected }

    /// A new Meet space, ready to join; it isn't added to any calendar.
    func createMeeting() async throws -> MeetingLink {
        let (data, response) = try await session.send { token in
            var request = URLRequest(url: Self.spacesEndpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)
            return request
        }
        guard response.statusCode == 200 else {
            throw MeetingServiceError.requestFailed(service: "Google", status: response.statusCode)
        }

        struct Space: Decodable { let meetingUri: String }
        guard let space = try? JSONDecoder().decode(Space.self, from: data),
              let meeting = MeetingLink(space.meetingUri) else { throw MeetingServiceError.invalidResponse(service: "Google") }
        return meeting
    }

    func disconnect() async {
        await session.disconnect()
    }
}
