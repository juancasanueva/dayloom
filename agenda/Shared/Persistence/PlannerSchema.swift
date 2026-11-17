import Foundation
import OSLog
import Security
import SwiftData

enum PlannerSchema {
    static let schema = Schema([
        TaskItem.self, Tag.self, Habit.self, HabitCompletion.self, Note.self, NoteBlock.self,
    ])

    /// iCloud container whose private database mirrors the on-disk store.
    static let cloudKitContainerID = "iCloud.com.juancasanueva.agenda"

    /// True when the app is hosting unit tests, which must never touch the real store.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static let logger = Logger(subsystem: "com.juancasanueva.agenda", category: "Persistence")

    /// Logs an error with its domain and code in the clear and its description private,
    /// since descriptions can contain file paths with the user name.
    static func log(_ what: StaticString, _ error: Error) {
        let error = error as NSError
        logger.error("\(what, privacy: .public): \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .private)")
    }

    /// An opened store, whether it syncs through iCloud, and why not when it couldn't.
    struct Store {
        let container: ModelContainer
        let syncs: Bool
        var syncError: String?
    }

    /// The on-disk store syncs through iCloud unless `syncs` is false; in-memory stores never do.
    static func configuration(inMemory: Bool, syncs: Bool = true) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory || !syncs ? .none : .private(cloudKitContainerID)
        )
    }

    /// Whether this running copy is signed for the app's iCloud container. Without it, SwiftData
    /// opens an iCloud store without throwing and Core Data then traps during CloudKit setup,
    /// and `CKContainer(identifier:)` traps too.
    static var hasICloudEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil),
              let containers = value as? [String] else { return false }
        return containers.contains(cloudKitContainerID)
    }

    typealias ContainerFactory = (ModelConfiguration) throws -> ModelContainer

    /// The app's store: in memory and never syncing while hosting unit tests.
    static func openAppStore() -> Store {
        openStore(inMemory: isRunningTests)
    }

    /// Opens the store with iCloud sync. If sync can't start (for example, a build without the
    /// iCloud entitlement), the same store opens without sync so the app keeps working.
    static func openStore(
        inMemory: Bool = false,
        canUseICloud: Bool = hasICloudEntitlement,
        makeContainer: ContainerFactory = { try ModelContainer(for: schema, configurations: [$0]) }
    ) -> Store {
        let syncError: String
        if !inMemory && !canUseICloud {
            syncError = "This copy of Agenda isn't signed for iCloud."
        } else {
            do {
                let container = try makeContainer(configuration(inMemory: inMemory))
                return Store(container: container, syncs: !inMemory)
            } catch {
                log("iCloud sync unavailable, opening the store locally", error)
                syncError = error.localizedDescription
            }
        }
        do {
            let container = try makeContainer(configuration(inMemory: inMemory, syncs: false))
            return Store(container: container, syncs: false, syncError: syncError)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        openStore(inMemory: inMemory).container
    }
}
