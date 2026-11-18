import AppKit
import Network

/// Sign-in for services that only redirect to a web address (Zoom). Opens the sign-in page in
/// the default browser and waits for the redirect on a listener bound to 127.0.0.1, so nothing
/// outside this Mac can reach it. The listener only runs while a sign-in is in progress.
final class LoopbackAuthorizer: WebAuthorizer {
    let port: UInt16
    let path: String
    let timeout: TimeInterval
    private let openURL: (URL) -> Void

    init(port: UInt16, path: String, timeout: TimeInterval = 180, openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }) {
        self.port = port
        self.path = path
        self.timeout = timeout
        self.openURL = openURL
    }

    /// `callbackScheme` is unused: the redirect is recognized by its port and path instead.
    func authorize(url: URL, callbackScheme: String) async throws -> URL {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        parameters.allowLocalEndpointReuse = true
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            throw MeetingServiceError.signInSheetFailed(reason: "couldn't listen for the sign-in reply")
        }

        return try await withCheckedThrowingContinuation { continuation in
            var isFinished = false
            var deadline: DispatchWorkItem?

            func finish(_ result: Result<URL, Error>) {
                guard !isFinished else { return }
                isFinished = true
                deadline?.cancel()
                // Stops new connections; the page already being sent to the browser still goes out.
                // Clearing the handlers releases what they captured, including this function.
                listener.newConnectionHandler = nil
                listener.stateUpdateHandler = nil
                listener.cancel()
                continuation.resume(with: result)
            }

            listener.newConnectionHandler = { connection in
                MainActor.assumeIsolated {
                    connection.start(queue: .main)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
                        MainActor.assumeIsolated {
                            let request = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
                            guard let target = Self.requestTarget(in: request),
                                  Self.isSignInReply(target, path: self.path),
                                  let callback = URL(string: "http://127.0.0.1:\(self.port)\(target)") else {
                                Self.respond(connection, status: "404 Not Found", body: "Not found")
                                return
                            }
                            Self.respond(connection, status: "200 OK", body: Self.signedInPage)
                            NSApp?.activate()
                            finish(.success(callback))
                        }
                    }
                }
            }
            listener.stateUpdateHandler = { state in
                MainActor.assumeIsolated {
                    switch state {
                    case .ready:
                        self.openURL(url)
                    case .failed(let error):
                        finish(.failure(MeetingServiceError.signInSheetFailed(reason: "couldn't listen for the sign-in reply (\(error.localizedDescription))")))
                    default:
                        break
                    }
                }
            }

            // Giving up on the browser counts as cancelling, like closing a sign-in sheet.
            let giveUp = DispatchWorkItem {
                MainActor.assumeIsolated { finish(.failure(MeetingServiceError.signInCancelled)) }
            }
            deadline = giveUp
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: giveUp)
            listener.start(queue: .main)
        }
    }

    /// Only a redirect carrying a sign-in reply (`state` with a `code` or an `error`) ends the sign-in;
    /// anything else, such as a stray visit to the path, is answered with 404 and the wait goes on.
    static func isSignInReply(_ target: String, path: String) -> Bool {
        guard target.hasPrefix(path + "?"),
              let items = URLComponents(string: target)?.queryItems else { return false }
        let names = Set(items.map(\.name))
        return names.contains("state") && (names.contains("code") || names.contains("error"))
    }

    /// The path and query of a `GET` request, such as `/callback?code=…&state=…`.
    static func requestTarget(in request: String) -> String? {
        guard let line = request.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = line.split(separator: " ")
        guard parts.count == 3, parts[0] == "GET", parts[1].hasPrefix("/"), parts[2].hasPrefix("HTTP/") else { return nil }
        return String(parts[1])
    }

    private static let signedInPage = """
    <!doctype html><meta charset="utf-8"><title>Dayloom</title>\
    <body style="font: 15px -apple-system, sans-serif; text-align: center; margin-top: 20vh">\
    <p>Signed in. You can close this tab and return to Dayloom.</p></body>
    """

    private static func respond(_ connection: NWConnection, status: String, body: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
            + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}
