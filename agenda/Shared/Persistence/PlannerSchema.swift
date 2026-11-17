import Foundation
import OSLog
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

    static let logger = Logger(subsystem: "com.juancasanueva.agenda", category: "Persistence")

    /// An opened store and whether it syncs through iCloud.
    struct Store {
        let container: ModelContainer
        let syncs: Bool
    }

    /// The on-disk store syncs through iCloud unless `syncs` is false; in-memory stores never do.
    static func configuration(inMemory: Bool, syncs: Bool = true) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory || !syncs ? .none : .private(cloudKitContainerID)
        )
    }

    /// Opens the store with iCloud sync. If sync can't start (for example, a build without the
    /// iCloud entitlement), the same store opens without sync so the app keeps working.
    static func openStore(inMemory: Bool = false) -> Store {
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration(inMemory: inMemory)])
            return Store(container: container, syncs: !inMemory)
        } catch {
            logger.error("iCloud sync unavailable, opening the store locally: \(error.localizedDescription, privacy: .public)")
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration(inMemory: inMemory, syncs: false)])
            return Store(container: container, syncs: false)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        openStore(inMemory: inMemory).container
    }
}
