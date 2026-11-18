import AppKit
import SwiftUI

/// Applies the chosen appearance to every window and the theme's accent to controls.
struct ThemedAppearance: ViewModifier {
    private let store = ThemeStore.shared

    func body(content: Content) -> some View {
        content
            .tint(Theme.accent)
            .onChange(of: store.appearance, initial: true) { _, mode in
                NSApp.appearance = mode.appearanceName.flatMap(NSAppearance.init(named:))
            }
    }
}

extension View {
    /// Follows the appearance and accent chosen in Settings.
    func themedAppearance() -> some View {
        modifier(ThemedAppearance())
    }
}

/// Settings controls for the appearance and the dark and light themes.
struct ThemeSettingsSection: View {
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        PanelSection("Theme") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appearance")
                        .fontWeight(.medium)
                    Text("Light or dark, or as your system is now.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Picker("Appearance", selection: $store.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            Divider()

            themeGrid("Dark", ThemePalette.dark, selected: store.darkPalette)
            themeGrid("Light", ThemePalette.light, selected: store.lightPalette)
        }
    }

    private func themeGrid(_ title: String, _ palettes: [ThemePalette], selected: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118, maximum: 140), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(palettes) { palette in
                    ThemeSwatch(palette: palette, isSelected: palette == selected) {
                        store.select(palette)
                    }
                }
            }
        }
    }
}

/// A small preview of a theme: its canvas and panel, a title line, and its accent with a few tag colors.
private struct ThemeSwatch: View {
    let palette: ThemePalette
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var accent: Color {
        palette.accent.map { Color(nsColor: Theme.nsColor($0)) } ?? .accentColor
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                preview
                HStack(spacing: 4) {
                    Text(palette.name)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        // Long names such as "Catppuccin Macchiato" shrink a little instead of wrapping.
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding(6)
            .background(isHovered && !isSelected ? Theme.cardHover : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(palette.name) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        let text = palette.isDark ? Color.white.opacity(0.75) : Color.black.opacity(0.7)
        return VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(text)
                .frame(width: 44, height: 4)
            HStack(spacing: 4) {
                Circle().fill(accent)
                Circle().fill(Color.red)
                Circle().fill(Color.green)
                Circle().fill(Color.orange)
                Circle().fill(Color.purple)
            }
            .frame(height: 9)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: Theme.nsColor(palette.panel)), in: RoundedRectangle(cornerRadius: 6))
        .padding(6)
        .background(Color(nsColor: Theme.nsColor(palette.canvas)), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.12))
        }
    }
}
