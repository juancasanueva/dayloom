import Foundation
import Observation

/// How long before a timed task starts its reminder fires.
enum ReminderLead: Int, CaseIterable, Identifiable {
    case atStart = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case oneDay = 1440

    var id: Int { rawValue }
    var interval: TimeInterval { TimeInterval(rawValue) * 60 }

    var title: String {
        switch self {
        case .atStart: String(appLocalized: "At start time")
        case .fiveMinutes: "5 minutes before"
        case .fifteenMinutes: "15 minutes before"
        case .thirtyMinutes: "30 minutes before"
        case .oneHour: "1 hour before"
        case .oneDay: "1 day before"
        }
    }
}

/// The reminder choices from Settings.
struct ReminderSettings: Equatable {
    var isEnabled: Bool
    var lead: ReminderLead
    /// When tasks with only a due date are reminded, in minutes after midnight on that day.
    var allDayMinutes: Int

    static let standard = ReminderSettings(isEnabled: false, lead: .fifteenMinutes, allDayMinutes: 9 * 60)
}

/// What the planner needs to know about a task.
struct ReminderCandidate {
    /// Stable key that leads back to the task when the notification is clicked.
    let key: String
    let title: String
    let dueDate: Date?
    let scheduledStart: Date?
    let isDone: Bool
}

/// One notification to schedule.
struct PlannedReminder: Equatable {
    let id: String
    let taskKey: String
    let title: String
    let body: String
    let fireDate: Date
}

/// Decides which tasks get a reminder and when. Pure, so the rules are testable without notifications.
struct ReminderPlanner {
    /// macOS keeps at most 64 pending notifications per app; stay under it.
    static let limit = 60
    static let identifierPrefix = "dayloom.reminder."

    var now: Date = .now
    var calendar: Calendar = .current
    var locale: Locale = .app

    func plan(_ candidates: [ReminderCandidate], settings: ReminderSettings) -> [PlannedReminder] {
        guard settings.isEnabled else { return [] }
        let reminders = candidates.compactMap { candidate -> PlannedReminder? in
            guard !candidate.isDone, let (fireDate, body) = schedule(for: candidate, settings: settings), fireDate > now else {
                return nil
            }
            return PlannedReminder(
                id: Self.identifierPrefix + candidate.key,
                taskKey: candidate.key,
                title: candidate.title.isEmpty ? String(appLocalized: "Untitled") : candidate.title,
                body: body,
                fireDate: fireDate
            )
        }
        return Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(Self.limit))
    }

    /// A scheduled time wins over a due date: the reminder counts back from the start.
    private func schedule(for candidate: ReminderCandidate, settings: ReminderSettings) -> (Date, String)? {
        if let start = candidate.scheduledStart {
            let fireDate = start.addingTimeInterval(-settings.lead.interval)
            let time = start.formatted(timeStyle)
            let body = calendar.isDate(fireDate, inSameDayAs: start)
                ? String(appLocalized: "Starts at \(time)") : String(appLocalized: "Starts tomorrow at \(time)")
            return (fireDate, body)
        }
        if let due = candidate.dueDate {
            let fireDate = calendar.startOfDay(for: due).addingTimeInterval(TimeInterval(settings.allDayMinutes) * 60)
            return (fireDate, String(appLocalized: "Due today"))
        }
        return nil
    }

    private var timeStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
    }
}

/// The reminder settings, remembered across launches.
@Observable
final class ReminderSettingsStore {
    static let shared = ReminderSettingsStore()

    static let enabledKey = "remindersEnabled"
    static let leadKey = "remindersLead"
    static let allDayKey = "remindersAllDayMinutes"

    @ObservationIgnored private let defaults: UserDefaults

    var settings: ReminderSettings {
        didSet {
            defaults.set(settings.isEnabled, forKey: Self.enabledKey)
            defaults.set(settings.lead.rawValue, forKey: Self.leadKey)
            defaults.set(settings.allDayMinutes, forKey: Self.allDayKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let standard = ReminderSettings.standard
        settings = ReminderSettings(
            isEnabled: defaults.object(forKey: Self.enabledKey) as? Bool ?? standard.isEnabled,
            lead: (defaults.object(forKey: Self.leadKey) as? Int).flatMap(ReminderLead.init(rawValue:)) ?? standard.lead,
            allDayMinutes: defaults.object(forKey: Self.allDayKey) as? Int ?? standard.allDayMinutes
        )
    }
}
