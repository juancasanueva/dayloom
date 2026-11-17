import SwiftUI

/// A compact task card: title, dates, priority, subtask progress, and tags.
struct BoardCardView: View {
    let task: TaskItem
    let isOverdue: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                CompletionButton(task: task)

                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if task.priority != .none && !task.isDone {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(task.priority.color)
                        .accessibilityLabel("\(task.priority.title) priority")
                }
            }

            if hasDetails {
                details
            }

            if !(task.tags ?? []).isEmpty {
                tags
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var hasDetails: Bool {
        task.dueDate != nil || task.scheduledStart != nil || task.subtaskProgress.total > 0
    }

    private var details: some View {
        HStack(spacing: 10) {
            if let due = task.dueDate {
                Label(DayFormatting.relativeTitle(for: due), systemImage: "calendar")
                    .foregroundStyle(isOverdue ? Color.red : Color.secondary)
            }
            if let start = task.scheduledStart {
                Label(scheduleText(for: start), systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
            let progress = task.subtaskProgress
            if progress.total > 0 {
                Label("\(progress.done)/\(progress.total)", systemImage: "checklist")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
    }

    private var tags: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(task.orderedTags) { TagChip(tag: $0) }
            }
            HStack(spacing: 4) {
                if let first = task.orderedTags.first {
                    TagChip(tag: first)
                }
                Text("+\(task.orderedTags.count - 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Cards have no day sections, so a start on another day names the day too.
    private func scheduleText(for start: Date) -> String {
        let time = start.formatted(date: .omitted, time: .shortened)
        guard !Calendar.current.isDateInToday(start) else { return time }
        return "\(DayFormatting.relativeTitle(for: start)), \(time)"
    }
}
