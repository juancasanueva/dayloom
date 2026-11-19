import Foundation

/// How a task comes back after it is completed.
enum RepeatRule: String, CaseIterable, Codable, Identifiable {
    case none
    case daily
    case weekdays
    case weekly
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .none: String(appLocalized: "Never")
        case .daily: String(appLocalized: "Every Day")
        case .weekdays: String(appLocalized: "Every Weekday")
        case .weekly: String(appLocalized: "Every Week")
        case .monthly: String(appLocalized: "Every Month")
        }
    }

    /// The rule inside a sentence, as in "Repeats every day".
    var phrase: String {
        switch self {
        case .none: String(appLocalized: "never")
        case .daily: String(appLocalized: "every day")
        case .weekdays: String(appLocalized: "every weekday")
        case .weekly: String(appLocalized: "every week")
        case .monthly: String(appLocalized: "every month")
        }
    }

    var repeats: Bool { self != .none }

    /// The matching date of the next occurrence, keeping the time of day.
    ///
    /// `weekdays` moves to the next Monday–Friday; `monthly` uses the calendar's month
    /// arithmetic, so Jan 31 becomes the last day of February.
    func nextDate(after date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            var next = date
            repeat {
                guard let candidate = calendar.date(byAdding: .day, value: 1, to: next) else { return nil }
                next = candidate
            } while Self.isWeekend(next, calendar: calendar)
            return next
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    /// Saturday and Sunday, by Gregorian weekday number, regardless of locale.
    private static func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}
