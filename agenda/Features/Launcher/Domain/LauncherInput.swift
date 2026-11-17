import Foundation

/// What the launcher understood from the typed text.
struct LauncherInput: Equatable {
    /// Events get this length when the text has a time but no duration.
    static let defaultEventDuration: TimeInterval = 60 * 60

    /// The text left after removing every recognized token.
    var title: String = ""
    /// Start of the target day. Set when a date or a time was recognized (a time alone means today).
    var day: Date?
    /// Exact start. Set only when a time was recognized.
    var start: Date?
    var duration: TimeInterval?
    var priority: TaskPriority = .none
    /// Tag names as typed, without `#`, unique ignoring case.
    var tagNames: [String] = []

    var hasTitle: Bool { !title.isEmpty }
    var hasDateOrTime: Bool { day != nil }

    /// The calendar slot an event built from this input would take, or `nil` without a date or time.
    func eventSpan(calendar: Calendar) -> LauncherEventSpan? {
        if let start {
            return LauncherEventSpan(start: start, end: start.addingTimeInterval(duration ?? Self.defaultEventDuration), isAllDay: false)
        }
        guard let day else { return nil }
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        return LauncherEventSpan(start: day, end: nextDay, isAllDay: true)
    }
}

struct LauncherEventSpan: Equatable {
    var start: Date
    var end: Date
    var isAllDay: Bool
}
