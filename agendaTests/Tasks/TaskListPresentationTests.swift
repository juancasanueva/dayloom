import Foundation
import Testing
@testable import agenda

@MainActor
@Suite("Task list presentation")
struct TaskListPresentationTests {
    let query = TaskQuery(now: TestClock.now, calendar: TestClock.calendar)
    let locale = Locale(identifier: "en_GB")

    // MARK: Time emphasis (S2.3)

    @Test func overdueTasksAreEmphasizedAsOverdue() {
        let dueYesterday = TaskItem(title: "Late", dueDate: TestClock.date(2026, 11, 16))
        let missedSlot = TaskItem(title: "Missed", scheduledStart: TestClock.date(2026, 11, 17, 9))

        #expect(query.timeEmphasis(for: dueYesterday) == .overdue)
        #expect(query.timeEmphasis(for: missedSlot) == .overdue)
    }

    @Test func tasksForLaterTodayAreEmphasizedAsToday() {
        let dueToday = TaskItem(title: "Due", dueDate: TestClock.date(2026, 11, 17))
        let laterToday = TaskItem(title: "Later", scheduledStart: TestClock.date(2026, 11, 17, 15))

        #expect(query.timeEmphasis(for: dueToday) == .today)
        #expect(query.timeEmphasis(for: laterToday) == .today)
    }

    @Test func futureUndatedAndDoneTasksAreNotEmphasized() {
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: TestClock.date(2026, 11, 18))
        let undated = TaskItem(title: "Someday")
        let doneLate = TaskItem(title: "Done", dueDate: TestClock.date(2026, 11, 16))
        doneLate.setCompleted(true, at: TestClock.now)

        #expect(query.timeEmphasis(for: tomorrow) == .normal)
        #expect(query.timeEmphasis(for: undated) == .normal)
        #expect(query.timeEmphasis(for: doneLate) == .normal)
    }

    // MARK: Keyboard selection (S4.1)

    @Test(arguments: [
        (nil as Int?, 1, 10 as Int?),
        (nil, -1, 30),
        (10, 1, 20),
        (20, -1, 10),
        (30, 1, 30),
        (10, -1, 10),
        (99, 1, 10),
    ])
    func arrowKeysStepThroughTheList(current: Int?, offset: Int, expected: Int?) {
        #expect(ListNavigation.step(from: current, in: [10, 20, 30], by: offset) == expected)
    }

    @Test func steppingAnEmptyListSelectsNothing() {
        #expect(ListNavigation.step(from: nil, in: [Int](), by: 1) == nil)
    }

    // MARK: Day column (S2.1)

    @Test func dayColumnNamesTodayTomorrowThenWeekdays() {
        let names = [17, 18, 19].map {
            DayFormatting.dayName(for: TestClock.date(2026, 11, $0), now: TestClock.now, calendar: TestClock.calendar, locale: locale)
        }

        #expect(names == ["Today", "Tomorrow", "Thursday"])
    }

    @Test func dayColumnShowsTheDateUnderTheName() {
        let date = DayFormatting.shortDate(for: TestClock.date(2026, 11, 19), calendar: TestClock.calendar, locale: locale)

        #expect(date == "19 Nov")
    }

    // MARK: Page subtitle (S1.2)

    @Test func subtitlesDescribeEachList() {
        func subtitle(_ scope: TaskScope, _ count: Int) -> String {
            TaskListHeading.subtitle(for: scope, count: count, now: TestClock.now, calendar: TestClock.calendar, locale: locale)
        }

        #expect(subtitle(.today, 2) == "Tuesday 17 November")
        #expect(subtitle(.inbox, 1) == "1 task without a date")
        #expect(subtitle(.inbox, 0) == "Nothing waiting")
        #expect(subtitle(.upcoming, 3) == "3 tasks ahead")
        #expect(subtitle(.completed, 4) == "4 finished")
    }
}
