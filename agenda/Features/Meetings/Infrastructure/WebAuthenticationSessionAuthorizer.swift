import AppKit
import AuthenticationServices

/// Shows a service's sign-in page in a system browser sheet over the app's window.
final class WebAuthenticationSessionAuthorizer: NSObject, WebAuthorizer, ASWebAuthenticationPresentationContextProviding {
    /// Held while the sheet is open; the session stops if nothing retains it.
    private var session: ASWebAuthenticationSession?

    func authorize(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            // AppKit may report a failed start both by returning false and through the handler; resume only once.
            var isFinished = false
            func finish(_ result: Result<URL, Error>) {
                guard !isFinished else { return }
                isFinished = true
                self.session = nil
                continuation.resume(with: result)
            }

            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) { callback, error in
                let result: Result<URL, Error>
                if let callback {
                    result = .success(callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    result = .failure(MeetingServiceError.signInCancelled)
                } else {
                    result = .failure(MeetingServiceError.signInSheetFailed(reason: error?.localizedDescription ?? "no reply"))
                }
                // The handler isn't documented to run on the main thread; the state it touches lives there.
                DispatchQueue.main.async { finish(result) }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                finish(.failure(MeetingServiceError.signInSheetFailed(reason: "the sign-in sheet couldn't open")))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? ASPresentationAnchor()
    }
}
