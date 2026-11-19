import CryptoKit
import Foundation

/// A video-call service's sign-in settings for this app. Native-app client IDs are public identifiers, not secrets.
protocol OAuthClientConfig {
    /// The name used in messages, such as "Google".
    var serviceName: String { get }
    var clientID: String { get }
    var isConfigured: Bool { get }
    var authorizationEndpoint: URL { get }
    var tokenEndpoint: URL { get }
    var revokeEndpoint: URL? { get }
    /// Nil when the service takes the scopes from the app's registration instead of the request.
    var scope: String? { get }
    var callbackScheme: String { get }
    var redirectURI: String { get }
}

/// Proof Key for Code Exchange: the sign-in code is only usable by whoever holds the verifier.
struct PKCE: Equatable {
    let verifier: String
    let challenge: String

    init(verifier: String) {
        self.verifier = verifier
        self.challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    static func random() -> PKCE {
        PKCE(verifier: randomToken())
    }

    /// 32 random bytes, base64url: 43 characters from the URL-safe alphabet.
    static func randomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }).base64URLEncoded
    }
}

/// A sign-in: the short-lived access token and the refresh token that renews it.
struct OAuthTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    /// Usable for at least another minute, so a request doesn't expire in flight.
    func isFresh(at now: Date) -> Bool {
        expiresAt.timeIntervalSince(now) > 60
    }
}

enum MeetingServiceError: Error, Equatable, LocalizedError {
    case notConfigured(service: String)
    case signInCancelled
    case signInFailed(service: String, reason: String)
    /// The system sign-in sheet itself failed, before any service answered.
    case signInSheetFailed(reason: String)
    case stateMismatch(service: String)
    case requestFailed(service: String, status: Int)
    case invalidResponse(service: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let service): String(appLocalized: "\(service) sign-in isn't set up in this build.")
        case .signInCancelled: String(appLocalized: "Sign-in was cancelled.")
        case .signInFailed(let service, let reason): String(appLocalized: "\(service) sign-in failed (\(reason)).")
        case .signInSheetFailed(let reason): String(appLocalized: "The sign-in sheet failed (\(reason)).")
        case .stateMismatch(let service): String(appLocalized: "\(service) sign-in couldn't be verified. Try again.")
        case .requestFailed(let service, let status): String(appLocalized: "\(service) couldn't create the meeting (error \(status)).")
        case .invalidResponse(let service): String(appLocalized: "\(service) sent an unexpected reply.")
        }
    }
}

/// The requests and replies of the OAuth authorization-code flow with PKCE, for native apps.
enum OAuth {
    static func authorizationURL(config: some OAuthClientConfig, pkce: PKCE, state: String) -> URL {
        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
        ]
        if let scope = config.scope {
            items.append(URLQueryItem(name: "scope", value: scope))
        }
        items += [
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        components.queryItems = items
        return components.url!
    }

    /// The code from the sign-in redirect, once its state proves the redirect answers this sign-in.
    static func code(fromCallback url: URL, state: String, service: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard value("state") == state else { throw MeetingServiceError.stateMismatch(service: service) }
        if let error = value("error") {
            throw error == "access_denied"
                ? MeetingServiceError.signInCancelled
                : MeetingServiceError.signInFailed(service: service, reason: error)
        }
        guard let code = value("code"), !code.isEmpty else { throw MeetingServiceError.invalidResponse(service: service) }
        return code
    }

    static func tokenRequest(code: String, config: some OAuthClientConfig, pkce: PKCE) -> URLRequest {
        formRequest(config.tokenEndpoint, [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("client_id", config.clientID),
            ("redirect_uri", config.redirectURI),
            ("code_verifier", pkce.verifier),
        ])
    }

    static func refreshRequest(refreshToken: String, config: some OAuthClientConfig) -> URLRequest {
        formRequest(config.tokenEndpoint, [
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", config.clientID),
        ])
    }

    static func revokeRequest(token: String, endpoint: URL) -> URLRequest {
        formRequest(endpoint, [("token", token)])
    }

    /// Reads a token reply. A refresh reply may omit the refresh token, in which case the previous one is kept.
    static func tokens(from data: Data, keeping previousRefreshToken: String?, now: Date, service: String) throws -> OAuthTokens {
        struct Reply: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
            throw MeetingServiceError.invalidResponse(service: service)
        }
        return OAuthTokens(
            accessToken: reply.access_token,
            refreshToken: reply.refresh_token ?? previousRefreshToken,
            expiresAt: now.addingTimeInterval(reply.expires_in)
        )
    }

    private static func formRequest(_ url: URL, _ fields: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(fields.map { "\($0.0)=\(formEncode($0.1))" }.joined(separator: "&").utf8)
        return request
    }

    /// Form values escape everything but unreserved characters, so `+`, `/` and `=` survive.
    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
