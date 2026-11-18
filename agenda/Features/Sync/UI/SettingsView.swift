import CloudKit
import SwiftUI

/// The app's Settings window: one tab per area, each sized to its own content.
struct SettingsView: View {
    enum Tab: String {
        case appearance, notifications, videoCalls, iCloud
    }

    /// Settings reopens on the tab used last.
    @AppStorage("settingsTab") private var selection: Tab = .appearance

    var body: some View {
        TabView(selection: $selection) {
            page { ThemeSettingsSection() }
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag(Tab.appearance)

            page { ReminderSettingsSection() }
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(Tab.notifications)

            page { VideoCallSettingsSection() }
                .tabItem { Label("Video Calls", systemImage: "video") }
                .tag(Tab.videoCalls)

            page { SyncSettingsSection() }
                .tabItem { Label("iCloud", systemImage: "icloud") }
                .tag(Tab.iCloud)
        }
        .containerBackground(Theme.panel, for: .window)
        .themedAppearance()
    }

    /// A tab's content at a fixed width; its height follows the content, so the window does too.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(width: 600, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
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
                        Text("Last synced \(lastSynced.formatted(date: .abbreviated, time: .shortened))")
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
