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
        for status in [SyncStatus.checking, .on, .signedOut, .restricted, .unavailable] {
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
}
