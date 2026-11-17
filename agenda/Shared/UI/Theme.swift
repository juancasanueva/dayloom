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

/// A titled group on a panel: a quiet heading over a soft card, used by the details panel and Settings.
struct PanelSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }
}

// MARK: - Controls

/// A toggle drawn as a soft pill: tinted with `color` while on, a quiet outline while off.
struct PillToggleStyle: ToggleStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, color: color)
    }

    private struct Pill: View {
        let configuration: ToggleStyleConfiguration
        let color: Color
        @State private var isHovered = false

        var body: some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                configuration.label
                    .font(.caption.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(configuration.isOn ? AnyShapeStyle(color) : AnyShapeStyle(.secondary))
                    .background(
                        configuration.isOn ? color.opacity(0.16) : (isHovered ? Theme.cardHover : Color.clear),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule().strokeBorder(configuration.isOn ? Color.clear : Theme.hairline, lineWidth: 1)
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
        }
    }
}

/// A quiet rounded control for a page header: the card surface, a little stronger under the pointer or when pressed.
struct PageControlStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        PageControl(configuration: configuration, horizontalPadding: horizontalPadding)
    }

    private struct PageControl: View {
        let configuration: ButtonStyleConfiguration
        let horizontalPadding: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .padding(.horizontal, horizontalPadding)
                .frame(minHeight: 28)
                .background(
                    configuration.isPressed ? Theme.hairline : (isHovered ? Theme.cardHover : Theme.card),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Layout

/// Lays out pills left to right, wrapping onto a new line when the next one would overflow.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    struct Arrangement: Equatable {
        var origins: [CGPoint]
        var size: CGSize
    }

    /// Where each item goes, and the space they take together, for a line at most `maxWidth` wide.
    /// An item wider than the line still gets a line of its own.
    static func arrange(sizes: [CGSize], maxWidth: CGFloat, spacing: CGFloat, lineSpacing: CGFloat) -> Arrangement {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var width: CGFloat = 0

        for size in sizes {
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            width = max(width, x + size.width)
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
        return Arrangement(origins: origins, size: CGSize(width: width, height: sizes.isEmpty ? 0 : y + lineHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(for: subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrangement(for: subviews, maxWidth: bounds.width).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrangement(for subviews: Subviews, maxWidth: CGFloat) -> Arrangement {
        Self.arrange(
            sizes: subviews.map { $0.sizeThatFits(.unspecified) },
            maxWidth: maxWidth,
            spacing: spacing,
            lineSpacing: lineSpacing
        )
    }
}
