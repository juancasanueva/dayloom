import Foundation
import Observation

/// Keeps the iCloud status shown in Settings current (the account state plus the latest sync
/// result) and asks for duplicates to be merged after each finished import.
@Observable
final class SyncStatusModel {
    private(set) var lastSynced: Date?
    /// Description of the latest failed sync step, cleared by the next success.
    private(set) var problem: String?
    /// Why the store opened without iCloud, when it did.
    let storeError: String?
    private var account: SyncStatus = .checking
    private let provider: AccountStatusProvider
    /// False when the store had to open without iCloud, so nothing syncs whatever the account says.
    private let storeSyncs: Bool
    /// Called after each successful import. Merging waits for these, because a record can
    /// arrive before its related records while an import is still running.
    private let onImportFinished: () -> Void
    @ObservationIgnored private var observation: Task<Void, Never>?

    init(
        provider: AccountStatusProvider,
        storeSyncs: Bool = true,
        storeError: String? = nil,
        onImportFinished: @escaping () -> Void = {}
    ) {
        self.provider = provider
        self.storeSyncs = storeSyncs
        self.storeError = storeError
        self.onImportFinished = onImportFinished
    }

    /// The account state wins; while it's fine, a local-only store or a failed sync step shows instead.
    var status: SyncStatus {
        guard account == .on else { return account }
        if !storeSyncs { return .localOnly }
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
            if event.kind == .import {
                onImportFinished()
            }
        }
    }

    /// Starts following the account and sync activity for the app's lifetime. Calling it again does nothing.
    func startObserving() {
        guard observation == nil else { return }
        observation = Task { await observeChanges() }
    }

    /// Follows account changes and sync activity until both streams end.
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
