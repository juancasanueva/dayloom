import Foundation
import SwiftData

/// One selectable line in the launcher.
enum LauncherRow: Identifiable {
    case newTask(LauncherInput)
    case newEvent(LauncherInput)
    case existing(TaskItem)

    var id: String {
        switch self {
        case .newTask: "new-task"
        case .newEvent: "new-event"
        case .existing(let task): "task-\(String(describing: task.persistentModelID))"
        }
    }
}

/// Decides which rows the launcher shows and in what order.
enum LauncherResults {
    static let maxTaskMatches = 8

    /// "New Task", then "New Event", then up to eight matching tasks.
    ///
    /// The create rows need a title. "New Event" also needs calendar access and a date or time.
    static func rows(for input: LauncherInput, query: String, tasks: [TaskItem], calendarAccess: CalendarAccess) -> [LauncherRow] {
        var rows: [LauncherRow] = []
        if input.hasTitle {
            rows.append(.newTask(input))
            if calendarAccess == .granted && input.hasDateOrTime {
                rows.append(.newEvent(input))
            }
        }
        // Search on the title left after parsing, so "dentist fri" still finds "Dentist".
        let searchText = input.hasTitle ? input.title : query
        rows += matchingTasks(tasks, query: searchText).map(LauncherRow.existing)
        return rows
    }

    /// Tasks whose title contains the query, ignoring case and diacritics. Open tasks come first.
    static func matchingTasks(_ tasks: [TaskItem], query: String) -> [TaskItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        let matches = tasks.filter {
            $0.title.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        let ordered = matches.filter { !$0.isDone } + matches.filter(\.isDone)
        return Array(ordered.prefix(maxTaskMatches))
    }
}
