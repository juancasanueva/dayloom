import Foundation
import SwiftData

enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case todo
    case inProgress
    case done

    var id: Self { self }

    var title: String {
        switch self {
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }
}

enum TaskPriority: Int, CaseIterable, Codable, Comparable, Identifiable {
    case none = 0
    case low
    case medium
    case high

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SubtaskProgress: Equatable {
    var done: Int
    var total: Int
}

/// A to-do item. Top-level tasks live in smart lists; subtasks hang off a parent.
///
/// Every stored property has a default and relationships are optional so the
/// schema stays compatible with CloudKit-backed stores.
@Model
final class TaskItem {
    var title: String = ""
    var notes: String = ""
    var statusRaw: String = TaskStatus.todo.rawValue
    var priorityRaw: Int = TaskPriority.none.rawValue
    var dueDate: Date?
    var scheduledStart: Date?
    var scheduledDuration: TimeInterval = 60 * 60
    var createdAt: Date = Date.now
    var completedAt: Date?
    var sortIndex: Double = 0
    var repeatRuleRaw: String = RepeatRule.none.rawValue

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var subtasks: [TaskItem]? = []
    var parent: TaskItem?

    @Relationship(inverse: \Tag.tasks)
    var tags: [Tag]? = []

    /// Note blocks that show this task. Deleting the task unlinks them.
    @Relationship(deleteRule: .nullify, inverse: \NoteBlock.task)
    var noteBlocks: [NoteBlock]? = []

    init(
        title: String,
        dueDate: Date? = nil,
        scheduledStart: Date? = nil,
        priority: TaskPriority = .none,
        createdAt: Date = .now
    ) {
        self.title = title
        self.dueDate = dueDate
        self.scheduledStart = scheduledStart
        self.priorityRaw = priority.rawValue
        self.createdAt = createdAt
        self.sortIndex = createdAt.timeIntervalSinceReferenceDate
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }

    /// Repeating only takes effect once the task has a due date or a scheduled start.
    var canRepeat: Bool { dueDate != nil || scheduledStart != nil }

    var isDone: Bool { status == .done }

    var scheduledEnd: Date? {
        scheduledStart.map { $0.addingTimeInterval(scheduledDuration) }
    }

    var orderedSubtasks: [TaskItem] {
        (subtasks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var orderedTags: [Tag] {
        (tags ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var subtaskProgress: SubtaskProgress {
        let all = subtasks ?? []
        return SubtaskProgress(done: all.filter(\.isDone).count, total: all.count)
    }

    func setCompleted(_ completed: Bool, at date: Date = .now, calendar: Calendar = .current) {
        updateStatus(completed ? .done : .todo, at: date, calendar: calendar)
    }

    /// Changes the status. Moving a repeating task into `.done` also creates its next occurrence.
    func updateStatus(_ newStatus: TaskStatus, at date: Date = .now, calendar: Calendar = .current) {
        let wasDone = isDone
        status = newStatus
        completedAt = newStatus == .done ? (completedAt ?? date) : nil
        if newStatus == .done && !wasDone {
            spawnNextOccurrence(createdAt: date, calendar: calendar)
        }
    }

    /// Inserts the next open copy of a repeating task and stops this one from repeating,
    /// so completing it again never spawns a second copy. Does nothing outside a context
    /// or when the task has no date to advance.
    private func spawnNextOccurrence(createdAt: Date, calendar: Calendar) {
        let rule = repeatRule
        guard rule.repeats, canRepeat, let modelContext else { return }

        let next = TaskItem(
            title: title,
            dueDate: dueDate.flatMap { rule.nextDate(after: $0, calendar: calendar) },
            scheduledStart: scheduledStart.flatMap { rule.nextDate(after: $0, calendar: calendar) },
            priority: priority,
            createdAt: createdAt
        )
        next.notes = notes
        next.scheduledDuration = scheduledDuration
        next.repeatRule = rule
        modelContext.insert(next)
        next.tags = tags ?? []
        for subtask in orderedSubtasks {
            next.addSubtask(title: subtask.title)
        }

        repeatRule = .none
    }

    /// Creates a subtask appended after the existing ones. The parent must already be in a context.
    @discardableResult
    func addSubtask(title: String) -> TaskItem {
        let child = TaskItem(title: title)
        child.sortIndex = (orderedSubtasks.last?.sortIndex ?? 0) + 1
        modelContext?.insert(child)
        child.parent = self
        return child
    }
}
