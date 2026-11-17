import AppKit
import SwiftUI

/// Dayloom's visual language: a warm, woven-paper palette with soft surfaces.
/// Screens sit on a canvas, content on a rounded panel, items on cards.
enum Theme {
    // MARK: Surfaces

    /// Window background behind the content panel.
    static let canvas = adaptive(light: 0xE8E4DD, dark: 0x151617)
    /// The rounded panel that holds a screen's content.
    static let panel = adaptive(light: 0xFBF9F6, dark: 0x1E1F22)
    /// Resting surface of a card.
    static let card = adaptive(light: 0xF1EDE7, dark: 0x292A2E)
    /// Card surface under the pointer.
    static let cardHover = adaptive(light: 0xEAE5DD, dark: 0x303135)
    /// Hairlines and quiet strokes.
    static let hairline = Color.primary.opacity(0.08)

    // MARK: Metrics

    static let panelRadius: CGFloat = 16
    static let cardRadius: CGFloat = 10
    static let panelInset: CGFloat = 8
    /// Comfortable reading width for list-style content.
    static let readableWidth: CGFloat = 760
    /// Width of the day column in grouped lists.
    static let dayColumnWidth: CGFloat = 112
    static let pagePadding = EdgeInsets(top: 24, leading: 32, bottom: 32, trailing: 32)

    // MARK: Type

    static let pageTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(.title3, design: .rounded).weight(.semibold)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Page structure

/// A screen's large title, a short subtitle, and optional controls on the trailing side.
struct PageHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    init(_ title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.pageTitle)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
            accessory
        }
    }
}

extension View {
    /// Places the screen on Dayloom's rounded content panel, inset from the window edges.
    func plannerPanel() -> some View {
        background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.panelRadius))
            .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius))
            .padding(Theme.panelInset)
            .background(Theme.canvas)
    }

    /// The soft card surface used for tasks, habits and other items.
    func plannerCard(isSelected: Bool = false, isHovered: Bool = false) -> some View {
        background(
            isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.14)) : AnyShapeStyle(isHovered ? Theme.cardHover : Theme.card),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
        }
    }
}
