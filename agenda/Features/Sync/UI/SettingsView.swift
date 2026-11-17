import CloudKit
import SwiftUI

/// The app's Settings window.
struct SettingsView: View {
    @Environment(SyncStatusModel.self) private var syncStatus

    var body: some View {
        Form {
            Section("iCloud") {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(syncStatus.status.title)
                        Text(syncStatus.status.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let problem = syncStatus.problem, syncStatus.status == .problem {
                            Text(problem)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if let lastSynced = syncStatus.lastSynced {
                            Text("Last synced \(lastSynced.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } icon: {
                    Image(systemName: syncStatus.status.symbol)
                        .foregroundStyle(syncStatus.status == .on ? Color.accentColor : Color.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView()
        .environment(SyncStatusModel(provider: StaticAccountStatusProvider(status: .available)))
}
