import Foundation

/// The video-call service a meeting link belongs to.
enum MeetingProvider: String, CaseIterable, Hashable {
    case googleMeet
    case zoom
    case teams
    case webex
    /// Any other web link used as a video call.
    case other

    var name: String {
        switch self {
        case .googleMeet: "Google Meet"
        case .zoom: "Zoom"
        case .teams: "Teams"
        case .webex: "Webex"
        case .other: "Video Call"
        }
    }

    /// Works out the service from a link's host, such as `us02web.zoom.us`.
    init(host: String) {
        let host = host.lowercased()
        func matches(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }

        if host == "meet.google.com" {
            self = .googleMeet
        } else if matches("zoom.us") || matches("zoomgov.com") {
            self = .zoom
        } else if host == "teams.microsoft.com" || host == "teams.live.com" || host == "teams.cloud.microsoft" {
            self = .teams
        } else if matches("webex.com") {
            self = .webex
        } else {
            self = .other
        }
    }
}

/// A web link to a video call, and the service it belongs to.
struct MeetingLink: Hashable {
    let url: URL
    let provider: MeetingProvider

    /// Reads a pasted link. A missing scheme is taken as `https`; anything that isn't a web link is rejected.
    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }

        let candidate = URL(string: trimmed)?.scheme == nil ? "https://" + trimmed : trimmed
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host(), host.contains(".") else { return nil }

        self.url = url
        self.provider = MeetingProvider(host: host)
    }

    var joinTitle: String { provider == .other ? "Join Call" : "Join \(provider.name)" }

    /// The first link to a known service in an event's text, such as its URL, location or notes.
    /// Ordinary links, like a shared document, are not meetings.
    static func find(in texts: [String?]) -> MeetingLink? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }

        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let url = match.url, let link = MeetingLink(url.absoluteString), link.provider != .other {
                    return link
                }
            }
        }
        return nil
    }

    /// A link that opens the service's desktop app directly, when the service has one.
    var appURL: URL? {
        switch provider {
        case .zoom:
            // Only numbered meetings (`/j/<id>`) can be handed to the app; personal links stay in the browser.
            let parts = url.pathComponents
            guard parts.count >= 3, parts[1] == "j", parts[2].allSatisfy(\.isNumber) else { return nil }
            var components = URLComponents()
            components.scheme = "zoommtg"
            components.host = "zoom.us"
            components.path = "/join"
            components.queryItems = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: parts[2])]
            if let password = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "pwd" })?.value {
                components.queryItems?.append(URLQueryItem(name: "pwd", value: password))
            }
            return components.url
        case .teams:
            // Work and school meeting links keep their path under the `msteams:` scheme.
            guard url.host()?.lowercased() == "teams.microsoft.com", url.path(percentEncoded: true).hasPrefix("/l/") else { return nil }
            var link = "msteams:" + url.path(percentEncoded: true)
            if let query = url.query(percentEncoded: true) { link += "?" + query }
            return URL(string: link)
        case .googleMeet, .webex, .other:
            return nil
        }
    }
}
