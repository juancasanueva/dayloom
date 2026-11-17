import Foundation
import Observation

/// State for the week view: which week is shown and the events loaded for it.
@Observable
final class WeekCalendarModel {
    private(set) var anchor: Date
    private(set) var events: [CalendarEntry] = []
    private(set) var access: CalendarAccess

    let week: WeekCalendar
    private let source: CalendarEventSource

    init(source: CalendarEventSource, week: WeekCalendar = WeekCalendar(), anchor: Date = .now) {
        self.source = source
        self.week = week
        self.anchor = anchor
        self.access = source.access
    }

    var days: [Date] { week.days(containing: anchor) }
    var interval: DateInterval { week.interval(containing: anchor) }

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
}
