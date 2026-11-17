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
        .task { await syncStatus.observeChanges() }
    }
}

#Preview {
    SettingsView()
        .environment(SyncStatusModel(provider: StaticAccountStatusProvider(status: .available)))
}
