import SwiftUI

/// "Search or add…" with the ⌘K hint, centered in the toolbar so people find the quick launcher
/// without knowing the shortcut. Clicking it opens the launcher.
struct LauncherPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // No Spacer: a toolbar drops items whose content contains one. The hint is pinned instead.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                Text("Search or add…")
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: 280, alignment: .leading)
            .overlay(alignment: .trailing) {
                Text(ShortcutStore.shared.shortcut(for: .quickLauncher).displayText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 4)
            .modifier(PillSurface())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help("Search, add a task or plan an event (\(ShortcutStore.shared.shortcut(for: .quickLauncher).displayText), or \(ShortcutStore.shared.shortcut(for: .quickLauncherAnywhere).displayText) from any app)")
        .accessibilityLabel("Quick Launcher")
        .accessibilityHint("Search, add a task or plan an event")
    }
}

/// Newer macOS toolbars already place items on a glass capsule; earlier ones get a matching capsule here.
private struct PillSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
        } else {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.card, in: Capsule())
                .overlay { Capsule().strokeBorder(Theme.hairline) }
        }
    }
}
