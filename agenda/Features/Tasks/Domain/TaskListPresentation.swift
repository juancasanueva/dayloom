import Foundation

/// How strongly a task's date or time should stand out in a list.
enum TimeEmphasis: Equatable {
    case overdue
    case today
    case normal
}

extension TaskQuery {
    /// Overdue when it's due before today or its time slot has passed; today when it falls later today.
    func timeEmphasis(for task: TaskItem) -> TimeEmphasis {
        guard !task.isDone else { return .normal }
        if isOverdue(task) { return .overdue }
        if let start = task.scheduledStart, start < now { return .overdue }
        if let day = relevantDay(for: task), calendar.isDate(day, inSameDayAs: now) { return .today }
        return .normal
    }
}

/// Moves a selection through an ordered list with the arrow keys.
enum ListNavigation {
    /// The item `offset` steps from `current`, clamped to the ends.
    /// With nothing (or something unknown) selected, Down picks the first item and Up the last.
    static func step<ID: Equatable>(from current: ID?, in ids: [ID], by offset: Int) -> ID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return offset >= 0 ? ids.first : ids.last
        }
        return ids[min(max(index + offset, 0), ids.count - 1)]
    }
}

/// The short line under a task list's title.
enum TaskListHeading {
    static func subtitle(
        for scope: TaskScope,
        count: Int,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .app
    ) -> String {
        switch scope {
        case .today:
            var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            style = style.weekday(.wide).day().month(.wide)
            return now.formatted(style)
        case .inbox:
            return count == 0 ? String(appLocalized: "Nothing waiting") : String(appLocalized: "\(count) tasks without a date")
        case .upcoming:
            return count == 0 ? String(appLocalized: "Nothing planned") : String(appLocalized: "\(count) tasks ahead")
        case .completed:
            return count == 0 ? String(appLocalized: "Nothing yet") : String(appLocalized: "\(count) finished")
        case .tag:
            return count == 0 ? String(appLocalized: "No open tasks") : String(appLocalized: "\(count) open tasks")
        }
    }
}
