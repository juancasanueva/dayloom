import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct TaskItemTests {
    @Test func newTaskStartsOpenWithDefaults() {
        let task = TaskItem(title: "Write report")

        #expect(task.title == "Write report")
        #expect(task.status == .todo)
        #expect(task.priority == .none)
        #expect(task.isDone == false)
        #expect(task.completedAt == nil)
    }

    @Test func completingSetsStatusAndTimestamp() {
        let task = TaskItem(title: "Pay rent")

        task.setCompleted(true, at: TestClock.now)

        #expect(task.status == .done)
        #expect(task.isDone)
        #expect(task.completedAt == TestClock.now)
    }

    @Test func reopeningClearsCompletion() {
        let task = TaskItem(title: "Pay rent")
        task.setCompleted(true, at: TestClock.now)

        task.setCompleted(false, at: TestClock.now)

        #expect(task.status == .todo)
        #expect(task.completedAt == nil)
    }

    @Test func settingStatusToDoneRecordsCompletion() {
        let task = TaskItem(title: "Review PR")

        task.updateStatus(.done, at: TestClock.now)
        #expect(task.completedAt == TestClock.now)

        task.updateStatus(.inProgress, at: TestClock.now)
        #expect(task.completedAt == nil)
        #expect(task.status == .inProgress)
    }

    @Test func subtaskProgressCountsDoneChildren() throws {
        let context = try makeInMemoryContext()
        let parent = TaskItem(title: "Launch")
        context.insert(parent)

        let first = parent.addSubtask(title: "Design")
        _ = parent.addSubtask(title: "Build")
        first.setCompleted(true, at: TestClock.now)

        #expect(parent.subtaskProgress == SubtaskProgress(done: 1, total: 2))
        #expect(parent.orderedSubtasks.map(\.title) == ["Design", "Build"])
        #expect(first.parent === parent)
    }

    @Test func deletingEverySubtaskKeepsTheParent() throws {
        let context = try makeInMemoryContext()
        let parent = TaskItem(title: "Launch")
        context.insert(parent)
        let first = parent.addSubtask(title: "Design")
        let second = parent.addSubtask(title: "Build")
        try context.save()

        context.delete(first)
        context.delete(second)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).map(\.title) == ["Launch"])
        #expect(parent.orderedSubtasks.isEmpty)
    }

    @Test func scheduledEndUsesDuration() {
        let start = TestClock.date(2026, 11, 17, 9, 0)
        let task = TaskItem(title: "Focus", scheduledStart: start)
        task.scheduledDuration = 90 * 60

        #expect(task.scheduledEnd == TestClock.date(2026, 11, 17, 10, 30))
    }

    @Test func priorityOrderingIsAscendingByUrgency() {
        #expect(TaskPriority.none < .low)
        #expect(TaskPriority.low < .medium)
        #expect(TaskPriority.medium < .high)
    }

    // MARK: Recurrence

    private func topLevelTasks(in context: ModelContext) throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>()).filter { $0.parent == nil }
    }

    @Test func newTaskDoesNotRepeat() {
        #expect(TaskItem(title: "Once").repeatRule == .none)
    }

    @Test func completingRepeatingTaskSpawnsNextOpenOccurrence() throws {
        let context = try makeInMemoryContext()
        let home = Tag(name: "Home", color: .green)
        let chores = Tag(name: "Chores", color: .orange)
        context.insert(home)
        context.insert(chores)
        let task = TaskItem(
            title: "Water plants",
            dueDate: TestClock.date(2026, 11, 17),
            scheduledStart: TestClock.date(2026, 11, 17, 9, 0),
            priority: .high
        )
        context.insert(task)
        task.notes = "Balcony first"
        task.scheduledDuration = 45 * 60
        task.repeatRule = .daily
        task.tags = [home, chores]
        let first = task.addSubtask(title: "Fill can")
        task.addSubtask(title: "Check soil")
        first.setCompleted(true, at: TestClock.now)

        task.setCompleted(true, at: TestClock.now, calendar: TestClock.calendar)

        let spawned = try #require(try topLevelTasks(in: context).first { $0 !== task })
        #expect(try topLevelTasks(in: context).count == 2)
        #expect(spawned.title == "Water plants")
        #expect(spawned.notes == "Balcony first")
        #expect(spawned.priority == .high)
        #expect(spawned.scheduledDuration == 45 * 60)
        #expect(spawned.dueDate == TestClock.date(2026, 11, 18))
        #expect(spawned.scheduledStart == TestClock.date(2026, 11, 18, 9, 0))
        #expect(spawned.repeatRule == .daily)
        #expect(spawned.status == .todo)
        #expect(spawned.completedAt == nil)
        #expect(spawned.orderedTags.map(\.name) == ["Chores", "Home"])
        #expect(spawned.orderedSubtasks.map(\.title) == ["Fill can", "Check soil"])
        #expect(spawned.orderedSubtasks.allSatisfy { !$0.isDone })
        #expect(spawned.orderedSubtasks.allSatisfy { $0.parent === spawned })

        #expect(task.status == .done)
        #expect(task.repeatRule == .none)
        #expect(task.orderedSubtasks.map(\.title) == ["Fill can", "Check soil"])
        #expect(task.orderedTags.map(\.name) == ["Chores", "Home"])
    }

    @Test func completingAgainAfterReopeningSpawnsOnlyOnce() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Stand-up", dueDate: TestClock.date(2026, 11, 17))
        context.insert(task)
        task.repeatRule = .weekly

        task.updateStatus(.done, at: TestClock.now, calendar: TestClock.calendar)
        task.updateStatus(.todo, at: TestClock.now, calendar: TestClock.calendar)
        task.updateStatus(.done, at: TestClock.now, calendar: TestClock.calendar)

        let all = try topLevelTasks(in: context)
        #expect(all.count == 2)
        #expect(all.filter { $0 !== task }.map(\.dueDate) == [TestClock.date(2026, 11, 24)])
    }

    @Test func weekdaysTaskDueFridaySpawnsOnMonday() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Report", dueDate: TestClock.date(2026, 11, 20))
        context.insert(task)
        task.repeatRule = .weekdays

        task.setCompleted(true, at: TestClock.now, calendar: TestClock.calendar)

        let spawned = try #require(try topLevelTasks(in: context).first { $0 !== task })
        #expect(spawned.dueDate == TestClock.date(2026, 11, 23))
        #expect(spawned.scheduledStart == nil)
    }

    @Test func repeatingTaskWithoutDatesSpawnsNothing() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Someday")
        context.insert(task)
        task.repeatRule = .daily

        task.setCompleted(true, at: TestClock.now, calendar: TestClock.calendar)

        #expect(try topLevelTasks(in: context).count == 1)
        #expect(task.isDone)
    }

    @Test func repeatingTaskOutsideAContextSpawnsNothing() {
        let task = TaskItem(title: "Detached", dueDate: TestClock.date(2026, 11, 17))
        task.repeatRule = .daily

        task.setCompleted(true, at: TestClock.now, calendar: TestClock.calendar)

        #expect(task.isDone)
        #expect(task.completedAt == TestClock.now)
        #expect(task.repeatRule == .daily)
    }

    @Test func completingNonRepeatingTaskCreatesNoExtraTasks() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "One-off", dueDate: TestClock.date(2026, 11, 17))
        context.insert(task)

        task.setCompleted(true, at: TestClock.now)
        task.updateStatus(.inProgress, at: TestClock.now)
        task.updateStatus(.done, at: TestClock.now)

        #expect(try topLevelTasks(in: context).count == 1)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(task.completedAt == TestClock.now)
    }
}
