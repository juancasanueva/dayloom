import Foundation
import SwiftData

enum LauncherActionError: Error, Equatable {
    /// An event needs a date or a time.
    case nothingToSchedule
}

/// Runs the launcher's create actions.
enum LauncherActions {
    /// Inserts a task built from `input` and saves, so the new task has a permanent ID.
    ///
    /// A time schedules the task (`scheduledStart`, plus the duration when given) and leaves the due date empty.
    /// A date alone becomes the due date. Missing tags are created once, matching names ignoring case.
    @discardableResult
    static func createTask(from input: LauncherInput, in context: ModelContext) throws -> TaskItem {
        let task = TaskItem(
            title: input.title,
            dueDate: input.start == nil ? input.day : nil,
            scheduledStart: input.start,
            priority: input.priority
        )
        if input.start != nil, let duration = input.duration {
            task.scheduledDuration = duration
        }
        context.insert(task)
        task.tags = try tags(named: input.tagNames, in: context)
        try context.save()
        return task
    }

    /// Writes an event built from `input` to the default calendar and reloads the week.
    static func createEvent(from input: LauncherInput, in model: WeekCalendarModel, calendar: Calendar) throws {
        guard let span = input.eventSpan(calendar: calendar) else { throw LauncherActionError.nothingToSchedule }
        try model.createEvent(title: input.title, start: span.start, end: span.end, isAllDay: span.isAllDay)
    }

    private static func tags(named names: [String], in context: ModelContext) throws -> [Tag] {
        guard !names.isEmpty else { return [] }
        var existing = try context.fetch(FetchDescriptor<Tag>())
        var result: [Tag] = []

        for name in names {
            if let tag = existing.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if !result.contains(where: { $0 === tag }) { result.append(tag) }
                continue
            }
            let tag = Tag(name: name, color: TagColor.next(after: existing.count))
            context.insert(tag)
            existing.append(tag)
            result.append(tag)
        }
        return result
    }
}
