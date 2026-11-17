import Foundation
import Observation

/// Keeps the iCloud status shown in Settings current: the account state plus the latest sync result.
@Observable
final class SyncStatusModel {
    private(set) var lastSynced: Date?
    /// Description of the latest failed sync step, cleared by the next success.
    private(set) var problem: String?
    private var account: SyncStatus = .checking
    private let provider: AccountStatusProvider
    /// False when the store had to open without iCloud, so nothing syncs whatever the account says.
    private let storeSyncs: Bool

    init(provider: AccountStatusProvider, storeSyncs: Bool = true) {
        self.provider = provider
        self.storeSyncs = storeSyncs
    }

    /// The account state wins; while it's fine, a local-only store or a failed sync step shows instead.
    var status: SyncStatus {
        guard account == .on else { return account }
        if !storeSyncs { return .unavailable }
        return problem != nil ? .problem : .on
    }

    func refresh() async {
        account = (await provider.accountStatus()).map(SyncStatus.init) ?? .unavailable
    }

    func record(_ event: SyncEvent) {
        guard let endDate = event.endDate else { return }
        if let error = event.errorDescription {
            problem = error
        } else {
            problem = nil
            lastSynced = max(lastSynced ?? endDate, endDate)
        }
    }

    /// Follows account changes and sync activity for as long as the caller is alive.
    func observeChanges() async {
        let accountChanges = provider.changes()
        let events = provider.syncEvents()
        await withDiscardingTaskGroup { group in
            group.addTask {
                await self.refresh()
                for await _ in accountChanges {
                    await self.refresh()
                }
            }
            group.addTask {
                for await event in events {
                    await self.record(event)
                }
            }
        }
    }
}
