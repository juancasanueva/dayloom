import CloudKit
import Foundation

/// Reads the account state of the app's iCloud container.
final class CloudKitAccountStatusProvider: AccountStatusProvider {
    /// Created on first use: the container needs the iCloud entitlement, which previews don't have.
    private lazy var container = CKContainer(identifier: PlannerSchema.cloudKitContainerID)

    func accountStatus() async -> CKAccountStatus? {
        try? await container.accountStatus()
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
