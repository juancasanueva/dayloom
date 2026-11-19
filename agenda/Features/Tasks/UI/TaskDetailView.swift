import SwiftData
import SwiftUI

/// Resolves the selected task and shows its editor in the inspector.
struct TaskInspector: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let id = appState.selectedTaskID, let task = fetchTask(id) {
                TaskDetailView(task: task)
                    .id(id)
            } else {
                ContentUnavailableView("No Task Selected", systemImage: "checklist", description: Text("Select a task to see its details."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // A sibling of the content panel: the same rounded paper surface on the canvas.
        .plannerPanel()
        // No line between the content and this panel, only the canvas gap.
        .background(HiddenSplitDivider())
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
    @State private var isConfirmingDelete = false
    @State private var isCreatingMeeting = false
    @State private var meetingError: String?
    @State private var showsTeamsHint = false

    private static let durations: [TimeInterval] = [15, 30, 45, 60, 90, 120, 180, 240].map { $0 * 60 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                prioritySection

                if task.parent == nil {
                    datesSection
                    meetingSection
                }

                tagsSection
                subtasksSection
                notesSection
                deleteButton
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("Delete \u{201C}\(task.title)\u{201D}?", isPresented: $isConfirmingDelete) {
            Button("Delete Task", role: .destructive, action: deleteTask)
        } message: {
            let subtasks = task.subtasks?.count ?? 0
            Text(subtasks > 0 ? "Its \(subtasks) subtasks will be deleted too. You can't undo this." : "You can't undo this.")
        }
    }

    // MARK: Sections

    /// The title, prominent like a page title, with the status right under it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $task.title, prompt: Text("Task title"), axis: .vertical)
                .labelsHidden()
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)

            Picker("Status", selection: statusBinding) {
                ForEach(TaskStatus.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var prioritySection: some View {
        PanelSection("Priority") {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(TaskPriority.allCases) { priority in
                    Toggle(priority.title, isOn: priorityBinding(priority))
                        .accessibilityLabel("\(priority.title) priority")
                    .toggleStyle(PillToggleStyle(color: priority == .none ? .secondary : priority.color))
                }
            }
        }
    }

    private var datesSection: some View {
        PanelSection("Dates") {
            DetailRow("Due date") {
                Toggle("Due date", isOn: hasDueDate)
            }
            if let due = task.dueDate {
                DetailRow("Due") {
                    DatePicker("Due", selection: Binding(get: { due }, set: { task.dueDate = $0 }), displayedComponents: .date)
                }
            }

            DetailRow("Scheduled") {
                Toggle("Scheduled", isOn: hasSchedule)
            }
            if let start = task.scheduledStart {
                DetailRow("Starts") {
                    DatePicker(
                        "Starts",
                        selection: Binding(get: { start }, set: { task.scheduledStart = $0 }),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                DetailRow("Duration") {
                    Picker("Duration", selection: $task.scheduledDuration) {
                        ForEach(Self.durations, id: \.self) { duration in
                            Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(.app)))
                                .tag(duration)
                        }
                    }
                }
            }

            DetailRow("Repeat") {
                Picker("Repeat", selection: $task.repeatRule) {
                    ForEach(RepeatRule.allCases) { rule in
                        Text(rule.title).tag(rule)
                    }
                }
            }
            .disabled(!task.canRepeat)
            .help(task.canRepeat ? "Creates the next occurrence when this task is completed." : "Add a due date or schedule to repeat this task.")
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var tagsSection: some View {
        PanelSection("Tags") {
            if tags.isEmpty {
                Text("Create tags from the sidebar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(tags) { tag in
                        Toggle(isOn: tagBinding(tag)) {
                            Label(tag.name, systemImage: "number")
                        }
                        .toggleStyle(PillToggleStyle(color: tag.color.color))
                    }
                }
            }
        }
    }

    private var subtasksSection: some View {
        let progress = task.subtaskProgress
        return PanelSection(progress.total > 0 ? "Subtasks \(progress.done)/\(progress.total)" : "Subtasks") {
            ForEach(task.orderedSubtasks) { subtask in
                SubtaskRow(subtask: subtask) { modelContext.delete(subtask) }
            }
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                // Hidden label: as a labeled field the title would show beside it and squeeze the field out of sight.
                TextField("Add subtask", text: $newSubtaskTitle, prompt: Text("Add subtask"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .onSubmit(addSubtask)
            }
        }
    }

    /// A link makes the task a video call; the service is recognized from it.
    private var meetingSection: some View {
        PanelSection("Video Call") {
            TextField("Meeting link", text: $task.meetingURL, prompt: Text("Paste a Google Meet, Zoom or Teams link"))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .accessibilityLabel("Meeting link")

            if let meeting = task.meetingLink {
                JoinMeetingButton(meeting: meeting)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else if !task.meetingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Not a web link", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                createMeetingButton
            }

            if let meetingError {
                Text(meetingError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: task.persistentModelID) { meetingError = nil }
    }

    /// Ways to get a meeting link: Google Meet and Zoom create one after a sign-in; Teams opens to make one.
    private var createMeetingButton: some View {
        let google = GoogleMeetService.shared
        let zoom = ZoomMeetingService.shared

        return VStack(alignment: .leading, spacing: 6) {
            createRow("Create Google Meet", service: "Google", isConfigured: google.isConfigured) {
                try await google.createMeeting()
            }
            createRow("Create Zoom Meeting", service: "Zoom", isConfigured: zoom.isConfigured) { [task] in
                try await zoom.createMeeting(topic: task.title, start: task.scheduledStart, duration: task.scheduledDuration)
            }

            Button {
                TeamsMeetingStarter.open()
                showsTeamsHint = true
            } label: {
                Label("New Teams Meeting", systemImage: "arrow.up.forward.app")
            }
            .help("Opens Teams, where you create a meeting link to paste here")

            if showsTeamsHint {
                Text("In Teams, choose Meet, then Create a meeting link. Copy it and paste it above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isCreatingMeeting {
                ProgressView().controlSize(.small)
            }
        }
        .controlSize(.small)
    }

    private func createRow(
        _ title: LocalizedStringKey,
        service: String,
        isConfigured: Bool,
        create: @escaping () async throws -> MeetingLink
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                createMeeting(with: create)
            } label: {
                Label(title, systemImage: "video.badge.plus")
            }
            .disabled(!isConfigured || isCreatingMeeting)
            .help(isConfigured ? "Create a new \(service) meeting link for this task" : "\(service) sign-in isn't set up in this build.")

            if !isConfigured {
                Text("\(service) sign-in isn't set up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func createMeeting(with create: @escaping () async throws -> MeetingLink) {
        let task = task
        meetingError = nil
        isCreatingMeeting = true
        Task {
            defer { isCreatingMeeting = false }
            do {
                let meeting = try await create()
                // Another link may have been pasted while the service was answering; keep it.
                if task.meetingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    task.meetingURL = meeting.url.absoluteString
                }
            } catch MeetingServiceError.signInCancelled {
                // Closing the sign-in sheet is a choice, not an error.
            } catch {
                meetingError = error.localizedDescription
            }
        }
    }

    private var notesSection: some View {
        PanelSection("Notes") {
            // A fixed height keeps the box from growing with each line; long notes scroll inside, without a bar.
            TextEditor(text: $task.notes)
                .font(.body)
                .frame(height: 140)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .accessibilityLabel("Notes")
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete Task", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DestructiveButtonStyle())
    }

    // MARK: Bindings

    private var statusBinding: Binding<TaskStatus> {
        Binding(get: { task.status }, set: { task.updateStatus($0) })
    }

    private func priorityBinding(_ priority: TaskPriority) -> Binding<Bool> {
        Binding(
            get: { task.priority == priority },
            set: { if $0 { task.priority = priority } }
        )
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

/// A label on the leading side and its control on the trailing side, inside a details section.
private struct DetailRow<Control: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let control: Control

    init(_ title: LocalizedStringKey, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            control
                .labelsHidden()
                .fixedSize()
        }
        .frame(minHeight: 22)
    }
}

/// Red on a faint red wash, stronger under the pointer.
private struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        WashedLabel(configuration: configuration)
    }

    private struct WashedLabel: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(.red)
                .padding(.vertical, 8)
                .background(
                    Color.red.opacity(configuration.isPressed ? 0.2 : (isHovered ? 0.14 : 0.08)),
                    in: RoundedRectangle(cornerRadius: Theme.cardRadius)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .onHover { isHovered = $0 }
        }
    }
}

private struct SubtaskRow: View {
    @Bindable var subtask: TaskItem
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            CompletionButton(task: subtask)
                .frame(width: 20)
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
