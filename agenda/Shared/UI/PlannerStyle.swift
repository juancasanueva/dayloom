import SwiftUI

extension TaskPriority {
    var color: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }
}

extension TagColor {
    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        case .red: .red
        case .teal: .teal
        case .yellow: .yellow
        case .gray: .gray
        }
    }
}

extension TimeEmphasis {
    /// Overdue in red, later today in the accent color, otherwise quiet.
    var color: Color {
        switch self {
        case .overdue: .red
        case .today: Theme.accent
        case .normal: .secondary
        }
    }
}

extension EntryTint {
    var color: Color {
        switch self {
        case .accent: Theme.accent
        case let .rgb(red, green, blue): Color(red: red, green: green, blue: blue)
        }
    }
}

enum DayFormatting {
    /// "Today", "Tomorrow", "Yesterday", or a short date such as "Thu, Nov 20".
    static func relativeTitle(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(appLocalized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(appLocalized: "Tomorrow") }
        if calendar.isDateInYesterday(date) { return String(appLocalized: "Yesterday") }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(.app))
    }

    /// "Today", "Tomorrow", or the full weekday name, for the day column of a list.
    static func dayName(for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .app) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(appLocalized: "Today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(appLocalized: "Tomorrow")
        }
        return date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide))
    }

    /// Day and short month, such as "19 Nov", shown under the day name.
    static func shortDate(for date: Date, calendar: Calendar = .current, locale: Locale = .app) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated))
    }
}

/// Small rounded label used for tags.
struct TagChip: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tag.color.color)
            .background(tag.color.color.opacity(0.15), in: Capsule())
    }
}

/// Circular check button that toggles a task's completion.
struct CompletionButton: View {
    let task: TaskItem

    var body: some View {
        Button {
            withAnimation(.snappy) { task.setCompleted(!task.isDone) }
        } label: {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.isDone ? Color.secondary : task.priority.color)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isDone ? "Mark as not done" : "Mark as done")
    }
}
