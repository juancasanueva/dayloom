import Foundation

/// Whether the calendar shows one day, one week, or a whole month.
enum CalendarScope: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }
}

/// Month grid rules: whole weeks covering the month, and what each day holds.
struct MonthCalendar {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Every day of the weeks that touch the month containing `date`, from the first week's start.
    func days(containing date: Date) -> [Date] {
        let range = interval(containing: date)
        var days: [Date] = []
        var day = range.start
        while day < range.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// From the start of the week holding the 1st to the end of the week holding the last day.
    func interval(containing date: Date) -> DateInterval {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay) else {
            return DateInterval(start: calendar.startOfDay(for: date), duration: 24 * 60 * 60)
        }
        return DateInterval(start: firstWeek.start, end: lastWeek.end)
    }

    func shift(_ date: Date, byMonths months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    func isInSameMonth(_ day: Date, as date: Date) -> Bool {
        calendar.isDate(day, equalTo: date, toGranularity: .month)
    }

    /// Entries touching `day`: all-day ones first, then by start time.
    func entries(_ entries: [CalendarEntry], on day: Date) -> [CalendarEntry] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return entries
            .filter { $0.start < end && $0.end > start }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }
}
