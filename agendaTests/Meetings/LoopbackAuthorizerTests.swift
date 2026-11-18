import Foundation
import Testing
@testable import agenda

/// Drives the real listener: the "browser" is a URLSession request to the loopback redirect.
@MainActor
@Suite("Loopback sign-in redirect", .serialized)
struct LoopbackAuthorizerTests {
    private static func visit(_ url: URL) async -> (status: Int, body: String) {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse else { return (0, "") }
        return (http.statusCode, String(decoding: data, as: UTF8.self))
    }

    @Test func returnsTheRedirectTheBrowserLandsOn() async throws {
        var opened: [URL] = []
        var page: (status: Int, body: String) = (0, "")
        let authorizer = LoopbackAuthorizer(port: 47901, path: "/callback", timeout: 10) { url in
            opened.append(url)
            Task { page = await Self.visit(URL(string: "http://127.0.0.1:47901/callback?state=s1&code=c1")!) }
        }

        let callback = try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize?x=1")!, callbackScheme: "http")

        #expect(opened.map(\.absoluteString) == ["https://zoom.us/oauth/authorize?x=1"])
        #expect(callback.absoluteString == "http://127.0.0.1:47901/callback?state=s1&code=c1")
        try await Task.sleep(for: .milliseconds(300))
        #expect(page.status == 200)
        #expect(page.body.contains("return to Dayloom"))
    }

    @Test func ignoresOtherPagesTheBrowserAsksFor() async throws {
        var favicon = 0
        let authorizer = LoopbackAuthorizer(port: 47902, path: "/callback", timeout: 10) { _ in
            Task {
                favicon = await Self.visit(URL(string: "http://127.0.0.1:47902/favicon.ico")!).status
                _ = await Self.visit(URL(string: "http://127.0.0.1:47902/callback?state=s2&code=c2")!)
            }
        }

        let callback = try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize")!, callbackScheme: "http")

        #expect(favicon == 404)
        #expect(callback.absoluteString == "http://127.0.0.1:47902/callback?state=s2&code=c2")
    }

    @Test func aCallbackWithoutASignInReplyIsIgnored() async throws {
        var stray = 0
        let authorizer = LoopbackAuthorizer(port: 47905, path: "/callback", timeout: 10) { _ in
            Task {
                stray = await Self.visit(URL(string: "http://127.0.0.1:47905/callback")!).status
                _ = await Self.visit(URL(string: "http://127.0.0.1:47905/callback?state=s5&code=c5")!)
            }
        }

        let callback = try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize")!, callbackScheme: "http")

        #expect(stray == 404)
        #expect(callback.absoluteString == "http://127.0.0.1:47905/callback?state=s5&code=c5")
    }

    @Test func aNewSignInReplacesOneStillWaiting() async throws {
        var opens = 0
        let authorizer = LoopbackAuthorizer(port: 47906, path: "/callback", timeout: 30) { _ in
            opens += 1
            // Only the second sign-in gets a reply; the first is left waiting, as after a Zoom error page.
            if opens == 2 {
                Task { _ = await Self.visit(URL(string: "http://127.0.0.1:47906/callback?state=s6&code=c6")!) }
            }
        }

        let first = Task { try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize?n=1")!, callbackScheme: "http") }
        try await Task.sleep(for: .milliseconds(300))
        let second = try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize?n=2")!, callbackScheme: "http")

        #expect(second.absoluteString == "http://127.0.0.1:47906/callback?state=s6&code=c6")
        await #expect(throws: MeetingServiceError.signInCancelled) { try await first.value }
        #expect(opens == 2)
    }

    @Test func givingUpOnTheBrowserCountsAsCancelled() async {
        let authorizer = LoopbackAuthorizer(port: 47903, path: "/callback", timeout: 0.3) { _ in }

        await #expect(throws: MeetingServiceError.signInCancelled) {
            try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize")!, callbackScheme: "http")
        }
    }

    @Test func theListenerStopsAfterTheRedirect() async throws {
        let authorizer = LoopbackAuthorizer(port: 47904, path: "/callback", timeout: 10) { _ in
            Task { _ = await Self.visit(URL(string: "http://127.0.0.1:47904/callback?state=s&code=c")!) }
        }
        _ = try await authorizer.authorize(url: URL(string: "https://zoom.us/oauth/authorize")!, callbackScheme: "http")
        try await Task.sleep(for: .milliseconds(300))

        #expect(await Self.visit(URL(string: "http://127.0.0.1:47904/callback?state=x&code=y")!).status == 0)
    }

    @Test func readsTheTargetOfABrowserRequest() {
        #expect(LoopbackAuthorizer.requestTarget(in: "GET /callback?code=a&state=b HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n") == "/callback?code=a&state=b")
        #expect(LoopbackAuthorizer.requestTarget(in: "POST /callback HTTP/1.1\r\n\r\n") == nil)
        #expect(LoopbackAuthorizer.requestTarget(in: "garbage") == nil)
    }
}
