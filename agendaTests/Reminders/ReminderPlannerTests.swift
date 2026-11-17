import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Task reminders")
struct ReminderPlannerTests {
    let planner = ReminderPlanner(now: TestClock.now, calendar: TestClock.calendar, locale: Locale(identifier: "en_GB"))
    let on = ReminderSettings(isEnabled: true, lead: .fifteenMinutes, allDayMinutes: 9 * 60)

    private func task(_ key: String, due: Date? = nil, start: Date? = nil, done: Bool = false) -> ReminderCandidate {
        ReminderCandidate(key: key, title: "Task \(key)", dueDate: due, scheduledStart: start, isDone: done)
    }

    @Test func timedTasksAreRemindedTheChosenTimeBeforeTheyStart() {
        let plan = planner.plan([task("a", start: TestClock.date(2026, 11, 17, 15))], settings: on)

        #expect(plan.count == 1)
        #expect(plan.first?.fireDate == TestClock.date(2026, 11, 17, 14, 45))
        #expect(plan.first?.title == "Task a")
        #expect(plan.first?.body == "Starts at 15:00")
        #expect(plan.first?.taskKey == "a")
    }

    @Test(arguments: [
        (ReminderLead.atStart, TestClock.date(2026, 11, 18, 15)),
        (.fiveMinutes, TestClock.date(2026, 11, 18, 14, 55)),
        (.thirtyMinutes, TestClock.date(2026, 11, 18, 14, 30)),
        (.oneHour, TestClock.date(2026, 11, 18, 14)),
        (.oneDay, TestClock.date(2026, 11, 17, 15)),
    ])
    func eachLeadTimeMovesTheReminder(lead: ReminderLead, expected: Date) {
        var settings = on
        settings.lead = lead

        let plan = planner.plan([task("a", start: TestClock.date(2026, 11, 18, 15))], settings: settings)

        #expect(plan.first?.fireDate == expected)
    }

    @Test func tasksWithOnlyADueDateAreRemindedAtTheChosenTimeThatDay() {
        let plan = planner.plan([task("a", due: TestClock.date(2026, 11, 18))], settings: on)

        #expect(plan.first?.fireDate == TestClock.date(2026, 11, 18, 9))
        #expect(plan.first?.body == "Due today")
    }

    @Test func aScheduledTimeWinsOverTheDueDate() {
        let plan = planner.plan([task("a", due: TestClock.date(2026, 11, 18), start: TestClock.date(2026, 11, 18, 16))], settings: on)

        #expect(plan.first?.fireDate == TestClock.date(2026, 11, 18, 15, 45))
    }

    @Test func doneTasksUndatedTasksAndPastRemindersAreSkipped() {
        let plan = planner.plan([
            task("done", start: TestClock.date(2026, 11, 18, 15), done: true),
            task("undated"),
            task("past", start: TestClock.date(2026, 11, 17, 10, 5)), // 15 minutes before is 9:50, already gone
            task("today", due: TestClock.date(2026, 11, 17)),          // 9:00 today, already gone
            task("kept", start: TestClock.date(2026, 11, 17, 11)),
        ], settings: on)

        #expect(plan.map(\.taskKey) == ["kept"])
    }

    @Test func nothingIsPlannedWhenRemindersAreOff() {
        var off = on
        off.isEnabled = false

        #expect(planner.plan([task("a", start: TestClock.date(2026, 11, 18, 15))], settings: off).isEmpty)
    }

    @Test func remindersAreSoonestFirstAndCappedToTheSystemLimit() {
        let candidates = (0..<80).reversed().map { index in
            task("t\(index)", start: TestClock.date(2026, 11, 18).addingTimeInterval(TimeInterval(index) * 3600))
        }

        let plan = planner.plan(candidates, settings: on)

        #expect(plan.count == ReminderPlanner.limit)
        #expect(plan.first?.taskKey == "t0")
        #expect(plan.map(\.fireDate) == plan.map(\.fireDate).sorted())
    }

    @Test func eachReminderHasAStableIdentifierPerTask() {
        let plan = planner.plan([task("a", start: TestClock.date(2026, 11, 18, 15))], settings: on)

        #expect(plan.first?.id == ReminderPlanner.identifierPrefix + "a")
    }

    @Test func aReminderKeyLeadsBackToItsTask() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Call the bank")
        context.insert(task)
        try context.save()

        let key = try #require(TaskReminderKey.key(for: task.persistentModelID))

        #expect(TaskReminderKey.identifier(from: key) == task.persistentModelID)
        #expect(TaskReminderKey.identifier(from: "not a key") == nil)
    }

    // MARK: Settings

    private func makeDefaults() -> UserDefaults {
        let name = "ReminderSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func settingsStartOffWithFifteenMinutesAndNineInTheMorning() {
        let store = ReminderSettingsStore(defaults: makeDefaults())

        #expect(store.settings == ReminderSettings(isEnabled: false, lead: .fifteenMinutes, allDayMinutes: 9 * 60))
    }

    @Test func settingsAreRememberedAcrossLaunches() {
        let defaults = makeDefaults()
        let store = ReminderSettingsStore(defaults: defaults)
        store.settings = ReminderSettings(isEnabled: true, lead: .oneHour, allDayMinutes: 8 * 60 + 30)

        #expect(ReminderSettingsStore(defaults: defaults).settings == store.settings)
    }
}
