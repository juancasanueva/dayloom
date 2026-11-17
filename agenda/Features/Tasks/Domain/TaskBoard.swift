import Foundation
import SwiftData

/// One status column on the board.
struct BoardColumn: Identifiable {
    let status: TaskStatus
    let tasks: [TaskItem]
    var id: TaskStatus { status }
}

/// Pure rules that arrange a smart list's tasks into status columns and move cards between them.
struct TaskBoard {
    /// How far back the Done column looks.
    static let doneWindowDays = 7

    var now: Date
    var calendar: Calendar

    init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    private var query: TaskQuery { TaskQuery(now: now, calendar: calendar) }

    /// To Do and In Progress keep the list's membership and order; Done holds top-level tasks
    /// that would be listed if they were open and were completed within the window, newest first.
    func columns(from all: [TaskItem], in scope: TaskScope) -> [BoardColumn] {
        let query = query
        let open = query.tasks(from: all, in: scope)
        let windowStart = calendar.date(byAdding: .day, value: -Self.doneWindowDays, to: now) ?? now

        let done = all
            .filter { task in
                guard task.parent == nil, task.isDone, let completedAt = task.completedAt else { return false }
                return completedAt >= windowStart && query.wouldList(task, in: scope)
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.completedAt ?? .distantPast
                let rhsDate = rhs.completedAt ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return lhs.sortIndex < rhs.sortIndex
            }

        return [
            BoardColumn(status: .todo, tasks: open.filter { $0.status == .todo }),
            BoardColumn(status: .inProgress, tasks: open.filter { $0.status == .inProgress }),
            BoardColumn(status: .done, tasks: done),
        ]
    }

    /// Applies a drop: resolves each dragged payload and moves its task to `status`.
    /// Returns whether any task changed column.
    @discardableResult
    func drop(_ payloads: [String], onto status: TaskStatus, from all: [TaskItem]) -> Bool {
        var moved = false
        for payload in payloads {
            guard let id = Self.taskID(fromPayload: payload),
                  let task = all.first(where: { $0.persistentModelID == id }),
                  task.status != status else { continue }
            task.updateStatus(status, at: now)
            moved = true
        }
        return moved
    }

    // MARK: Drag payload

    private static let payloadPrefix = "agenda.task:"

    /// A plain-text drag payload that identifies a task within this app.
    static func dragPayload(for task: TaskItem) -> String? {
        guard let data = try? JSONEncoder().encode(task.persistentModelID),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return payloadPrefix + json
    }

    static func taskID(fromPayload payload: String) -> PersistentIdentifier? {
        guard payload.hasPrefix(payloadPrefix) else { return nil }
        let json = Data(payload.dropFirst(payloadPrefix.count).utf8)
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: json)
    }
}

extension TaskQuery {
    /// Whether the list for `scope` would show `task` if it were open.
    /// Mirrors the scope rules in `tasks(from:in:)` without the open-status check.
    func wouldList(_ task: TaskItem, in scope: TaskScope) -> Bool {
        guard task.parent == nil else { return false }
        let startOfToday = calendar.startOfDay(for: now)

        switch scope {
        case .completed:
            return true
        case .inbox:
            return task.dueDate == nil && task.scheduledStart == nil
        case .today:
            guard let day = relevantDay(for: task) else { return false }
            return day <= startOfToday
        case .upcoming:
            guard let day = relevantDay(for: task) else { return false }
            return day > startOfToday
        case .tag(let tagID):
            return (task.tags ?? []).contains { $0.persistentModelID == tagID }
        }
    }
}
