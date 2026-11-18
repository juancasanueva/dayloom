import Foundation

/// Creates Zoom meetings for a task, signing in to Zoom the first time.
final class ZoomMeetingService {
    static let shared = ZoomMeetingService(session: OAuthSession(
        config: ZoomOAuthConfig.app,
        store: KeychainTokenStore.zoom,
        transport: URLSessionTransport(),
        authorizer: WebAuthenticationSessionAuthorizer()
    ))

    static let meetingsEndpoint = URL(string: "https://api.zoom.us/v2/users/me/meetings")!

    let session: OAuthSession

    init(session: OAuthSession) {
        self.session = session
    }

    convenience init(
        config: ZoomOAuthConfig,
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

    /// A meeting named after the task: scheduled at its time when it has one, otherwise with no fixed time.
    func createMeeting(topic: String, start: Date?, duration: TimeInterval) async throws -> MeetingLink {
        let body = try JSONSerialization.data(
            withJSONObject: Self.meetingFields(topic: topic, start: start, duration: duration),
            options: .sortedKeys
        )
        let (data, response) = try await session.send { token in
            var request = URLRequest(url: Self.meetingsEndpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            return request
        }
        guard response.statusCode == 201 || response.statusCode == 200 else {
            throw MeetingServiceError.requestFailed(service: "Zoom", status: response.statusCode)
        }

        struct Meeting: Decodable { let join_url: String }
        guard let meeting = try? JSONDecoder().decode(Meeting.self, from: data),
              let link = MeetingLink(meeting.join_url) else { throw MeetingServiceError.invalidResponse(service: "Zoom") }
        return link
    }

    func disconnect() async {
        await session.disconnect()
    }

    /// Zoom meeting types: 2 is scheduled, 3 is recurring with no fixed time (its link stays valid).
    static func meetingFields(topic: String, start: Date?, duration: TimeInterval) -> [String: Any] {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        var fields: [String: Any] = ["topic": trimmed.isEmpty ? "Meeting" : String(trimmed.prefix(200))]
        if let start {
            fields["type"] = 2
            fields["start_time"] = start.formatted(.iso8601) // UTC, such as 2026-11-17T09:30:00Z.
            fields["duration"] = max(1, Int((duration / 60).rounded()))
        } else {
            fields["type"] = 3
        }
        return fields
    }
}
