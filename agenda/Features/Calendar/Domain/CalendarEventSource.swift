import Foundation

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied
}

/// Port for reading events from the user's calendars.
protocol CalendarEventSource: AnyObject {
    var access: CalendarAccess { get }
    func requestAccess() async -> CalendarAccess
    func events(in interval: DateInterval) -> [CalendarEntry]
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

    func changes() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
