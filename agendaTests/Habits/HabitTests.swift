import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
struct HabitTests {
    private let calendar = TestClock.calendar

    /// Inserts a habit and marks the given days of November 2026 as completed.
    private func makeHabit(
        in context: ModelContext,
        days: HabitDays = .everyDay,
        createdAt: Date = TestClock.date(2026, 9, 1),
        completedNovemberDays: [Int] = []
    ) -> Habit {
        let habit = Habit(name: "Read", symbolName: "book.fill", color: .purple, days: days, createdAt: createdAt)
        context.insert(habit)
        for day in completedNovemberDays {
            habit.toggle(on: TestClock.date(2026, 11, day, 20), calendar: calendar)
        }
        return habit
    }

    // MARK: Schedule

    @Test func newHabitHasDefaults() {
        let habit = Habit(name: "Stretch")

        #expect(habit.name == "Stretch")
        #expect(habit.days == .everyDay)
        #expect(habit.color == .blue)
        #expect((habit.completions ?? []).isEmpty)
    }

    @Test func daysMapCalendarWeekdaysToBits() {
        #expect(HabitDays(weekday: 1).rawValue == 0b1)
        #expect(HabitDays(weekday: 7).rawValue == 0b100_0000)
        #expect(HabitDays.everyDay.rawValue == 0b111_1111)
        #expect(HabitDays.weekdays == [HabitDays(weekday: 2), HabitDays(weekday: 3), HabitDays(weekday: 4), HabitDays(weekday: 5), HabitDays(weekday: 6)])
        #expect(HabitDays.weekdays.contains(weekday: 1) == false)
        #expect(HabitDays.weekdays.contains(weekday: 6))
    }

