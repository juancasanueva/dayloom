import Foundation
import Observation

/// State for the calendar: which week or month is shown and the events loaded for it.
@Observable
final class WeekCalendarModel {
    private(set) var anchor: Date
    private(set) var events: [CalendarEntry] = []
    private(set) var access: CalendarAccess

    /// Week or month; changing it reloads the events for the new range.
    var scope: CalendarScope = .week {
        didSet { if scope != oldValue { reload() } }
    }

    let week: WeekCalendar
    let month: MonthCalendar
    private let source: CalendarEventSource

    init(source: CalendarEventSource, week: WeekCalendar = WeekCalendar(), anchor: Date = .now) {
        self.source = source
        self.week = week
        self.month = MonthCalendar(calendar: week.calendar)
        self.anchor = anchor
        self.access = source.access
    }

    var days: [Date] {
        switch scope {
        case .day: [week.calendar.startOfDay(for: anchor)]
        case .week: week.days(containing: anchor)
        case .month: month.days(containing: anchor)
        }
    }

    var interval: DateInterval {
        switch scope {
        case .day: week.dayInterval(containing: anchor)
        case .week: week.interval(containing: anchor)
        case .month: month.interval(containing: anchor)
        }
    }

    func reload() {
        access = source.access
        events = source.events(in: interval)
    }

    /// Events on the day containing `date`, read straight from the source without changing the visible week.
    func events(on date: Date) -> [CalendarEntry] {
        let calendar = week.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return source.events(in: DateInterval(start: start, end: end))
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    func requestAccess() async {
        access = await source.requestAccess()
        reload()
    }

    /// Saves a new event through the source, then reloads the visible week.
    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool) throws {
        try source.createEvent(title: title, start: start, end: end, isAllDay: isAllDay)
        reload()
    }

    func showNextWeek() { move(byWeeks: 1) }
    func showPreviousWeek() { move(byWeeks: -1) }

    /// The next day, week, or month, depending on the scope.
    func showNext() { move(by: 1) }
    /// The previous day, week, or month, depending on the scope.
    func showPrevious() { move(by: -1) }

    /// Switches to the week holding `day`.
    func showWeek(of day: Date) {
        anchor = day
        if scope == .week { reload() } else { scope = .week }
    }

    /// Switches to `day` on its own.
    func showDay(_ day: Date) {
        anchor = day
        if scope == .day { reload() } else { scope = .day }
    }

    func showToday(_ now: Date = .now) {
        anchor = now
        reload()
    }

    /// Keeps events fresh while the view is on screen.
    func observeChanges() async {
        for await _ in source.changes() {
            reload()
        }
    }

    private func move(byWeeks weeks: Int) {
        anchor = week.shift(anchor, byWeeks: weeks)
        reload()
    }

    /// Moves one step of the current scope forward or back.
    private func move(by steps: Int) {
        switch scope {
        case .day: anchor = week.shift(anchor, byDays: steps)
        case .week: anchor = week.shift(anchor, byWeeks: steps)
        case .month: anchor = month.shift(anchor, byMonths: steps)
        }
        reload()
    }
}
