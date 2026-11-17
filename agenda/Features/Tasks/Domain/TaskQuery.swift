import Foundation
import SwiftData

/// A smart list the user can open from the sidebar.
enum TaskScope: Hashable {
    case inbox
    case today
    case upcoming
    case completed
    case tag(PersistentIdentifier)
}

struct DaySection: Identifiable {
    let day: Date
    let tasks: [TaskItem]
    var id: Date { day }
}

/// Pure rules that decide which tasks belong to each smart list and in what order.
struct TaskQuery {
    var now: Date
    var calendar: Calendar

    init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    private var startOfToday: Date { calendar.startOfDay(for: now) }

    func tasks(from all: [TaskItem], in scope: TaskScope) -> [TaskItem] {
        let topLevel = all.filter { $0.parent == nil }

        switch scope {
        case .completed:
            return topLevel
                .filter(\.isDone)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .inbox:
            return sorted(topLevel.filter { !$0.isDone && $0.dueDate == nil && $0.scheduledStart == nil })
        case .today:
            return sorted(topLevel.filter { task in
                guard !task.isDone, let day = relevantDay(for: task) else { return false }
                return day <= startOfToday
            })
        case .upcoming:
            return sorted(topLevel.filter { task in
                guard !task.isDone, let day = relevantDay(for: task) else { return false }
                return day > startOfToday
            })
        case .tag(let tagID):
            return sorted(topLevel.filter { task in
                !task.isDone && (task.tags ?? []).contains { $0.persistentModelID == tagID }
            })
        }
    }

    func upcomingSections(from all: [TaskItem]) -> [DaySection] {
        let grouped = Dictionary(grouping: tasks(from: all, in: .upcoming)) { relevantDay(for: $0)! }
        return grouped.keys.sorted().map { DaySection(day: $0, tasks: sorted(grouped[$0]!)) }
    }

    /// The start of the earliest day the task is due or scheduled on.
    func relevantDay(for task: TaskItem) -> Date? {
        [task.dueDate, task.scheduledStart]
            .compactMap { $0 }
            .min()
            .map { calendar.startOfDay(for: $0) }
    }

    func isOverdue(_ task: TaskItem) -> Bool {
        guard !task.isDone, let due = task.dueDate else { return false }
        return calendar.startOfDay(for: due) < startOfToday
    }

    /// Due date a task gets when created from inside a list.
    func defaultDueDate(for scope: TaskScope) -> Date? {
        switch scope {
        case .today: startOfToday
        case .upcoming: calendar.date(byAdding: .day, value: 1, to: startOfToday)
        case .inbox, .completed, .tag: nil
        }
    }

    private func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            let lhsDate = earliestDate(lhs) ?? .distantFuture
            let rhsDate = earliestDate(rhs) ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    private func earliestDate(_ task: TaskItem) -> Date? {
        [task.dueDate, task.scheduledStart].compactMap { $0 }.min()
    }
}
