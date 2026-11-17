import Foundation
import Testing
@testable import agenda

@MainActor
@Suite("Month calendar")
struct MonthCalendarTests {
    let month = MonthCalendar(calendar: TestClock.calendar)

    private func entry(_ id: String, start: Date, end: Date, allDay: Bool = false) -> CalendarEntry {
        CalendarEntry(id: id, title: id, start: start, end: end, isAllDay: allDay, kind: .event, tint: .accent)
    }

    @Test func gridCoversWholeWeeksAroundTheMonth() {
        // November 2026 starts on a Sunday and ends on a Monday; weeks start on Monday.
        let days = month.days(containing: TestClock.now)

        #expect(days.count == 42)
        #expect(days.first == TestClock.date(2026, 10, 26))
        #expect(days.last == TestClock.date(2026, 12, 6))
    }

    @Test func aMonthThatFitsInFiveWeeksShowsFiveRows() {
        // February 2027 starts on a Monday and ends on a Sunday: exactly four weeks.
        let days = month.days(containing: TestClock.date(2027, 2, 10))

        #expect(days.count == 28)
        #expect(days.first == TestClock.date(2027, 2, 1))
        #expect(days.last == TestClock.date(2027, 2, 28))
    }

    @Test func intervalSpansTheWholeGrid() {
        let interval = month.interval(containing: TestClock.now)

        #expect(interval.start == TestClock.date(2026, 10, 26))
        #expect(interval.end == TestClock.date(2026, 12, 7))
    }

    @Test func movingByMonthsKeepsAValidDay() {
        #expect(month.shift(TestClock.date(2027, 1, 31), byMonths: 1) == TestClock.date(2027, 2, 28))
        #expect(month.shift(TestClock.now, byMonths: -1) == TestClock.date(2026, 10, 17, 10))
    }

    @Test func daysOutsideTheMonthAreMarked() {
        #expect(month.isInSameMonth(TestClock.date(2026, 11, 30), as: TestClock.now))
        #expect(!month.isInSameMonth(TestClock.date(2026, 10, 31), as: TestClock.now))
    }

    @Test func eachDayListsItsEntriesAllDayFirstThenByTime() {
        let entries = [
            entry("Lunch", start: TestClock.date(2026, 11, 18, 12), end: TestClock.date(2026, 11, 18, 13)),
            entry("Standup", start: TestClock.date(2026, 11, 18, 9), end: TestClock.date(2026, 11, 18, 9, 15)),
            entry("Trip", start: TestClock.date(2026, 11, 17), end: TestClock.date(2026, 11, 20), allDay: true),
            entry("Other day", start: TestClock.date(2026, 11, 19, 9), end: TestClock.date(2026, 11, 19, 10)),
        ]

        #expect(month.entries(entries, on: TestClock.date(2026, 11, 18)).map(\.id) == ["Trip", "Standup", "Lunch"])
        #expect(month.entries(entries, on: TestClock.date(2026, 11, 20)).isEmpty)
    }

    // MARK: Model

    private func makeModel() -> WeekCalendarModel {
        let source = StaticCalendarSource(access: .granted, entries: [
            entry("This week", start: TestClock.date(2026, 11, 18, 9), end: TestClock.date(2026, 11, 18, 10)),
            entry("Later this month", start: TestClock.date(2026, 11, 28, 9), end: TestClock.date(2026, 11, 28, 10)),
            entry("Next month", start: TestClock.date(2026, 12, 15, 9), end: TestClock.date(2026, 12, 15, 10)),
        ])
        return WeekCalendarModel(source: source, week: WeekCalendar(calendar: TestClock.calendar), anchor: TestClock.now)
    }

    @Test func switchingToMonthShowsAndLoadsTheMonth() {
        let model = makeModel()
        model.reload()
        #expect(model.days.count == 7)
        #expect(model.events.map(\.id) == ["This week"])

        model.scope = .month

        #expect(model.days.count == 42)
        #expect(model.events.map(\.id) == ["This week", "Later this month"])
    }

    @Test func inMonthScopeNavigationMovesByMonth() {
        let model = makeModel()
        model.scope = .month

        model.showNext()
        #expect(model.events.map(\.id) == ["Next month"])

        model.showPrevious()
        model.showPrevious()
        #expect(model.events.isEmpty)
    }

    @Test func inWeekScopeNavigationStillMovesByWeek() {
        let model = makeModel()
        model.reload()

        model.showNext()

        #expect(model.days.first == TestClock.date(2026, 11, 23))
    }

    @Test func goingToADayShowsItsWeek() {
        let model = makeModel()
        model.scope = .month

        model.showWeek(of: TestClock.date(2026, 11, 28))

        #expect(model.scope == .week)
        #expect(model.days.first == TestClock.date(2026, 11, 23))
    }
}