    @Test func isScheduledFollowsTheChosenWeekdays() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, days: .weekdays)

        #expect(habit.isScheduled(on: TestClock.now, calendar: calendar)) // Tuesday
        #expect(habit.isScheduled(on: TestClock.date(2026, 11, 20, 23, 59), calendar: calendar)) // Friday
        #expect(habit.isScheduled(on: TestClock.date(2026, 11, 21), calendar: calendar) == false) // Saturday
        #expect(habit.isScheduled(on: TestClock.date(2026, 11, 22), calendar: calendar) == false) // Sunday
    }

    // MARK: Completions

    @Test func toggleRecordsOneCompletionAtStartOfDay() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context)

        habit.toggle(on: TestClock.now, calendar: calendar)

        #expect(habit.isCompleted(on: TestClock.date(2026, 11, 17, 23), calendar: calendar))
        #expect(habit.isCompleted(on: TestClock.date(2026, 11, 16, 23), calendar: calendar) == false)
        #expect(habit.completions?.map(\.day) == [TestClock.date(2026, 11, 17)])
        #expect(try context.fetch(FetchDescriptor<HabitCompletion>()).count == 1)
    }

    @Test func togglingTwiceOnTheSameDayRemovesTheCompletion() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context)

        habit.toggle(on: TestClock.date(2026, 11, 17, 8), calendar: calendar)
        habit.toggle(on: TestClock.date(2026, 11, 17, 21), calendar: calendar)
        try context.save()

        #expect(habit.isCompleted(on: TestClock.now, calendar: calendar) == false)
        #expect((habit.completions ?? []).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HabitCompletion>()).isEmpty)
    }

    @Test func deletingAHabitDeletesItsCompletions() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, completedNovemberDays: [15, 16])
        try context.save()

        context.delete(habit)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<HabitCompletion>()).isEmpty)
    }

    // MARK: Streak

    @Test func streakCountsTodayWhenDone() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, completedNovemberDays: [15, 16, 17])

        #expect(habit.currentStreak(asOf: TestClock.now, calendar: calendar) == 3)
    }

    @Test func streakStartsFromYesterdayWhileTodayIsPending() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, completedNovemberDays: [14, 15, 16])

        #expect(habit.currentStreak(asOf: TestClock.now, calendar: calendar) == 3)
    }

    @Test func aMissedScheduledDayBreaksTheStreak() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, completedNovemberDays: [13, 14, 16, 17])

        #expect(habit.currentStreak(asOf: TestClock.now, calendar: calendar) == 2)
    }

    @Test func streakIsZeroWhenYesterdayWasMissedAndTodayIsPending() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, completedNovemberDays: [14, 15])

        #expect(habit.currentStreak(asOf: TestClock.now, calendar: calendar) == 0)
    }

    @Test func unscheduledDaysAreSkipped() throws {
        let context = try makeInMemoryContext()
        // Weekdays only: Sat 14 and Sun 15 are skipped; Mon 16, Fri 13, Thu 12 count, Wed 11 breaks.
        let habit = makeHabit(in: context, days: .weekdays, completedNovemberDays: [12, 13, 16])

        #expect(habit.currentStreak(asOf: TestClock.now, calendar: calendar) == 3)
    }

    @Test func habitWithoutScheduledDaysHasNoStreak() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, days: [], completedNovemberDays: [16, 17])

        #expect(habit.currentStreak(asOf: TestClock.now, calendar: calendar) == 0)
    }

    // MARK: Completion rate

    @Test func completionRateExcludesDaysBeforeCreation() throws {
        let context = try makeInMemoryContext()
        // Created Tue Nov 10 in the afternoon: Nov 10…16 are 7 scheduled days; today is still pending.
        let habit = makeHabit(
            in: context,
            createdAt: TestClock.date(2026, 11, 10, 15),
            completedNovemberDays: [5, 10, 11, 12, 16]
        )

        #expect(habit.completionRate(asOf: TestClock.now, calendar: calendar) == 4.0 / 7.0)
    }

    @Test func completionRateCountsTodayOnceDone() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(
            in: context,
            createdAt: TestClock.date(2026, 11, 10, 15),
            completedNovemberDays: [10, 11, 12, 16, 17]
        )

        #expect(habit.completionRate(asOf: TestClock.now, calendar: calendar) == 5.0 / 8.0)
    }

    @Test func completionRateLooksBackThirtyDays() throws {
        let context = try makeInMemoryContext()
        let habit = Habit(name: "Walk", createdAt: TestClock.date(2026, 9, 1))
        context.insert(habit)
        habit.toggle(on: TestClock.date(2026, 10, 18), calendar: calendar) // Outside the window.
        habit.toggle(on: TestClock.date(2026, 10, 19), calendar: calendar) // First day of the window.

        // Oct 19 … Nov 16 are 29 elapsed days; today is pending.
        #expect(habit.completionRate(asOf: TestClock.now, calendar: calendar) == 1.0 / 29.0)
    }

    @Test func completionRateOnlyCountsScheduledDays() throws {
        let context = try makeInMemoryContext()
        // Weekdays since Mon Nov 9: Nov 9…13 and Nov 16 are 6 scheduled days.
        let habit = makeHabit(
            in: context,
            days: .weekdays,
            createdAt: TestClock.date(2026, 11, 9),
            completedNovemberDays: [9, 14, 15, 16]
        )

        #expect(habit.completionRate(asOf: TestClock.now, calendar: calendar) == 2.0 / 6.0)
    }

    @Test func completionRateIsNilWithoutElapsedScheduledDays() throws {
        let context = try makeInMemoryContext()
        let habit = makeHabit(in: context, createdAt: TestClock.date(2026, 11, 17, 8))

        #expect(habit.completionRate(asOf: TestClock.now, calendar: calendar) == nil)
    }

    // MARK: Week

    @Test func weekContainingDateStartsOnTheCalendarsFirstWeekday() {
        let days = HabitWeek.days(containing: TestClock.now, calendar: calendar)

        #expect(days == (16...22).map { TestClock.date(2026, 11, $0) })
    }
}
