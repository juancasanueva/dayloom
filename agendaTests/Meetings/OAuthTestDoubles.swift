import Foundation
@testable import agenda

final class StubTransport: HTTPTransport {
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

final class StubAuthorizer: WebAuthorizer {
    /// Builds the callback from the authorization URL, so it can echo the state back.
    var respond: (URL) throws -> URL
    private(set) var calls: [(url: URL, scheme: String)] = []

    init(respond: @escaping (URL) throws -> URL) {
        self.respond = respond
    }

    /// Answers the sign-in sheet with `code-1` and the state it was given.
    static func approving(redirectURI: String) -> StubAuthorizer {
        StubAuthorizer { url in
            let state = OAuthFixture.query(url)["state"] ?? ""
            return URL(string: "\(redirectURI)?state=\(state)&code=code-1")!
        }
    }

    func authorize(url: URL, callbackScheme: String) async throws -> URL {
        calls.append((url, callbackScheme))
        return try respond(url)
    }
}

final class MemoryTokenStore: TokenStore {
    var tokens: OAuthTokens?
    init(_ tokens: OAuthTokens? = nil) { self.tokens = tokens }
    func load() -> OAuthTokens? { tokens }
    func save(_ tokens: OAuthTokens) throws { self.tokens = tokens }
    func clear() { tokens = nil }
}

enum OAuthFixture {
    static let now = TestClock.now
    static let pkce = PKCE(verifier: "dBjftJeZ4CVP-mJ92K9qkk8C8w2y4Lm_SVWlLHcRmSM")

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

    static func json(_ request: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
    }
}
