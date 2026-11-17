import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct TaskBoardTests {
    let board = TaskBoard(now: TestClock.now, calendar: TestClock.calendar)
    let query = TaskQuery(now: TestClock.now, calendar: TestClock.calendar)

    private func titles(_ tasks: [TaskItem]) -> [String] { tasks.map(\.title) }

    private func titles(in columns: [BoardColumn], _ status: TaskStatus) -> [String] {
        titles(columns.first { $0.status == status }?.tasks ?? [])
    }

    private func done(_ title: String, at date: Date, dueDate: Date? = nil) -> TaskItem {
        let task = TaskItem(title: title, dueDate: dueDate)
        task.updateStatus(.done, at: date)
        return task
    }

    private func inProgress(_ title: String, dueDate: Date? = nil, priority: TaskPriority = .none) -> TaskItem {
        let task = TaskItem(title: title, dueDate: dueDate, priority: priority)
        task.updateStatus(.inProgress, at: TestClock.now)
        return task
    }

    // MARK: Columns

    @Test func columnsAreToDoInProgressDoneInOrder() {
        let columns = board.columns(from: [], in: .inbox)

        #expect(columns.map(\.status) == [.todo, .inProgress, .done])
        #expect(columns.allSatisfy { $0.tasks.isEmpty })
    }

    @Test func inboxBoardHoldsUndatedTasksIncludingRecentlyDone() {
        let todo = TaskItem(title: "Todo")
        let working = inProgress("Working")
        let finished = done("Finished", at: TestClock.date(2026, 11, 16))
        let dated = TaskItem(title: "Dated", dueDate: TestClock.date(2026, 11, 17))
        let finishedDated = done("Finished dated", at: TestClock.date(2026, 11, 16), dueDate: TestClock.date(2026, 11, 17))

        let columns = board.columns(from: [todo, working, finished, dated, finishedDated], in: .inbox)

        #expect(titles(in: columns, .todo) == ["Todo"])
        #expect(titles(in: columns, .inProgress) == ["Working"])
        #expect(titles(in: columns, .done) == ["Finished"])
    }

    @Test func todayBoardDoneHoldsTasksThatWouldBeDueToday() {
        let dueToday = TaskItem(title: "Due today", dueDate: TestClock.date(2026, 11, 17))
        let doneToday = done("Done today", at: TestClock.date(2026, 11, 17, 9), dueDate: TestClock.date(2026, 11, 17))
        let doneOverdue = done("Done overdue", at: TestClock.date(2026, 11, 16), dueDate: TestClock.date(2026, 11, 12))
        let doneTomorrow = done("Done tomorrow", at: TestClock.date(2026, 11, 16), dueDate: TestClock.date(2026, 11, 18))
        let doneUndated = done("Done undated", at: TestClock.date(2026, 11, 16))

        let columns = board.columns(from: [dueToday, doneToday, doneOverdue, doneTomorrow, doneUndated], in: .today)

        #expect(titles(in: columns, .todo) == ["Due today"])
        #expect(titles(in: columns, .inProgress).isEmpty)
        #expect(titles(in: columns, .done) == ["Done today", "Done overdue"])
    }

    @Test func upcomingBoardDoneHoldsTasksThatWouldBeInTheFuture() {
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: TestClock.date(2026, 11, 18))
        let scheduled = inProgress("Scheduled")
        scheduled.scheduledStart = TestClock.date(2026, 11, 20, 9)
        let doneFuture = done("Done future", at: TestClock.date(2026, 11, 17, 8), dueDate: TestClock.date(2026, 11, 21))
        let doneToday = done("Done today", at: TestClock.date(2026, 11, 17, 8), dueDate: TestClock.date(2026, 11, 17))

        let columns = board.columns(from: [tomorrow, scheduled, doneFuture, doneToday], in: .upcoming)

        #expect(titles(in: columns, .todo) == ["Tomorrow"])
        #expect(titles(in: columns, .inProgress) == ["Scheduled"])
        #expect(titles(in: columns, .done) == ["Done future"])
    }

    @Test func tagBoardHoldsOnlyTasksWithThatTag() throws {
        let context = try makeInMemoryContext()
        let work = Tag(name: "Work", color: .blue)
        let home = Tag(name: "Home", color: .green)
        let tagged = TaskItem(title: "Tagged")
        let taggedWorking = inProgress("Tagged working")
        let taggedDone = done("Tagged done", at: TestClock.date(2026, 11, 15))
        let otherDone = done("Other done", at: TestClock.date(2026, 11, 15))
        [tagged, taggedWorking, taggedDone, otherDone].forEach(context.insert)
        context.insert(work)
        context.insert(home)
        tagged.tags = [work]
        taggedWorking.tags = [work]
        taggedDone.tags = [work]
        otherDone.tags = [home]
        try context.save()

        let columns = board.columns(
            from: [tagged, taggedWorking, taggedDone, otherDone],
            in: .tag(work.persistentModelID)
        )

        #expect(titles(in: columns, .todo) == ["Tagged"])
        #expect(titles(in: columns, .inProgress) == ["Tagged working"])
        #expect(titles(in: columns, .done) == ["Tagged done"])
    }

    @Test func openColumnsKeepTheListOrder() {
        let low = TaskItem(title: "Low", dueDate: TestClock.date(2026, 11, 17), priority: .low)
        let high = TaskItem(title: "High", dueDate: TestClock.date(2026, 11, 17), priority: .high)
        let workingLow = inProgress("Working low", dueDate: TestClock.date(2026, 11, 17), priority: .low)
        let workingHigh = inProgress("Working high", dueDate: TestClock.date(2026, 11, 16), priority: .high)
        let medium = TaskItem(title: "Medium", dueDate: TestClock.date(2026, 11, 15), priority: .medium)
        let all = [low, workingLow, high, medium, workingHigh]

        let columns = board.columns(from: all, in: .today)

        #expect(titles(in: columns, .todo) == ["High", "Medium", "Low"])
        #expect(titles(in: columns, .inProgress) == ["Working high", "Working low"])
        let listOrder = titles(query.tasks(from: all, in: .today))
        #expect(listOrder.filter { titles(in: columns, .todo).contains($0) } == titles(in: columns, .todo))
        #expect(listOrder.filter { titles(in: columns, .inProgress).contains($0) } == titles(in: columns, .inProgress))
    }

    // MARK: Done window

    @Test func doneColumnKeepsTasksCompletedWithinTheLastSevenDays() {
        let sixDaysAgo = done("Six days ago", at: TestClock.date(2026, 11, 11, 10))
        let eightDaysAgo = done("Eight days ago", at: TestClock.date(2026, 11, 9, 10))

        let columns = board.columns(from: [sixDaysAgo, eightDaysAgo], in: .inbox)

        #expect(titles(in: columns, .done) == ["Six days ago"])
    }

    @Test func doneColumnListsMostRecentlyCompletedFirst() {
        let monday = done("Monday", at: TestClock.date(2026, 11, 16, 9))
        let thisMorning = done("This morning", at: TestClock.date(2026, 11, 17, 8))
        let lastWeek = done("Last week", at: TestClock.date(2026, 11, 12, 18))

        let columns = board.columns(from: [monday, lastWeek, thisMorning], in: .inbox)

        #expect(titles(in: columns, .done) == ["This morning", "Monday", "Last week"])
    }

    @Test func subtasksNeverAppearOnTheBoard() throws {
        let context = try makeInMemoryContext()
        let parent = TaskItem(title: "Parent")
        context.insert(parent)
        let openChild = parent.addSubtask(title: "Open child")
        let doneChild = parent.addSubtask(title: "Done child")
        doneChild.updateStatus(.done, at: TestClock.date(2026, 11, 16))
        let workingChild = parent.addSubtask(title: "Working child")
        workingChild.updateStatus(.inProgress, at: TestClock.now)

        let columns = board.columns(from: [parent, openChild, doneChild, workingChild], in: .inbox)

        #expect(titles(in: columns, .todo) == ["Parent"])
        #expect(titles(in: columns, .inProgress).isEmpty)
        #expect(titles(in: columns, .done).isEmpty)
    }

    // MARK: Scope predicate

    @Test func scopePredicateAgreesWithTheListForOpenTasks() throws {
        let context = try makeInMemoryContext()
        let work = Tag(name: "Work", color: .blue)
        context.insert(work)
        let sample = [
            TaskItem(title: "Undated"),
            TaskItem(title: "Overdue", dueDate: TestClock.date(2026, 11, 10)),
            TaskItem(title: "Today", dueDate: TestClock.date(2026, 11, 17)),
            TaskItem(title: "Scheduled today", scheduledStart: TestClock.date(2026, 11, 17, 22)),
            TaskItem(title: "Tomorrow", dueDate: TestClock.date(2026, 11, 18)),
            TaskItem(title: "Mixed", dueDate: TestClock.date(2026, 11, 25), scheduledStart: TestClock.date(2026, 11, 17, 9)),
        ]
        sample.forEach(context.insert)
        sample[0].tags = [work]
        sample[4].tags = [work]
        try context.save()

        for scope in [TaskScope.inbox, .today, .upcoming, .tag(work.persistentModelID)] {
            let listed = Set(titles(query.tasks(from: sample, in: scope)))
            let matched = Set(titles(sample.filter { query.wouldList($0, in: scope) }))
            #expect(listed == matched, "scope \(scope)")
        }
    }

    // MARK: Moving between columns

    @Test func droppingAPayloadMovesTheTaskAndTracksCompletion() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Card")
        context.insert(task)
        try context.save()
        let payload = try #require(TaskBoard.dragPayload(for: task))

        #expect(board.drop([payload], onto: .inProgress, from: [task]))
        #expect(task.status == .inProgress)
        #expect(task.completedAt == nil)

        #expect(board.drop([payload], onto: .done, from: [task]))
        #expect(task.status == .done)
        #expect(task.completedAt == TestClock.now)

        #expect(board.drop([payload], onto: .todo, from: [task]))
        #expect(task.status == .todo)
        #expect(task.completedAt == nil)
    }

    @Test func droppingOntoTheSameColumnOrAForeignStringChangesNothing() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Card")
        context.insert(task)
        try context.save()
        let payload = try #require(TaskBoard.dragPayload(for: task))

        #expect(board.drop([payload], onto: .todo, from: [task]) == false)
        #expect(board.drop(["just some text"], onto: .done, from: [task]) == false)
        #expect(task.status == .todo)
        #expect(task.completedAt == nil)
    }

    // MARK: List mode

    @Test func listModeResultsAreUnchanged() throws {
        let context = try makeInMemoryContext()
        let work = Tag(name: "Work", color: .blue)
        context.insert(work)
        let undated = TaskItem(title: "Undated")
        let working = inProgress("Working", dueDate: TestClock.date(2026, 11, 17), priority: .medium)
        let today = TaskItem(title: "Today", dueDate: TestClock.date(2026, 11, 17), priority: .high)
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: TestClock.date(2026, 11, 18))
        let finished = done("Finished", at: TestClock.date(2026, 11, 16))
        let oldFinished = done("Old finished", at: TestClock.date(2026, 10, 1))
        let all = [undated, working, today, tomorrow, finished, oldFinished]
        all.forEach(context.insert)
        undated.tags = [work]
        finished.tags = [work]
        try context.save()

        #expect(titles(query.tasks(from: all, in: .inbox)) == ["Undated"])
        #expect(titles(query.tasks(from: all, in: .today)) == ["Today", "Working"])
        #expect(titles(query.tasks(from: all, in: .upcoming)) == ["Tomorrow"])
        #expect(titles(query.tasks(from: all, in: .completed)) == ["Finished", "Old finished"])
        #expect(titles(query.tasks(from: all, in: .tag(work.persistentModelID))) == ["Undated"])
    }
}
