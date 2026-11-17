import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct LauncherResultsTests {
    private func parse(_ text: String) -> LauncherInput {
        LauncherParser.parse(text, now: TestClock.now, calendar: TestClock.calendar)
    }

    private func rows(_ text: String, tasks: [TaskItem] = [], access: CalendarAccess = .granted) -> [LauncherRow] {
        LauncherResults.rows(for: parse(text), query: text, tasks: tasks, calendarAccess: access)
    }

    private func kinds(_ rows: [LauncherRow]) -> [String] {
        rows.map { row in
            switch row {
            case .newTask: "task"
            case .newEvent: "event"
            case .existing(let task): task.title
            }
        }
    }

    @Test func titleOnlyOffersNewTask() {
        #expect(kinds(rows("Buy milk")) == ["task"])
    }

    @Test func dateOffersNewEventWhenAccessIsGranted() {
        #expect(kinds(rows("Buy milk tomorrow")) == ["task", "event"])
        #expect(kinds(rows("Buy milk 3pm")) == ["task", "event"])
    }

    @Test func noNewEventWithoutCalendarAccess() {
        #expect(kinds(rows("Buy milk tomorrow", access: .denied)) == ["task"])
        #expect(kinds(rows("Buy milk tomorrow", access: .notDetermined)) == ["task"])
    }

    @Test func noCreateRowsWithoutATitle() {
        #expect(kinds(rows("tomorrow 3pm")).isEmpty)
        #expect(kinds(rows("   ")).isEmpty)
    }

    @Test func newRowsCarryTheParsedInput() throws {
        let result = rows("Standup tomorrow 9am")

        guard case .newEvent(let input) = try #require(result.last) else {
            Issue.record("Expected a New Event row")
            return
        }
        #expect(input.title == "Standup")
        #expect(input.start == TestClock.date(2026, 11, 18, 9))
    }

    @Test func matchesIgnoreCaseAndDiacriticsWithOpenTasksFirst() {
        let done = TaskItem(title: "cafe receipts")
        done.setCompleted(true, at: TestClock.now)
        let tasks = [done, TaskItem(title: "Café with Leo"), TaskItem(title: "CAFE supplies"), TaskItem(title: "Groceries")]

        let matches = LauncherResults.matchingTasks(tasks, query: "cafe")

        #expect(matches.map(\.title) == ["Café with Leo", "CAFE supplies", "cafe receipts"])
    }

    @Test func atMostEightMatches() {
        let tasks = (1...10).map { TaskItem(title: "Report \($0)") }

        #expect(LauncherResults.matchingTasks(tasks, query: "report").count == 8)
    }

    @Test func emptyQueryMatchesNothing() {
        #expect(LauncherResults.matchingTasks([TaskItem(title: "Anything")], query: "  ").isEmpty)
    }

    @Test func rowsListCreateActionsBeforeMatches() {
        let tasks = [TaskItem(title: "Water plants"), TaskItem(title: "Taxes")]

        #expect(kinds(rows("water", tasks: tasks)) == ["task", "Water plants"])
    }

    @Test func searchIgnoresParsedDateTokens() {
        let tasks = [TaskItem(title: "Dentist"), TaskItem(title: "Friday review")]

        #expect(kinds(rows("dentist fri", tasks: tasks)) == ["task", "event", "Dentist"])
    }
}
