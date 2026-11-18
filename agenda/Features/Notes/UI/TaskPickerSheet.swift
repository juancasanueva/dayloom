import SwiftData
import SwiftUI

/// Searches existing tasks so one can be added to a note.
struct TaskPickerSheet: View {
    let pick: (TaskItem) -> Void

    @Query private var tasks: [TaskItem]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var candidates: [TaskItem] { TaskPicker.candidates(from: tasks, query: query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Existing Task")
                .font(Theme.sectionTitle)
            TextField("Search tasks", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    if let first = candidates.first { choose(first) }
                }
            taskList
        }
        .padding(20)
        .frame(width: 400, height: 380)
        .background(Theme.panel)
        .onAppear { isSearchFocused = true }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var taskList: some View {
        let candidates = candidates
        if candidates.isEmpty {
            ContentUnavailableView(
                query.isEmpty ? "No Open Tasks" : "No Matches",
                systemImage: "checkmark.circle",
                description: Text(query.isEmpty ? "Every task is done." : "No task title contains “\(query)”.")
            )
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(candidates) { task in
                        Button { choose(task) } label: { TaskPickerRow(task: task) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func choose(_ task: TaskItem) {
        pick(task)
        dismiss()
    }
}

/// One task in the picker, as a soft card.
private struct TaskPickerRow: View {
    let task: TaskItem

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .fontWeight(.medium)
                    .strikethrough(task.isDone)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(isHovered: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var detail: String {
        guard let due = task.dueDate else { return "Inbox" }
        return "Due \(DayFormatting.relativeTitle(for: due))"
    }
}
