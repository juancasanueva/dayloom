import SwiftUI

/// A task as a soft card: check, title, then its time, progress and tags.
struct TaskRowView: View {
    let task: TaskItem
    let emphasis: TimeEmphasis
    let isSelected: Bool
    /// False inside a day column, where the day is already shown beside the card.
    var showsDay = true

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CompletionButton(task: task)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .fontWeight(.medium)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(2)
                    .padding(.top, 2)

                if hasMetadata {
                    metadata
                }
            }

            Spacer(minLength: 0)

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
    }

    private var dueText: String? {
        guard let due = task.dueDate, showsDay || task.scheduledStart == nil && emphasis == .overdue else { return nil }
        return DayFormatting.relativeTitle(for: due)
    }

    private var hasMetadata: Bool {
        dueText != nil || task.scheduledStart != nil || task.repeatRule.repeats || !(task.subtasks ?? []).isEmpty || !(task.tags ?? []).isEmpty
    }

    private var metadata: some View {
        HStack(spacing: 10) {
            if let dueText {
                Label(dueText, systemImage: "calendar")
                    .foregroundStyle(emphasis.color)
            }
            if let start = task.scheduledStart {
                Label(start.formatted(date: .omitted, time: .shortened), systemImage: "clock")
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
            ForEach(task.orderedTags) { tag in
                TagChip(tag: tag)
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
    }
}
