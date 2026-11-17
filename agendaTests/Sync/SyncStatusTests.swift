import CloudKit
import Foundation
import Testing
@testable import agenda

@MainActor
@Suite("Sync status")
struct SyncStatusTests {
    @Test(arguments: [
        (CKAccountStatus.available, SyncStatus.on),
        (.noAccount, .signedOut),
        (.restricted, .restricted),
        (.temporarilyUnavailable, .unavailable),
        (.couldNotDetermine, .unavailable),
    ])
    func accountStatusMapsToSyncStatus(account: CKAccountStatus, expected: SyncStatus) {
        #expect(SyncStatus(account) == expected)
    }

    @Test func everyStatusExplainsItself() {
        for status in [SyncStatus.checking, .on, .signedOut, .restricted, .unavailable, .problem, .localOnly] {
            #expect(!status.title.isEmpty)
            #expect(!status.detail.isEmpty)
        }
    }

    @Test func statusCopyUsesTheAppName() {
        let statuses = [SyncStatus.checking, .on, .signedOut, .restricted, .unavailable, .problem, .localOnly]
        for status in statuses {
            #expect(!status.title.contains("Agenda"))
            #expect(!status.detail.contains("Agenda"))
        }
        #expect(SyncStatus.localOnly.detail.contains("reopen Dayloom"))
    }

    @Test func modelStartsCheckingThenReportsTheAccount() async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: .noAccount))
        #expect(model.status == .checking)

        await model.refresh()

        #expect(model.status == .signedOut)
    }

    @Test func failedCheckReportsUnavailable() async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: nil))

        await model.refresh()

        #expect(model.status == .unavailable)
    }

    // MARK: Sync activity

    @Test func successfulSyncIsShownWithItsTime() async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: .available))
        await model.refresh()

        model.record(SyncEvent(endDate: TestClock.now, errorDescription: nil))

        #expect(model.status == .on)
        #expect(model.lastSynced == TestClock.now)
        #expect(model.problem == nil)
    }

    @Test func failedSyncIsAProblemUntilTheNextSuccess() async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: .available))
        await model.refresh()
        model.record(SyncEvent(endDate: TestClock.date(2026, 11, 17, 9), errorDescription: nil))

        model.record(SyncEvent(endDate: TestClock.now, errorDescription: "Bad container"))
        #expect(model.status == .problem)
        #expect(model.problem == "Bad container")
        #expect(model.lastSynced == TestClock.date(2026, 11, 17, 9))

        model.record(SyncEvent(endDate: TestClock.date(2026, 11, 17, 11), errorDescription: nil))
        #expect(model.status == .on)
        #expect(model.problem == nil)
    }

    @Test func eventsStillRunningAreIgnored() async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: .available))
        await model.refresh()

        model.record(SyncEvent(endDate: nil, errorDescription: nil))

        #expect(model.lastSynced == nil)
        #expect(model.status == .on)
    }

    @Test func signedOutWinsOverSyncProblems() async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: .noAccount))
        await model.refresh()

        model.record(SyncEvent(endDate: TestClock.now, errorDescription: "Not authenticated"))

        #expect(model.status == .signedOut)
    }

    @Test func localOnlyStoreSaysSyncIsOffUntilReopened() async {
        let model = SyncStatusModel(
            provider: StaticAccountStatusProvider(status: .available),
            storeSyncs: false,
            storeError: "Missing entitlement"
        )

        await model.refresh()

        #expect(model.status == .localOnly)
        #expect(model.storeError == "Missing entitlement")
        #expect(SyncStatus.localOnly.detail.contains("reopen"))
        #expect(!SyncStatus.localOnly.detail.contains("once iCloud is reachable"))
    }

    /// The retry promise of `.unavailable` doesn't hold for a local-only store, whatever the account says.
    @Test(arguments: [CKAccountStatus.temporarilyUnavailable, .couldNotDetermine, .noAccount])
    func localOnlyStoreWinsOverInconclusiveAccounts(account: CKAccountStatus) async {
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: account), storeSyncs: false)

        await model.refresh()

        #expect(model.status == .localOnly)
    }

    // MARK: Merge trigger and observation (S5.3, S5.6)

    @Test func onlySuccessfulFinishedImportsTriggerAMerge() async {
        var merges = 0
        let model = SyncStatusModel(provider: StaticAccountStatusProvider(status: .available)) { merges += 1 }

        model.record(SyncEvent(endDate: nil, errorDescription: nil, kind: .import))
        model.record(SyncEvent(endDate: TestClock.now, errorDescription: "Network", kind: .import))
        model.record(SyncEvent(endDate: TestClock.now, errorDescription: nil, kind: .export))
        model.record(SyncEvent(endDate: TestClock.now, errorDescription: nil, kind: .setup))
        #expect(merges == 0)

        model.record(SyncEvent(endDate: TestClock.now, errorDescription: nil, kind: .import))
        #expect(merges == 1)
    }

    @Test func startingObservationTwiceKeepsOneObserver() async {
        let provider = ScriptedAccountStatusProvider(
            statuses: [.noAccount, .available],
            events: [SyncEvent(endDate: TestClock.now, errorDescription: nil, kind: .import)]
        )
        var merges = 0
        let model = SyncStatusModel(provider: provider) { merges += 1 }

        let first = model.startObserving()
        let second = model.startObserving()
        await first.value

        #expect(first == second)
        #expect(provider.statusReads == 2)
        #expect(merges == 1)
    }

    @Test func observationFollowsAccountChangesAndSyncEvents() async {
        let provider = ScriptedAccountStatusProvider(
            statuses: [.noAccount, .available],
            events: [SyncEvent(endDate: TestClock.now, errorDescription: nil, kind: .import)]
        )
        var merges = 0
        let model = SyncStatusModel(provider: provider) { merges += 1 }

        await model.observeChanges()

        #expect(provider.statusReads == 2) // Initial read plus one per account change.
        #expect(model.status == .on)
        #expect(model.lastSynced == TestClock.now)
        #expect(merges == 1)
    }
}

/// Answers account reads from a script and emits one account change plus fixed sync events.
@MainActor
final class ScriptedAccountStatusProvider: AccountStatusProvider {
    private var statuses: [CKAccountStatus]
    private let events: [SyncEvent]
    private(set) var statusReads = 0

    init(statuses: [CKAccountStatus], events: [SyncEvent]) {
        self.statuses = statuses
        self.events = events
    }

    func accountStatus() async -> CKAccountStatus? {
        statusReads += 1
        return statuses.count > 1 ? statuses.removeFirst() : statuses.first
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { $0.yield(); $0.finish() }
    }

    func syncEvents() -> AsyncStream<SyncEvent> {
        let events = events
        return AsyncStream { continuation in
            events.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
