import Foundation
import SwiftData

/// The weekdays a habit is scheduled on, keyed by `Calendar` weekday numbers
/// (1 = Sunday … 7 = Saturday): weekday `n` is bit `n - 1`.
nonisolated struct HabitDays: OptionSet, Hashable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(weekday: Int) {
        self.rawValue = 1 << (weekday - 1)
    }

    static let everyDay = HabitDays(rawValue: 0b111_1111)
    static let weekdays: HabitDays = [
        HabitDays(weekday: 2), HabitDays(weekday: 3), HabitDays(weekday: 4),
        HabitDays(weekday: 5), HabitDays(weekday: 6),
    ]

    func contains(weekday: Int) -> Bool {
        contains(HabitDays(weekday: weekday))
    }
}

/// A recurring personal routine tracked per day.
///
/// Every stored property has a default and relationships are optional so the
/// schema stays compatible with CloudKit-backed stores.
@Model
final class Habit {
    var name: String = ""
    var symbolName: String = "checkmark"
    var colorRaw: String = TagColor.blue.rawValue
    var weekdayMask: Int = HabitDays.everyDay.rawValue
    var createdAt: Date = Date.now
    var sortIndex: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion]? = []

    init(
        name: String,
        symbolName: String = "checkmark",
        color: TagColor = .blue,
        days: HabitDays = .everyDay,
        createdAt: Date = .now
    ) {
        self.name = name
        self.symbolName = symbolName
        self.colorRaw = color.rawValue
        self.weekdayMask = days.rawValue
        self.createdAt = createdAt
        self.sortIndex = createdAt.timeIntervalSinceReferenceDate
    }

    var color: TagColor {
        get { TagColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    var days: HabitDays {
        get { HabitDays(rawValue: weekdayMask) }
        set { weekdayMask = newValue.rawValue }
    }

    // MARK: Rules

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        days.contains(weekday: calendar.component(.weekday, from: date))
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completion(on: date, calendar: calendar) != nil
    }

    /// Marks the day as done, or clears it when it already was. One completion per day;
    /// clearing removes every completion of the day, since sync can bring in copies.
    func toggle(on date: Date, calendar: Calendar = .current) {
        let existing = (completions ?? []).filter { calendar.isDate($0.day, inSameDayAs: date) }
        if !existing.isEmpty {
            // Detach first so the relationship reflects the removal before the context saves.
            completions?.removeAll { completion in existing.contains { $0 === completion } }
            existing.forEach { modelContext?.delete($0) }
        } else {
            let completion = HabitCompletion(day: calendar.startOfDay(for: date))
            modelContext?.insert(completion)
            completion.habit = self
        }
    }

    /// Consecutive completed scheduled days counted backwards from today. Unscheduled
    /// days are skipped, and a scheduled day still pending today doesn't break the run.
    func currentStreak(asOf now: Date, calendar: Calendar = .current) -> Int {
        guard !days.isEmpty else { return 0 }
        let completed = completedDays(calendar: calendar)
        guard let earliest = completed.min() else { return 0 }

        var day = calendar.startOfDay(for: now)
        if isScheduled(on: day, calendar: calendar) && !completed.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while day >= earliest {
            if isScheduled(on: day, calendar: calendar) {
                guard completed.contains(day) else { break }
                streak += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Completed scheduled days ÷ scheduled days over the last 30 days (today included),
    /// ignoring days before the habit was created. Today only counts once it is done.
    /// Returns `nil` when no scheduled day has elapsed yet.
    func completionRate(asOf now: Date, calendar: Calendar = .current) -> Double? {
        let today = calendar.startOfDay(for: now)
        let created = calendar.startOfDay(for: createdAt)
        let completed = completedDays(calendar: calendar)

        var scheduled = 0
        var done = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today), day >= created else { break }
            guard isScheduled(on: day, calendar: calendar) else { continue }
            let isDone = completed.contains(day)
            if day == today && !isDone { continue }
            scheduled += 1
            if isDone { done += 1 }
        }
        return scheduled == 0 ? nil : Double(done) / Double(scheduled)
    }

    // MARK: Helpers

    private func completion(on date: Date, calendar: Calendar) -> HabitCompletion? {
        (completions ?? []).first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    private func completedDays(calendar: Calendar) -> Set<Date> {
        Set((completions ?? []).map { calendar.startOfDay(for: $0.day) })
    }
}

/// One day on which a habit was done, stored as the start of that day.
@Model
final class HabitCompletion {
    var day: Date = Date.distantPast
    var habit: Habit?

    init(day: Date) {
        self.day = day
    }
}

enum HabitWeek {
    /// The seven days of the week containing `date`, starting on the calendar's first weekday.
    static func days(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
