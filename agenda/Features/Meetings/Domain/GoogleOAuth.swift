import CryptoKit
import Foundation

/// The app's Google sign-in client. Native-app client IDs are public identifiers, not secrets.
struct GoogleOAuthConfig: Equatable {
    /// Set to the "iOS" OAuth client ID from Google Cloud Console, such as `1234-abc.apps.googleusercontent.com`.
    static let app = GoogleOAuthConfig(clientID: "404557996424-cv2htro98ambvmjn7mn8jeejhtskrpdd.apps.googleusercontent.com")

    /// Only lets the app create meetings; it can't read the user's calendar, mail or other meetings.
    static let scope = "https://www.googleapis.com/auth/meetings.space.created"

    var clientID: String

    var isConfigured: Bool { clientID.hasSuffix(".apps.googleusercontent.com") }

    /// The client ID reversed (`com.googleusercontent.apps.1234-abc`), which Google accepts as a redirect scheme.
    var callbackScheme: String { clientID.split(separator: ".").reversed().joined(separator: ".") }
    var redirectURI: String { callbackScheme + ":/oauthredirect" }
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

/// A Google sign-in: the short-lived access token and the refresh token that renews it.
struct GoogleTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    /// Usable for at least another minute, so a request doesn't expire in flight.
    func isFresh(at now: Date) -> Bool {
        expiresAt.timeIntervalSince(now) > 60
    }
}

enum GoogleMeetError: Error, Equatable, LocalizedError {
    case notConfigured
    case signInCancelled
    case signInFailed(String)
    case stateMismatch
    case requestFailed(status: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Google sign-in isn't set up in this build."
        case .signInCancelled: "Google sign-in was cancelled."
        case .signInFailed(let reason): "Google sign-in failed (\(reason))."
        case .stateMismatch: "Google sign-in couldn't be verified. Try again."
        case .requestFailed(let status): "Google couldn't create the meeting (error \(status))."
        case .invalidResponse: "Google sent an unexpected reply."
        }
    }
}

/// The requests and replies of Google's OAuth flow for native apps.
enum GoogleOAuth {
    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let revokeEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!

    static func authorizationURL(config: GoogleOAuthConfig, pkce: PKCE, state: String) -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    /// The code from the sign-in redirect, once its state proves the redirect answers this sign-in.
    static func code(fromCallback url: URL, state: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard value("state") == state else { throw GoogleMeetError.stateMismatch }
        if let error = value("error") {
            throw error == "access_denied" ? GoogleMeetError.signInCancelled : GoogleMeetError.signInFailed(error)
        }
        guard let code = value("code"), !code.isEmpty else { throw GoogleMeetError.invalidResponse }
        return code
    }

    static func tokenRequest(code: String, config: GoogleOAuthConfig, pkce: PKCE) -> URLRequest {
        formRequest(tokenEndpoint, [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("client_id", config.clientID),
            ("redirect_uri", config.redirectURI),
            ("code_verifier", pkce.verifier),
        ])
    }

    static func refreshRequest(refreshToken: String, config: GoogleOAuthConfig) -> URLRequest {
        formRequest(tokenEndpoint, [
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", config.clientID),
        ])
    }

    static func revokeRequest(token: String) -> URLRequest {
        formRequest(revokeEndpoint, [("token", token)])
    }

    /// Reads a token reply. A refresh reply has no refresh token, so the previous one is kept.
    static func tokens(from data: Data, keeping previousRefreshToken: String?, now: Date) throws -> GoogleTokens {
        struct Reply: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw GoogleMeetError.invalidResponse }
        return GoogleTokens(
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
