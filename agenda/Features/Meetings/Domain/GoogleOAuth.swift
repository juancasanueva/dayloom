import Foundation

/// The app's Google sign-in client: an "iOS" OAuth client from Google Cloud Console.
struct GoogleOAuthConfig: OAuthClientConfig, Equatable {
    static let app = GoogleOAuthConfig(clientID: "404557996424-cv2htro98ambvmjn7mn8jeejhtskrpdd.apps.googleusercontent.com")

    var clientID: String

    var serviceName: String { "Google" }
    var isConfigured: Bool { clientID.hasSuffix(".apps.googleusercontent.com") }

    var authorizationEndpoint: URL { URL(string: "https://accounts.google.com/o/oauth2/v2/auth")! }
    var tokenEndpoint: URL { URL(string: "https://oauth2.googleapis.com/token")! }
    var revokeEndpoint: URL? { URL(string: "https://oauth2.googleapis.com/revoke")! }

    /// Only lets the app create meetings; it can't read the user's calendar, mail or other meetings.
    var scope: String? { "https://www.googleapis.com/auth/meetings.space.created" }

    /// The client ID reversed (`com.googleusercontent.apps.1234-abc`), which Google accepts as a redirect scheme.
    var callbackScheme: String { clientID.split(separator: ".").reversed().joined(separator: ".") }
    var redirectURI: String { callbackScheme + ":/oauthredirect" }
}
