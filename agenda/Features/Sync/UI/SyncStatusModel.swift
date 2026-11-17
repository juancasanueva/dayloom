import Foundation
import Observation

/// Keeps the iCloud status shown in Settings current.
@Observable
final class SyncStatusModel {
    private(set) var status: SyncStatus = .checking
    private let provider: AccountStatusProvider

    init(provider: AccountStatusProvider) {
        self.provider = provider
    }

    func refresh() async {
        status = (await provider.accountStatus()).map(SyncStatus.init) ?? .unavailable
    }

    /// Refreshes now and again whenever the iCloud account changes, while the caller is alive.
    func observeChanges() async {
        await refresh()
        for await _ in provider.changes() {
            await refresh()
        }
    }
}
