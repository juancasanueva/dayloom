import AppKit
import EventKit

/// Reads and adds events in the system calendars (iCloud, Google, Exchange accounts added in macOS).
final class EventKitCalendarSource: CalendarEventSource {
    private let store = EKEventStore()

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        case .writeOnly, .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        _ = try? await store.requestFullAccessToEvents()
        return access
    }

    func events(in interval: DateInterval) -> [CalendarEntry] {
        guard access == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEntry(
                id: "event-\(event.calendarItemIdentifier)-\(Int(event.startDate.timeIntervalSince1970))",
                title: event.title?.isEmpty == false ? event.title : "Untitled Event",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                kind: .event,
                tint: Self.tint(for: event.calendar),
                calendarName: event.calendar?.title,
                location: event.location,
                url: event.url
            )
        }
    }

    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool) throws {
        guard access == .granted else { throw CalendarWriteError.accessDenied }
        guard let calendar = store.defaultCalendarForNewEvents, calendar.allowsContentModifications else {
            throw CalendarWriteError.readOnlyCalendar
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = calendar
        event.isAllDay = isAllDay
        event.startDate = start
        // EventKit treats an all-day event that ends on its start day as a single day.
        event.endDate = isAllDay ? start : end
        try store.save(event, span: .thisEvent, commit: true)
    }

    func changes() -> AsyncStream<Void> {
        let notifications = NotificationCenter.default.notifications(named: .EKEventStoreChanged, object: store)
        return AsyncStream { continuation in
            let task = Task {
                for await _ in notifications { continuation.yield() }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func tint(for calendar: EKCalendar?) -> EntryTint {
        guard let cgColor = calendar?.cgColor,
              let color = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) else { return .accent }
        return .rgb(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
}
