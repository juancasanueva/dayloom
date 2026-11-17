import Foundation
import Testing
@testable import agenda

@MainActor
struct LauncherParserTests {
    private func parse(_ text: String) -> LauncherInput {
        LauncherParser.parse(text, now: TestClock.now, calendar: TestClock.calendar)
    }

    @Test func plainTextBecomesTheTitleWithCollapsedWhitespace() {
        let input = parse("  Buy   oat\tmilk  ")

        #expect(input.title == "Buy oat milk")
        #expect(input.day == nil)
        #expect(input.start == nil)
        #expect(input.duration == nil)
        #expect(input.priority == .none)
        #expect(input.tagNames.isEmpty)
        #expect(input.hasTitle)
    }

    @Test(arguments: [
        ("Pay rent today", 11, 17),
        ("Pay rent tomorrow", 11, 18),
        ("Pay rent TMR", 11, 18),
        ("Pay rent next week", 11, 23),
        ("Pay rent in 3 days", 11, 20),
        ("Pay rent in 1 day", 11, 18),
        ("Pay rent in 2 weeks", 12, 1),
    ])
    func relativeDates(text: String, month: Int, day: Int) {
        let input = parse(text)

        #expect(input.title == "Pay rent")
        #expect(input.day == TestClock.date(2026, month, day))
        #expect(input.start == nil)
    }

    /// Today is Tuesday the 17th; a weekday means the next occurrence strictly after today.
    @Test(arguments: [
        ("tue", 24), ("Tuesday", 24), ("wed", 18), ("wednesday", 18), ("thu", 19),
        ("fri", 20), ("sat", 21), ("sun", 22), ("mon", 23), ("Monday", 23),
    ])
    func weekdays(token: String, expectedDay: Int) {
        let input = parse("Gym \(token)")

        #expect(input.title == "Gym")
        #expect(input.day == TestClock.date(2026, 11, expectedDay))
        #expect(input.start == nil)
    }

    @Test(arguments: [
        ("3pm", 15, 0), ("3:30pm", 15, 30), ("15:00", 15, 0), ("noon", 12, 0),
        ("midnight", 0, 0), ("at 9am", 9, 0), ("at 18:45", 18, 45), ("12am", 0, 0), ("12pm", 12, 0),
    ])
    func timeWithoutDateMeansToday(token: String, hour: Int, minute: Int) {
        let input = parse("Call Ana \(token)")

        #expect(input.title == "Call Ana")
        #expect(input.day == TestClock.date(2026, 11, 17))
        #expect(input.start == TestClock.date(2026, 11, 17, hour, minute))
    }

    @Test func dateAndTimeCombine() {
        let input = parse("Dentist fri at 3:30pm")

        #expect(input.title == "Dentist")
        #expect(input.day == TestClock.date(2026, 11, 20))
        #expect(input.start == TestClock.date(2026, 11, 20, 15, 30))
    }

    @Test(arguments: [
        ("for 30m", 30.0), ("for 45min", 45.0), ("for 1h", 60.0), ("for 1.5h", 90.0), ("for 90 minutes", 90.0),
    ])
    func durations(token: String, minutes: Double) {
        let input = parse("Deep work \(token)")

        #expect(input.title == "Deep work")
        #expect(input.duration == minutes * 60)
    }

    @Test(arguments: [
        ("!high", TaskPriority.high), ("!!!", .high),
        ("!medium", .medium), ("!med", .medium), ("!!", .medium),
        ("!low", .low), ("!", .low),
    ])
    func priorities(token: String, expected: TaskPriority) {
        let input = parse("Ship it \(token)")

        #expect(input.title == "Ship it")
        #expect(input.priority == expected)
    }

    @Test func tagsAreCollectedOnceIgnoringCase() {
        let input = parse("Plan #Work trip #travel #work")

        #expect(input.title == "Plan trip")
        #expect(input.tagNames == ["Work", "travel"])
    }

    @Test func everythingTogether() {
        let input = parse("Review budget tomorrow 9am for 45min !high #Finance")

        #expect(input.title == "Review budget")
        #expect(input.day == TestClock.date(2026, 11, 18))
        #expect(input.start == TestClock.date(2026, 11, 18, 9))
        #expect(input.duration == TimeInterval(45 * 60))
        #expect(input.priority == .high)
        #expect(input.tagNames == ["Finance"])
    }

    @Test func connectorWordsStayWhenNothingFollowsThem() {
        let input = parse("Meet at the cafe for lunch in a few days")

        #expect(input.title == "Meet at the cafe for lunch in a few days")
        #expect(input.day == nil)
        #expect(input.start == nil)
        #expect(input.duration == nil)
    }

    @Test func invalidTimesStayInTheTitle() {
        let input = parse("Room 3 13pm 25:00")

        #expect(input.title == "Room 3 13pm 25:00")
        #expect(input.start == nil)
        #expect(input.day == nil)
    }

    @Test func onlyTheFirstDateIsUsed() {
        let input = parse("Call today tomorrow")

        #expect(input.title == "Call tomorrow")
        #expect(input.day == TestClock.date(2026, 11, 17))
    }

    @Test func tokensOnlyLeaveNoTitle() {
        let input = parse("tomorrow 3pm #work")

        #expect(input.title.isEmpty)
        #expect(!input.hasTitle)
        #expect(input.start == TestClock.date(2026, 11, 18, 15))
    }

    @Test func eventSpanIsAllDayWithoutATime() throws {
        let span = try #require(parse("Holiday fri").eventSpan(calendar: TestClock.calendar))

        #expect(span.isAllDay)
        #expect(span.start == TestClock.date(2026, 11, 20))
        #expect(span.end == TestClock.date(2026, 11, 21))
    }

    @Test func eventSpanLastsOneHourByDefault() throws {
        let span = try #require(parse("Sync tomorrow 3pm").eventSpan(calendar: TestClock.calendar))

        #expect(!span.isAllDay)
        #expect(span.start == TestClock.date(2026, 11, 18, 15))
        #expect(span.end == TestClock.date(2026, 11, 18, 16))
    }

    @Test func eventSpanUsesTheParsedDuration() throws {
        let span = try #require(parse("Sync tomorrow 3pm for 30m").eventSpan(calendar: TestClock.calendar))

        #expect(span.end == TestClock.date(2026, 11, 18, 15, 30))
    }

    @Test func noEventSpanWithoutDateOrTime() {
        #expect(parse("Sync").eventSpan(calendar: TestClock.calendar) == nil)
    }
}
