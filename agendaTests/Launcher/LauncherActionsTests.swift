import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct LauncherActionsTests {
    private func parse(_ text: String) -> LauncherInput {
        LauncherParser.parse(text, now: TestClock.now, calendar: TestClock.calendar)
    }

    // MARK: Tasks

    @Test func timedTaskIsScheduledWithoutDueDate() throws {
        let context = try makeInMemoryContext()

        let task = try LauncherActions.createTask(from: parse("Standup tomorrow 9am for 15m !med"), in: context)

        #expect(task.title == "Standup")
        #expect(task.scheduledStart == TestClock.date(2026, 11, 18, 9))
        #expect(task.scheduledDuration == 15 * 60)
        #expect(task.dueDate == nil)
        #expect(task.priority == .medium)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

    @Test func timedTaskWithoutDurationKeepsTheDefault() throws {
        let context = try makeInMemoryContext()

        let task = try LauncherActions.createTask(from: parse("Call Ana 3pm"), in: context)

        #expect(task.scheduledStart == TestClock.date(2026, 11, 17, 15))
        #expect(task.scheduledDuration == 60 * 60)
        #expect(task.dueDate == nil)
    }

    @Test func dateOnlyTaskGetsDueDateAtStartOfDay() throws {
        let context = try makeInMemoryContext()

        let task = try LauncherActions.createTask(from: parse("Pay rent fri"), in: context)

        #expect(task.title == "Pay rent")
        #expect(task.dueDate == TestClock.date(2026, 11, 20))
        #expect(task.scheduledStart == nil)
        #expect(task.priority == .none)
        #expect((task.tags ?? []).isEmpty)
    }

    @Test func plainTaskHasNoDates() throws {
        let context = try makeInMemoryContext()

        let task = try LauncherActions.createTask(from: parse("Read a book"), in: context)

        #expect(task.title == "Read a book")
        #expect(task.dueDate == nil)
        #expect(task.scheduledStart == nil)
        #expect(task.status == .todo)
    }

    @Test func tagsReuseExistingOnesIgnoringCaseAndCreateMissingOnesOnce() throws {
        let context = try makeInMemoryContext()
        let work = agenda.Tag(name: "Work", color: .purple)
        context.insert(work)
        try context.save()

        let task = try LauncherActions.createTask(from: parse("Prepare deck #work #Home #home"), in: context)

        let allTags = try context.fetch(FetchDescriptor<agenda.Tag>(sortBy: [SortDescriptor(\.name)]))
        #expect(allTags.map(\.name) == ["Home", "Work"])
        #expect(task.orderedTags.map(\.name) == ["Home", "Work"])
        #expect(task.orderedTags.last === work)
        #expect(work.color == .purple)
        #expect(task.orderedTags.first?.color == TagColor.next(after: 1))
    }

    @Test func missingTagsGetDistinctColors() throws {
        let context = try makeInMemoryContext()

        let task = try LauncherActions.createTask(from: parse("Trip #travel #family"), in: context)

        let colors = Dictionary(uniqueKeysWithValues: task.orderedTags.map { ($0.name, $0.color) })
        #expect(colors == ["travel": TagColor.next(after: 0), "family": TagColor.next(after: 1)])
        #expect(try context.fetchCount(FetchDescriptor<agenda.Tag>()) == 2)
    }

    // MARK: Events

    private func makeCalendarModel(access: CalendarAccess = .granted) -> (WeekCalendarModel, StaticCalendarSource) {
        let source = StaticCalendarSource(access: access)
        let model = WeekCalendarModel(source: source, week: WeekCalendar(calendar: TestClock.calendar), anchor: TestClock.now)
        return (model, source)
    }

    @Test func timedEventIsWrittenAndTheWeekReloads() throws {
        let (model, source) = makeCalendarModel()

        try LauncherActions.createEvent(from: parse("Standup tomorrow 9am for 15m"), in: model, calendar: TestClock.calendar)

        let entry = try #require(source.entries.first)
        #expect(source.entries.count == 1)
        #expect(entry.title == "Standup")
        #expect(entry.start == TestClock.date(2026, 11, 18, 9))
        #expect(entry.end == TestClock.date(2026, 11, 18, 9, 15))
        #expect(!entry.isAllDay)
        #expect(entry.kind == .event)
        #expect(model.events.map(\.id) == [entry.id])
    }

    @Test func dateOnlyEventIsAllDay() throws {
        let (model, source) = makeCalendarModel()

        try LauncherActions.createEvent(from: parse("Holiday fri"), in: model, calendar: TestClock.calendar)

        let entry = try #require(source.entries.first)
        #expect(entry.title == "Holiday")
        #expect(entry.isAllDay)
        #expect(entry.start == TestClock.date(2026, 11, 20))
        #expect(entry.end == TestClock.date(2026, 11, 21))
    }

    @Test func eventWithoutDateIsRejected() {
        let (model, source) = makeCalendarModel()

        #expect(throws: LauncherActionError.nothingToSchedule) {
            try LauncherActions.createEvent(from: parse("Standup"), in: model, calendar: TestClock.calendar)
        }
        #expect(source.entries.isEmpty)
    }

    @Test func eventWithoutAccessThrows() {
        let (model, source) = makeCalendarModel(access: .denied)

        #expect(throws: CalendarWriteError.accessDenied) {
            try LauncherActions.createEvent(from: parse("Standup tomorrow 9am"), in: model, calendar: TestClock.calendar)
        }
        #expect(source.entries.isEmpty)
    }
}
