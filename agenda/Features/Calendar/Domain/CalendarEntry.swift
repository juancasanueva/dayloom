import Foundation
import SwiftData

/// Color carried by an entry, kept framework-neutral so the domain doesn't depend on SwiftUI.
enum EntryTint: Hashable {
    case accent
    case rgb(red: Double, green: Double, blue: Double)
}

/// Anything drawn on the week grid: a calendar event or a scheduled task.
struct CalendarEntry: Identifiable, Hashable {
    enum Kind: Hashable {
        case event
        case task(PersistentIdentifier, isDone: Bool)
    }

    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var kind: Kind
    var tint: EntryTint
    var calendarName: String? = nil
    var location: String? = nil
    var url: URL? = nil

    var taskID: PersistentIdentifier? {
        if case .task(let id, _) = kind { return id }
        return nil
    }

    var isCompletedTask: Bool {
        if case .task(_, let isDone) = kind { return isDone }
        return false
    }

    /// Maps tasks with a scheduled time inside `interval` to grid entries.
    static func scheduledTasks(_ tasks: [TaskItem], in interval: DateInterval) -> [CalendarEntry] {
        tasks.compactMap { task in
            guard let start = task.scheduledStart, let end = task.scheduledEnd,
                  start < interval.end, end > interval.start else { return nil }
            return CalendarEntry(
                id: "task-\(String(describing: task.persistentModelID))",
                title: task.title,
                start: start,
                end: end,
                isAllDay: false,
                kind: .task(task.persistentModelID, isDone: task.isDone),
                tint: .accent
            )
        }
    }
}
