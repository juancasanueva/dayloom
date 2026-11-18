import Foundation

/// The app's Zoom sign-in client: a user-managed General App with "Use Public Client OAuth" on, so no secret ships.
/// Zoom only redirects to HTTPS or a loopback address, so the reply comes back to `LoopbackAuthorizer`.
struct ZoomOAuthConfig: OAuthClientConfig, Equatable {
    /// The app's public client ID from the Zoom App Marketplace (not the client ID that needs a secret).
    static let app = ZoomOAuthConfig(clientID: "D8b6gHTwRe62LTWG3OF7OQ")

    /// Registered in Zoom as the PKCE redirect, `http://127.0.0.1:47823/callback`.
    static let loopbackPort: UInt16 = 47823
    static let callbackPath = "/callback"

    var clientID: String

    var serviceName: String { "Zoom" }
    var isConfigured: Bool { !clientID.isEmpty }

    var authorizationEndpoint: URL { URL(string: "https://zoom.us/oauth/authorize")! }
    var tokenEndpoint: URL { URL(string: "https://zoom.us/oauth/token")! }
    var revokeEndpoint: URL? { URL(string: "https://zoom.us/oauth/revoke")! }

    /// Zoom grants the scopes chosen in the app's registration (`meeting:write:meeting`).
    var scope: String? { nil }

    var callbackScheme: String { "http" }
    var redirectURI: String { "http://127.0.0.1:\(Self.loopbackPort)\(Self.callbackPath)" }
}
