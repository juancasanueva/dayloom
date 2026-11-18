import AppKit
import AuthenticationServices

/// Shows Google's sign-in page in a system browser sheet over the app's window.
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
                if let callback {
                    finish(.success(callback))
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    finish(.failure(GoogleMeetError.signInCancelled))
                } else {
                    finish(.failure(GoogleMeetError.signInFailed(error?.localizedDescription ?? "no reply")))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                finish(.failure(GoogleMeetError.signInFailed("the sign-in sheet couldn't open")))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? ASPresentationAnchor()
    }
}
