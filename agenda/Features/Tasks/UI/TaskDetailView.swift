import SwiftData
import SwiftUI

/// Resolves the selected task and shows its editor in the inspector.
struct TaskInspector: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let id = appState.selectedTaskID, let task = fetchTask(id) {
            TaskDetailView(task: task)
                .id(id)
        } else {
            ContentUnavailableView("No Task Selected", systemImage: "checklist", description: Text("Select a task to see its details."))
        }
    }

    /// Fetches by ID instead of relying on the context's registry, which misses freshly saved tasks.
    private func fetchTask(_ id: PersistentIdentifier) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }
}

struct TaskDetailView: View {
    @Bindable var task: TaskItem

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var newSubtaskTitle = ""

    private static let durations: [TimeInterval] = [15, 30, 45, 60, 90, 120, 180, 240].map { $0 * 60 }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $task.title, prompt: Text("Task title"), axis: .vertical)
                    .labelsHidden()
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)

                Picker("Status", selection: statusBinding) {
                    ForEach(TaskStatus.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Priority", selection: $task.priority) {
                    ForEach(TaskPriority.allCases.reversed()) { priority in
                        Label(priority.title, systemImage: priority == .none ? "flag.slash" : "flag.fill")
                            .tag(priority)
                    }
                }
            }

            if task.parent == nil {
                datesSection
            }

            tagsSection
            subtasksSection

            Section("Notes") {
                TextEditor(text: $task.notes)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }

            Section {
                Button("Delete Task", systemImage: "trash", role: .destructive, action: deleteTask)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Sections

    private var datesSection: some View {
        Section("Dates") {
            Toggle("Due date", isOn: hasDueDate)
            if let due = task.dueDate {
                DatePicker("Due", selection: Binding(get: { due }, set: { task.dueDate = $0 }), displayedComponents: .date)
            }

            Toggle("Scheduled", isOn: hasSchedule)
            if let start = task.scheduledStart {
                DatePicker(
                    "Starts",
                    selection: Binding(get: { start }, set: { task.scheduledStart = $0 }),
                    displayedComponents: [.date, .hourAndMinute]
                )
                Picker("Duration", selection: $task.scheduledDuration) {
                    ForEach(Self.durations, id: \.self) { duration in
                        Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                            .tag(duration)
                    }
                }
            }

            Picker("Repeat", selection: $task.repeatRule) {
                ForEach(RepeatRule.allCases) { rule in
                    Text(rule.title).tag(rule)
                }
            }
            .disabled(!task.canRepeat)
            .help(task.canRepeat ? "Creates the next occurrence when this task is completed." : "Add a due date or schedule to repeat this task.")
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        Section("Tags") {
            if tags.isEmpty {
                Text("Create tags from the sidebar.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    Toggle(isOn: tagBinding(tag)) {
                        Label {
                            Text(tag.name)
                        } icon: {
                            Image(systemName: "number").foregroundStyle(tag.color.color)
                        }
                    }
                }
            }
        }
    }

    private var subtasksSection: some View {
        Section {
            ForEach(task.orderedSubtasks) { subtask in
                SubtaskRow(subtask: subtask) { modelContext.delete(subtask) }
            }
            HStack {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                // Hidden label: a grouped form would otherwise show the title as a label and put the field out of sight.
                TextField("Add subtask", text: $newSubtaskTitle, prompt: Text("Add subtask"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .onSubmit(addSubtask)
            }
        } header: {
            let progress = task.subtaskProgress
            Text(progress.total > 0 ? "Subtasks \(progress.done)/\(progress.total)" : "Subtasks")
        }
    }

    // MARK: Bindings

    private var statusBinding: Binding<TaskStatus> {
        Binding(get: { task.status }, set: { task.updateStatus($0) })
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { task.dueDate != nil },
            set: { task.dueDate = $0 ? Calendar.current.startOfDay(for: .now) : nil }
        )
    }

    private var hasSchedule: Binding<Bool> {
        Binding(
            get: { task.scheduledStart != nil },
            set: { task.scheduledStart = $0 ? Self.nextHalfHour(after: .now) : nil }
        )
    }

    private func tagBinding(_ tag: Tag) -> Binding<Bool> {
        Binding(
            get: { (task.tags ?? []).contains { $0.persistentModelID == tag.persistentModelID } },
            set: { isOn in
                var current = task.tags ?? []
                current.removeAll { $0.persistentModelID == tag.persistentModelID }
                if isOn { current.append(tag) }
                task.tags = current
            }
        )
    }

    // MARK: Actions

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        task.addSubtask(title: title)
        newSubtaskTitle = ""
    }

    private func deleteTask() {
        appState.select(task: nil)
        modelContext.delete(task)
    }

    private static func nextHalfHour(after date: Date, calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let rounded = calendar.date(bySetting: .second, value: 0, of: date) ?? date
        return calendar.date(byAdding: .minute, value: minute < 30 ? 30 - minute : 60 - minute, to: rounded) ?? date
    }
}

private struct SubtaskRow: View {
    @Bindable var subtask: TaskItem
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            CompletionButton(task: subtask)
            TextField("Subtask", text: $subtask.title, prompt: Text("Subtask"))
                .labelsHidden()
                .textFieldStyle(.plain)
                .strikethrough(subtask.isDone)
                .foregroundStyle(subtask.isDone ? .secondary : .primary)
            Button("Delete Subtask", systemImage: "xmark.circle.fill", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .opacity(isHovering ? 1 : 0)
        }
        .onHover { isHovering = $0 }
    }
}
