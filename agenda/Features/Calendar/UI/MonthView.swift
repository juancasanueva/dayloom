import SwiftData
import SwiftUI

/// A month at a glance: whole weeks, each day with its events and scheduled tasks.
struct MonthGrid: View {
    let days: [Date]
    let anchor: Date
    let entries: [CalendarEntry]
    let month: MonthCalendar
    let selectedTaskID: PersistentIdentifier?
    var onSelectTask: (PersistentIdentifier) -> Void
    var onOpenDay: (Date) -> Void
    var onCreateTask: (Date) -> Void

    private var weeks: [[Date]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(days.prefix(7), id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }
            }
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(weeks, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            MonthDayCell(
                                day: day,
                                isInMonth: month.isInSameMonth(day, as: anchor),
                                entries: month.entries(entries, on: day),
                                selectedTaskID: selectedTaskID,
                                onSelectTask: onSelectTask,
                                onOpenDay: onOpenDay,
                                onCreateTask: onCreateTask
                            )
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.hairline)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }
}

/// One day of the month grid: its number, then as many entries as fit and how many more there are.
private struct MonthDayCell: View {
    let day: Date
    let isInMonth: Bool
    let entries: [CalendarEntry]
    let selectedTaskID: PersistentIdentifier?
    var onSelectTask: (PersistentIdentifier) -> Void
    var onOpenDay: (Date) -> Void
    var onCreateTask: (Date) -> Void

    private static let visibleEntries = 3

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        let hidden = max(entries.count - Self.visibleEntries, 0)

        VStack(alignment: .leading, spacing: 3) {
            Button {
                onOpenDay(day)
            } label: {
                Text(day.formatted(.dateTime.day()))
                    .font(.callout.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.white : (isInMonth ? Color.primary : Color.secondary))
                    .frame(minWidth: 24, minHeight: 24)
                    .background(isToday ? Theme.accent : .clear, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Show this week")
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityHint("Shows this week")

            ForEach(entries.prefix(Self.visibleEntries)) { entry in
                MonthEntryRow(entry: entry, isSelected: entry.taskID != nil && entry.taskID == selectedTaskID, onSelectTask: onSelectTask)
            }
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isToday ? Theme.accent.opacity(0.06) : (isInMonth ? Color.clear : Theme.card.opacity(0.35)))
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hairline).frame(width: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onCreateTask(day) }
        .contextMenu {
            Button("New Task on \(day.formatted(.dateTime.day().month(.abbreviated)))", systemImage: "plus") { onCreateTask(day) }
            Button("Show Week", systemImage: "calendar") { onOpenDay(day) }
        }
        .accessibilityElement(children: .contain)
    }
}

/// An event or a scheduled task inside a month day: a colored mark, its time, and its title.
private struct MonthEntryRow: View {
    let entry: CalendarEntry
    let isSelected: Bool
    var onSelectTask: (PersistentIdentifier) -> Void

    var body: some View {
        let tint = entry.tint.color

        HStack(spacing: 4) {
            if entry.taskID != nil {
                Image(systemName: entry.isCompletedTask ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                Circle().fill(tint).frame(width: 6, height: 6)
            }
            if !entry.isAllDay {
                Text(entry.start.formatted(date: .omitted, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                .strikethrough(entry.isCompletedTask)
                .foregroundStyle(entry.isCompletedTask ? .secondary : .primary)
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.isAllDay ? tint.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = entry.taskID { onSelectTask(id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(entry.taskID != nil ? .isButton : [])
    }
}
