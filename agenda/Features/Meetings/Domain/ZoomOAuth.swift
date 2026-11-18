import Foundation

/// The app's Zoom sign-in client: a user-managed General App with "Use Public Client OAuth" on, so no secret ships.
struct ZoomOAuthConfig: OAuthClientConfig, Equatable {
    /// Set to the app's client ID from the Zoom App Marketplace.
    static let app = ZoomOAuthConfig(clientID: "")

    var clientID: String

    var serviceName: String { "Zoom" }
    var isConfigured: Bool { !clientID.isEmpty }

    var authorizationEndpoint: URL { URL(string: "https://zoom.us/oauth/authorize")! }
    var tokenEndpoint: URL { URL(string: "https://zoom.us/oauth/token")! }
    var revokeEndpoint: URL? { URL(string: "https://zoom.us/oauth/revoke")! }

    /// Zoom grants the scopes chosen in the app's registration (`meeting:write:meeting`).
    var scope: String? { nil }

    var callbackScheme: String { "dayloom" }
    var redirectURI: String { "dayloom://oauth/zoom" }
}
