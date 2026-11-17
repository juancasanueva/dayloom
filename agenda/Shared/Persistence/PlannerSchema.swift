import Foundation
import SwiftData

enum PlannerSchema {
    static let schema = Schema([TaskItem.self, Tag.self, Habit.self, HabitCompletion.self])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
