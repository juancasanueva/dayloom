import CloudKit
import SwiftUI

/// The app's Settings window.
struct SettingsView: View {
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(Theme.sectionTitle)
                Text("How Dayloom looks and keeps your planner in sync.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ThemeSettingsSection()

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
        .padding(24)
        .frame(width: 600, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .containerBackground(Theme.panel, for: .window)
        .themedAppearance()
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
