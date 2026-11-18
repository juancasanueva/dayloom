import Foundation

/// Which tasks to offer when adding an existing task to a note.
enum TaskPicker {
    static let maxRecentTasks = 20

    /// Without a query, the newest open tasks. With one, the same title search as the launcher.
    static func candidates(from tasks: [TaskItem], query: String) -> [TaskItem] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return LauncherResults.matchingTasks(tasks, query: query)
        }
        let open = tasks.filter { !$0.isDone }.sorted { $0.createdAt > $1.createdAt }
        return Array(open.prefix(maxRecentTasks))
    }
}
