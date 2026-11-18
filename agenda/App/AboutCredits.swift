import AppKit

/// The text under the app's name and version in the About window: copyright, license and source.
enum AboutCredits {
    static let repositoryURL = URL(string: "https://github.com/juancasanueva/dayloom")!
    static let licenseURL = URL(string: "https://github.com/juancasanueva/dayloom/blob/main/LICENSE.md")!

    static func make() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 4
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]

        let credits = NSMutableAttributedString()
        func append(_ text: String, link: URL? = nil) {
            var attributes = base
            if let link { attributes[.link] = link }
            credits.append(NSAttributedString(string: text, attributes: attributes))
        }

        append("© 2026 Juan Casanueva\n")
        append("Released under the ")
        append("MIT License", link: licenseURL)
        append(".\n")
        append("github.com/juancasanueva/dayloom", link: repositoryURL)
        return credits
    }

    /// The standard About window with the app icon and these credits.
    static func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage as Any,
            .credits: make(),
        ])
        NSApp.activate()
    }
}
