import AppKit
import Testing
@testable import agenda

@MainActor
@Suite("About window")
struct AboutCreditsTests {
    private func link(on text: String, in credits: NSAttributedString) -> URL? {
        let range = (credits.string as NSString).range(of: text)
        guard range.location != NSNotFound else { return nil }
        return credits.attribute(.link, at: range.location, effectiveRange: nil) as? URL
    }

    @Test func creditsNameTheLicenseAndLinkItsText() {
        let credits = AboutCredits.make()

        #expect(credits.string.contains("Released under the MIT License."))
        #expect(link(on: "MIT License", in: credits)?.absoluteString == "https://github.com/juancasanueva/dayloom/blob/main/LICENSE.md")
    }

    @Test func creditsLinkTheGitHubPage() {
        let credits = AboutCredits.make()

        #expect(credits.string.contains("github.com/juancasanueva/dayloom"))
        #expect(link(on: "github.com/juancasanueva/dayloom", in: credits)?.absoluteString == "https://github.com/juancasanueva/dayloom")
    }

    @Test func creditsShowTheCopyright() {
        #expect(AboutCredits.make().string.contains("© 2026 Juan Casanueva"))
    }
}
