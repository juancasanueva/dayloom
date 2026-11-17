import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct WeekCalendarTests {
    let week = WeekCalendar(calendar: TestClock.calendar)
    let day = TestClock.date(2026, 11, 17)

    private func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEntry {
        CalendarEntry(id: id, title: id, start: start, end: end, isAllDay: allDay, kind: .event, tint: .accent)
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        TestClock.date(2026, 11, 17, hour, minute)
    }

    @Test func weekStartsOnCalendarFirstWeekday() {
        let days = week.days(containing: TestClock.now)

        #expect(days.count == 7)
        #expect(days.first == TestClock.date(2026, 11, 16))
        #expect(days.last == TestClock.date(2026, 11, 22))
    }

    @Test func intervalCoversWholeWeek() {
        let interval = week.interval(containing: TestClock.now)

        #expect(interval.start == TestClock.date(2026, 11, 16))
        #expect(interval.end == TestClock.date(2026, 11, 23))
    }

    @Test func shiftingMovesByWholeWeeks() {
        #expect(week.shift(TestClock.now, byWeeks: 1) == TestClock.date(2026, 11, 24, 10))
        #expect(week.shift(TestClock.now, byWeeks: -1) == TestClock.date(2026, 11, 10, 10))
    }

    @Test func separateEntriesShareFullWidth() {
        let layout = week.layout([event("A", at(9), at(10)), event("B", at(11), at(12))], on: day)

        #expect(layout.map(\.column) == [0, 0])
        #expect(layout.map(\.columnCount) == [1, 1])
        #expect(layout.map(\.startMinute) == [540, 660])
        #expect(layout.map(\.endMinute) == [600, 720])
    }

    @Test func overlappingEntriesSplitIntoColumns() {
        let layout = week.layout([event("A", at(9), at(11)), event("B", at(10), at(12))], on: day)

        #expect(layout.map(\.entry.id) == ["A", "B"])
        #expect(layout.map(\.column) == [0, 1])
        #expect(layout.map(\.columnCount) == [2, 2])
    }

    @Test func chainedOverlapReusesFreedColumns() {
        let layout = week.layout([
            event("A", at(9), at(10)),
            event("B", at(9, 30), at(11)),
            event("C", at(10), at(11, 30)),
        ], on: day)

        #expect(layout.map(\.column) == [0, 1, 0])
        #expect(layout.map(\.columnCount) == [2, 2, 2])
    }

    @Test func entriesCrossingMidnightAreClippedPerDay() {
        let late = event("Late", TestClock.date(2026, 11, 17, 23), TestClock.date(2026, 11, 18, 1))

        let first = week.layout([late], on: day)
        let second = week.layout([late], on: TestClock.date(2026, 11, 18))

        #expect(first.map(\.startMinute) == [1380])
        #expect(first.map(\.endMinute) == [1440])
        #expect(second.map(\.startMinute) == [0])
        #expect(second.map(\.endMinute) == [60])
    }

    @Test func veryShortEntriesGetMinimumHeight() {
        let layout = week.layout([event("Blip", at(9), at(9, 5))], on: day)

        #expect(layout.first?.endMinute == 540 + WeekCalendar.minimumEntryMinutes)
    }

    @Test func allDayEntriesStayOutOfTimedLayout() {
        let allDay = event("Holiday", day, TestClock.date(2026, 11, 18), allDay: true)
        let timed = event("Meeting", at(9), at(10))

        #expect(week.layout([allDay, timed], on: day).map(\.entry.id) == ["Meeting"])
        #expect(week.allDayEntries([allDay, timed], on: day).map(\.id) == ["Holiday"])
        #expect(week.allDayEntries([allDay], on: TestClock.date(2026, 11, 18)).isEmpty)
    }

    @Test func scheduledTasksBecomeEntriesInsideInterval() {
        let interval = week.interval(containing: TestClock.now)
        let scheduled = TaskItem(title: "Deep work", scheduledStart: at(14))
        scheduled.scheduledDuration = 30 * 60
        let outside = TaskItem(title: "Later", scheduledStart: TestClock.date(2026, 12, 1, 9))
        let unscheduled = TaskItem(title: "Someday")

        let entries = CalendarEntry.scheduledTasks([scheduled, outside, unscheduled], in: interval)

        #expect(entries.map(\.title) == ["Deep work"])
        #expect(entries.first?.start == at(14))
        #expect(entries.first?.end == at(14, 30))
        #expect(entries.first?.taskID == scheduled.persistentModelID)
    }

    // MARK: New task slots

    static let slotCases: [(minute: Double, expected: Date)] = [
        (0, TestClock.date(2026, 11, 18, 0)),
        (29, TestClock.date(2026, 11, 18, 0)),
        (30, TestClock.date(2026, 11, 18, 0, 30)),
        (947, TestClock.date(2026, 11, 18, 15, 30)), // 15:47
        (-20, TestClock.date(2026, 11, 18, 0)),
        (1450, TestClock.date(2026, 11, 18, 23, 30)), // past midnight
    ]

    @Test(arguments: slotCases)
    func aPointInTheDaySnapsToTheHalfHourItFallsIn(slot: (minute: Double, expected: Date)) {
        #expect(week.slotStart(on: TestClock.date(2026, 11, 18), atMinute: slot.minute) == slot.expected)
    }
}
