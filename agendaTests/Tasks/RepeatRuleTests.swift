import Foundation
import Testing
@testable import agenda

@MainActor
struct RepeatRuleTests {
    private let calendar = TestClock.calendar

    @Test func noneNeverProducesANextDate() {
        #expect(RepeatRule.none.nextDate(after: TestClock.now, calendar: calendar) == nil)
    }

    @Test func dailyAdvancesOneDayAcrossMonthEnd() {
        let next = RepeatRule.daily.nextDate(after: TestClock.date(2026, 11, 30, 9, 15), calendar: calendar)

        #expect(next == TestClock.date(2026, 12, 1, 9, 15))
    }

    @Test func weekdaysAdvancesToNextDayWhenMidWeek() {
        // Tuesday → Wednesday.
        let next = RepeatRule.weekdays.nextDate(after: TestClock.date(2026, 11, 17, 8), calendar: calendar)

        #expect(next == TestClock.date(2026, 11, 18, 8))
    }

    @Test func weekdaysSkipsTheWeekendFromFriday() {
        // Friday → Monday.
        let next = RepeatRule.weekdays.nextDate(after: TestClock.date(2026, 11, 20, 8), calendar: calendar)

        #expect(next == TestClock.date(2026, 11, 23, 8))
    }

    @Test func weekdaysFromSaturdayLandsOnMonday() {
        let next = RepeatRule.weekdays.nextDate(after: TestClock.date(2026, 11, 21), calendar: calendar)

        #expect(next == TestClock.date(2026, 11, 23))
    }

    @Test func weeklyAdvancesSevenDays() {
        let next = RepeatRule.weekly.nextDate(after: TestClock.date(2026, 11, 17, 14), calendar: calendar)

        #expect(next == TestClock.date(2026, 11, 24, 14))
    }

    @Test func monthlyKeepsTheDayOfMonth() {
        let next = RepeatRule.monthly.nextDate(after: TestClock.date(2026, 3, 15), calendar: calendar)

        #expect(next == TestClock.date(2026, 4, 15))
    }

    @Test func monthlyFromJanuary31ClampsToEndOfFebruary() {
        let next = RepeatRule.monthly.nextDate(after: TestClock.date(2026, 1, 31), calendar: calendar)

        #expect(next == TestClock.date(2026, 2, 28))
    }

    @Test func everyRuleExceptNoneRepeats() {
        #expect(RepeatRule.none.repeats == false)
        #expect(RepeatRule.allCases.filter(\.repeats) == [.daily, .weekdays, .weekly, .monthly])
    }
}
