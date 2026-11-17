import SwiftUI

/// A task card on the board: the same soft card as the list, with tags on their own line.
struct BoardCardView: View {
    let task: TaskItem
    let emphasis: TimeEmphasis
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CompletionButton(task: task)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .fontWeight(.medium)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(3)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasDetails {
                    details
                }

                if !(task.tags ?? []).isEmpty {
                    tags
                }
            }

            if task.priority != .none && !task.isDone {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(task.priority.color)
                    .padding(.top, 4)
                    .accessibilityLabel("\(task.priority.title) priority")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(isSelected: isSelected, isHovered: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var hasDetails: Bool {
        task.dueDate != nil || task.scheduledStart != nil || task.repeatRule.repeats || task.subtaskProgress.total > 0
    }

    private var details: some View {
        HStack(spacing: 10) {
            if let due = task.dueDate {
                Label(DayFormatting.relativeTitle(for: due), systemImage: "calendar")
                    .foregroundStyle(emphasis.color)
            }
            if let start = task.scheduledStart {
                Label(scheduleText(for: start), systemImage: "clock")
                    .foregroundStyle(emphasis.color)
                    .fontWeight(emphasis == .normal ? .regular : .semibold)
            }
            if task.repeatRule.repeats {
                Image(systemName: "repeat")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Repeats \(task.repeatRule.title.lowercased())")
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
