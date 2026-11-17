import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct HabitsHeadingTests {
    private let calendar = TestClock.calendar

    private func subtitle(_ habits: [Habit]) -> String {
        HabitsHeading.subtitle(for: habits, now: TestClock.now, calendar: calendar)
    }

    @Test func noHabitsInvitesTheFirstOne() {
        #expect(subtitle([]) == "No habits yet")
    }

    @Test func nothingScheduledTodaySaysSo() throws {
        let context = try makeInMemoryContext()
        let weekend = Habit(name: "Hike", days: [HabitDays(weekday: 1), HabitDays(weekday: 7)])
        context.insert(weekend)

        #expect(subtitle([weekend]) == "Nothing due today")
    }

    @Test func countsOnlyHabitsDueTodayAndTheirCheckIns() throws {
        let context = try makeInMemoryContext()
        let read = Habit(name: "Read")
        let walk = Habit(name: "Walk")
        let weekend = Habit(name: "Hike", days: [HabitDays(weekday: 1), HabitDays(weekday: 7)])
        [read, walk, weekend].forEach(context.insert)
        read.toggle(on: TestClock.now, calendar: calendar)

        #expect(subtitle([read, walk, weekend]) == "1 of 2 done today")
    }

    @Test func everyCheckInDoneSaysAllDone() throws {
        let context = try makeInMemoryContext()
        let read = Habit(name: "Read")
        let walk = Habit(name: "Walk")
        [read, walk].forEach(context.insert)
        read.toggle(on: TestClock.now, calendar: calendar)
        walk.toggle(on: TestClock.now, calendar: calendar)

        #expect(subtitle([read, walk]) == "All 2 done today")
    }
}
