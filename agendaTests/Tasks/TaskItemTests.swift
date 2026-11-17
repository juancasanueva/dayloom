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
}
