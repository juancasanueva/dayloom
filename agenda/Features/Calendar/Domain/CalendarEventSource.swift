import Foundation

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied
}

enum CalendarWriteError: Error, Equatable, LocalizedError {
    case accessDenied
    case readOnlyCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Calendar access is needed to add events."
        case .readOnlyCalendar: "The default calendar doesn't accept new events."
        }
    }
}

/// Port for reading and adding events in the user's calendars.
protocol CalendarEventSource: AnyObject {
    var access: CalendarAccess { get }
    func requestAccess() async -> CalendarAccess
    func events(in interval: DateInterval) -> [CalendarEntry]
    /// Adds an event to the default calendar. An all-day event covers the day of `start`.
    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool) throws
    /// Emits whenever the underlying calendars change outside the app.
    func changes() -> AsyncStream<Void>
}

/// In-memory source used by previews and tests.
final class StaticCalendarSource: CalendarEventSource {
    var access: CalendarAccess
    var entries: [CalendarEntry]

    init(access: CalendarAccess = .granted, entries: [CalendarEntry] = []) {
        self.access = access
        self.entries = entries
    }

    func requestAccess() async -> CalendarAccess { access }

    func events(in interval: DateInterval) -> [CalendarEntry] {
        guard access == .granted else { return [] }
        return entries.filter { $0.start < interval.end && $0.end > interval.start }
    }

    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool) throws {
        guard access == .granted else { throw CalendarWriteError.accessDenied }
        entries.append(CalendarEntry(
            id: "event-\(UUID().uuidString)",
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            kind: .event,
            tint: .accent
        ))
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
