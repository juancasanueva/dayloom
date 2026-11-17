import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct TaskQueryTests {
    let query = TaskQuery(now: TestClock.now, calendar: TestClock.calendar)

    private func titles(_ tasks: [TaskItem]) -> [String] { tasks.map(\.title) }

    @Test func inboxHoldsOpenUndatedTopLevelTasks() throws {
        let context = try makeInMemoryContext()
        let undated = TaskItem(title: "Undated")
        let due = TaskItem(title: "Due", dueDate: TestClock.date(2026, 11, 20))
        let scheduled = TaskItem(title: "Scheduled", scheduledStart: TestClock.date(2026, 11, 18, 9))
        let done = TaskItem(title: "Done")
        done.setCompleted(true, at: TestClock.now)
        [undated, due, scheduled, done].forEach(context.insert)
        let child = undated.addSubtask(title: "Child")

        let result = query.tasks(from: [undated, due, scheduled, done, child], in: .inbox)

        #expect(titles(result) == ["Undated"])
    }

    @Test func todayIncludesDueTodayOverdueAndScheduledToday() {
        let dueToday = TaskItem(title: "Due today", dueDate: TestClock.date(2026, 11, 17))
        let overdue = TaskItem(title: "Overdue", dueDate: TestClock.date(2026, 11, 15))
        let scheduledToday = TaskItem(title: "Scheduled today", scheduledStart: TestClock.date(2026, 11, 17, 15))
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: TestClock.date(2026, 11, 18))
        let undated = TaskItem(title: "Undated")

        let result = query.tasks(from: [dueToday, overdue, scheduledToday, tomorrow, undated], in: .today)

        #expect(Set(titles(result)) == ["Due today", "Overdue", "Scheduled today"])
    }

    @Test func upcomingIncludesOnlyFutureDays() {
        let today = TaskItem(title: "Today", dueDate: TestClock.date(2026, 11, 17))
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: TestClock.date(2026, 11, 18))
        let nextWeek = TaskItem(title: "Next week", scheduledStart: TestClock.date(2026, 11, 24, 8))

        let result = query.tasks(from: [today, tomorrow, nextWeek], in: .upcoming)

        #expect(titles(result) == ["Tomorrow", "Next week"])
    }

    @Test func upcomingSectionsGroupByDayInOrder() {
        let a = TaskItem(title: "A", dueDate: TestClock.date(2026, 11, 19))
        let b = TaskItem(title: "B", dueDate: TestClock.date(2026, 11, 18))
        let c = TaskItem(title: "C", scheduledStart: TestClock.date(2026, 11, 19, 16))

        let sections = query.upcomingSections(from: [a, b, c])

        #expect(sections.map(\.day) == [TestClock.date(2026, 11, 18), TestClock.date(2026, 11, 19)])
        #expect(titles(sections[0].tasks) == ["B"])
        #expect(Set(titles(sections[1].tasks)) == ["A", "C"])
    }

    @Test func relevantDayIsEarliestOfDueAndScheduled() {
        let task = TaskItem(
            title: "Both",
            dueDate: TestClock.date(2026, 11, 22),
            scheduledStart: TestClock.date(2026, 11, 19, 14)
        )

        #expect(query.relevantDay(for: task) == TestClock.date(2026, 11, 19))
    }

    @Test func completedListsDoneTasksMostRecentFirst() {
        let older = TaskItem(title: "Older")
        older.setCompleted(true, at: TestClock.date(2026, 11, 10))
        let newer = TaskItem(title: "Newer")
        newer.setCompleted(true, at: TestClock.date(2026, 11, 16))
        let open = TaskItem(title: "Open")

        let result = query.tasks(from: [older, newer, open], in: .completed)

        #expect(titles(result) == ["Newer", "Older"])
    }

    @Test func tagScopeListsOpenTasksWithThatTag() throws {
        let context = try makeInMemoryContext()
        let work = Tag(name: "Work", color: .blue)
        let home = Tag(name: "Home", color: .green)
        let tagged = TaskItem(title: "Tagged")
        let other = TaskItem(title: "Other")
        let doneTagged = TaskItem(title: "Done tagged")
        [tagged, other, doneTagged].forEach(context.insert)
        context.insert(work)
        context.insert(home)
        tagged.tags = [work]
        other.tags = [home]
        doneTagged.tags = [work]
        doneTagged.setCompleted(true, at: TestClock.now)
        try context.save()

        let result = query.tasks(from: [tagged, other, doneTagged], in: .tag(work.persistentModelID))

        #expect(titles(result) == ["Tagged"])
    }

    @Test func listsSortByPriorityThenDateThenCreation() {
        let lowEarly = TaskItem(title: "Low early", dueDate: TestClock.date(2026, 11, 17), priority: .low)
        let highLate = TaskItem(title: "High late", dueDate: TestClock.date(2026, 11, 17, 18), priority: .high)
        let highEarly = TaskItem(title: "High early", dueDate: TestClock.date(2026, 11, 16), priority: .high)
        let firstCreated = TaskItem(title: "First", priority: .medium, createdAt: TestClock.date(2026, 11, 1))
        let secondCreated = TaskItem(title: "Second", priority: .medium, createdAt: TestClock.date(2026, 11, 2))
        firstCreated.dueDate = TestClock.date(2026, 11, 17)
        secondCreated.dueDate = TestClock.date(2026, 11, 17)

        let result = query.tasks(
            from: [lowEarly, secondCreated, highLate, firstCreated, highEarly],
            in: .today
        )

        #expect(titles(result) == ["High early", "High late", "First", "Second", "Low early"])
    }

    @Test func overdueOnlyForOpenTasksDueBeforeToday() {
        let overdue = TaskItem(title: "Overdue", dueDate: TestClock.date(2026, 11, 16))
        let today = TaskItem(title: "Today", dueDate: TestClock.date(2026, 11, 17))
        let doneOverdue = TaskItem(title: "Done", dueDate: TestClock.date(2026, 11, 16))
        doneOverdue.setCompleted(true, at: TestClock.now)

        #expect(query.isOverdue(overdue))
        #expect(query.isOverdue(today) == false)
        #expect(query.isOverdue(doneOverdue) == false)
    }

    @Test func newTaskDefaultsDependOnScope() {
        #expect(query.defaultDueDate(for: .inbox) == nil)
        #expect(query.defaultDueDate(for: .today) == TestClock.date(2026, 11, 17))
        #expect(query.defaultDueDate(for: .upcoming) == TestClock.date(2026, 11, 18))
    }
}
