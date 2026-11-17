import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let isOverdue: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            CompletionButton(task: task)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(2)

                if hasMetadata {
                    metadata
                }
            }

            Spacer(minLength: 0)

            if task.priority != .none && !task.isDone {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(task.priority.color)
                    .accessibilityLabel("\(task.priority.title) priority")
            }
        }
        .padding(.vertical, 3)
    }

    private var hasMetadata: Bool {
        task.dueDate != nil || task.scheduledStart != nil || task.repeatRule.repeats || !(task.subtasks ?? []).isEmpty || !(task.tags ?? []).isEmpty
    }

    private var metadata: some View {
        HStack(spacing: 10) {
            if let due = task.dueDate {
                Label(DayFormatting.relativeTitle(for: due), systemImage: "calendar")
                    .foregroundStyle(isOverdue ? Color.red : Color.secondary)
            }
            if let start = task.scheduledStart {
                Label(start.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    .foregroundStyle(.secondary)
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
    }
}
