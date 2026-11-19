import CloudKit
import SwiftUI

/// The app's Settings window: one tab per area, each sized to its own content.
///
/// The tab bar is drawn here rather than by `TabView`, whose toolbar tabs always use the
/// System Settings accent instead of the theme's.
struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case appearance, language, shortcuts, notifications, videoCalls, iCloud

        var id: Self { self }

        var title: String {
            switch self {
            case .appearance: String(appLocalized: "Appearance")
            case .language: String(appLocalized: "Language")
            case .shortcuts: String(appLocalized: "Shortcuts")
            case .notifications: String(appLocalized: "Notifications")
            case .videoCalls: String(appLocalized: "Video Calls")
            case .iCloud: "iCloud"
            }
        }

        var symbol: String {
            switch self {
            case .appearance: "paintbrush"
            case .language: "globe"
            case .shortcuts: "keyboard"
            case .notifications: "bell"
            case .videoCalls: "video"
            case .iCloud: "icloud"
            }
        }
    }

    /// Settings reopens on the tab used last.
    @AppStorage("settingsTab") private var selection: Tab = .appearance

    var body: some View {
        // ForEach reruns its content only when what the closure captures changes. Captured
        // through `self`, @AppStorage looks unchanged after a switch, so capture the value instead.
        let current = selection
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Tab.allCases) { tab in
                    SettingsTabButton(tab: tab, isSelected: tab == current) { selection = tab }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            Divider()
            page
        }
        .navigationTitle(selection.title)
        .containerBackground(Theme.panel, for: .window)
        .themedAppearance()
    }

    /// The selected tab's content at a fixed width; its height follows the content, so the window does too.
    private var page: some View {
        Group {
            switch selection {
            case .appearance: ThemeSettingsSection()
            case .language: LanguageSettingsSection()
            case .shortcuts: ShortcutSettingsSection()
            case .notifications: ReminderSettingsSection()
            case .videoCalls: VideoCallSettingsSection()
            case .iCloud: SyncSettingsSection()
            }
        }
        .padding(24)
        .frame(width: 600, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One tab of the Settings bar, shaped like the system's: the selected tab in the theme's accent.
private struct SettingsTabButton: View {
    let tab: SettingsView.Tab
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.appearsActive) private var appearsActive
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 17))
                    .frame(height: 22)
                Text(tab.title)
                    .font(.caption)
            }
            .frame(minWidth: 62)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        // The focus ring is drawn in the system accent; the selected tab already shows where you are.
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: AnyShapeStyle {
        guard isSelected else { return AnyShapeStyle(.secondary) }
        return appearsActive ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary)
    }

    private var background: Color {
        if isSelected { return Color.primary.opacity(0.1) }
        return isHovered ? Theme.hairline : .clear
    }
}

/// Whether Dayloom is syncing through iCloud, and why not when it isn't.
private struct SyncSettingsSection: View {
    @Environment(SyncStatusModel.self) private var syncStatus

    /// The underlying error, shown for the states it explains.
    private var reason: String? {
        switch syncStatus.status {
        case .problem: syncStatus.problem
        case .localOnly: syncStatus.storeError
        default: nil
        }
    }

    var body: some View {
        PanelSection("iCloud") {
            HStack(alignment: .top, spacing: 12) {
                statusIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(syncStatus.status.title)
                        .fontWeight(.medium)
                    Text(syncStatus.status.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let reason = reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let lastSynced = syncStatus.lastSynced {
                        Text("Last synced \(lastSynced.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(.app)))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The sync symbol on a soft round wash, tinted while sync is on.
    private var statusIcon: some View {
        let tint = syncStatus.status == .on ? Theme.accent : Color.secondary
        return Image(systemName: syncStatus.status.symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview {
    SettingsView()
        .environment(SyncStatusModel(provider: StaticAccountStatusProvider(status: .available)))
}
