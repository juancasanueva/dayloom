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
        for status in [SyncStatus.checking, .on, .signedOut, .restricted, .unavailable, .problem] {
            #expect(!status.title.isEmpty)
            #expect(!status.detail.isEmpty)
        }
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
}
