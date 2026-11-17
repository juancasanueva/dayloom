import SwiftData
import SwiftUI

/// The list for one smart list or tag, with a quick-add field on top.
struct TaskListView: View {
    let scope: TaskScope

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @AppStorage(TaskLayout.storageKey) private var layout: TaskLayout = .list
    @State private var newTitle = ""
    @FocusState private var isQuickAddFocused: Bool

    private var query: TaskQuery { TaskQuery() }

    /// Completed has no statuses to arrange, so it always shows the list.
    private var showsBoard: Bool { scope != .completed && layout == .board }

    private var scopeTag: Tag? {
        guard case .tag(let id) = scope else { return nil }
        return tags.first { $0.persistentModelID == id }
    }

    private var selection: Binding<PersistentIdentifier?> {
        Binding(get: { appState.selectedTaskID }, set: { appState.select(task: $0) })
    }

    var body: some View {
        let query = query
        let tasks = query.tasks(from: allTasks, in: scope)

        VStack(spacing: 0) {
            if scope != .completed {
                quickAddBar
            }

            if showsBoard {
                board(query: query)
            } else {
                list(tasks, query: query)
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(tasks.isEmpty ? "" : "\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")")
        .toolbar {
            if scope != .completed {
                ToolbarItem {
                    layoutPicker
                }
            }
        }
        .onDeleteCommand(perform: deleteSelectedTask)
        .onChange(of: appState.pendingQuickAdd, initial: true) { _, pending in
            guard pending else { return }
            isQuickAddFocused = true
            appState.pendingQuickAdd = false
        }
    }

    private func list(_ tasks: [TaskItem], query: TaskQuery) -> some View {
        List(selection: selection) {
            if scope == .upcoming {
                ForEach(query.upcomingSections(from: allTasks)) { section in
                    Section(DayFormatting.relativeTitle(for: section.day)) {
                        rows(section.tasks, query: query)
                    }
                }
            } else {
                rows(tasks, query: query)
            }
        }
        .listStyle(.inset)
        .overlay {
            if tasks.isEmpty { emptyState }
        }
    }

    private func board(query: TaskQuery) -> some View {
        TaskBoardView(
            columns: TaskBoard(now: query.now, calendar: query.calendar).columns(from: allTasks, in: scope),
            isOverdue: query.isOverdue,
            onDrop: { payloads, status in
                TaskBoard().drop(payloads, onto: status, from: allTasks)
            },
            cardMenu: contextMenu(for:)
        )
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: $layout) {
            ForEach(TaskLayout.allCases) { layout in
                Label(layout.title, systemImage: layout.systemImage)
                    .tag(layout)
            }
        }
        .pickerStyle(.segmented)
        .help("Show tasks as a list or a board")
    }

    private func rows(_ tasks: [TaskItem], query: TaskQuery) -> some View {
        ForEach(tasks) { task in
            TaskRowView(task: task, isOverdue: query.isOverdue(task))
                .tag(task.persistentModelID)
                .contextMenu { contextMenu(for: task) }
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            TextField(quickAddPlaceholder, text: $newTitle)
                .textFieldStyle(.plain)
                .focused($isQuickAddFocused)
                .onSubmit(addTask)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func contextMenu(for task: TaskItem) -> some View {
        Button(task.isDone ? "Mark as Not Done" : "Mark as Done") {
            task.setCompleted(!task.isDone)
        }
        Menu("Priority") {
            ForEach(TaskPriority.allCases.reversed()) { priority in
                Button(priority.title) { task.priority = priority }
            }
        }
        Button("Due Today") { task.dueDate = Calendar.current.startOfDay(for: .now) }
        Button("Due Tomorrow") { task.dueDate = TaskQuery().defaultDueDate(for: .upcoming) }
        Divider()
        Button("Delete", role: .destructive) { delete(task) }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch scope {
        case .inbox:
            ContentUnavailableView("Inbox Zero", systemImage: "tray", description: Text("Tasks without a date land here."))
        case .today:
            ContentUnavailableView("Nothing Due Today", systemImage: "sun.max", description: Text("Add a task above or plan one from the calendar."))
        case .upcoming:
            ContentUnavailableView("Nothing Upcoming", systemImage: "calendar", description: Text("Tasks with a future date show up here."))
        case .completed:
            ContentUnavailableView("No Completed Tasks", systemImage: "checkmark.circle", description: Text("Finished tasks are collected here."))
        case .tag:
            ContentUnavailableView("No Tasks", systemImage: "number", description: Text("Open tasks with this tag appear here."))
        }
    }

    private var title: String {
        switch scope {
        case .inbox: "Inbox"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .completed: "Completed"
        case .tag: scopeTag?.name ?? "Tag"
        }
    }

    private var quickAddPlaceholder: String {
        switch scope {
        case .today: "Add a task for today"
        case .upcoming: "Add a task for tomorrow"
        case .tag: "Add a task tagged \(scopeTag?.name ?? "")"
        case .inbox, .completed: "Add a task"
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let task = TaskItem(title: title, dueDate: query.defaultDueDate(for: scope))
        modelContext.insert(task)
        if let scopeTag {
            task.tags = [scopeTag]
        }
        newTitle = ""
    }

    private func deleteSelectedTask() {
        guard let id = appState.selectedTaskID,
              let task = allTasks.first(where: { $0.persistentModelID == id }) else { return }
        delete(task)
    }

    private func delete(_ task: TaskItem) {
        if appState.selectedTaskID == task.persistentModelID {
            appState.select(task: nil)
        }
        modelContext.delete(task)
    }
}

#Preview {
    TaskListView(scope: .today)
        .environment(AppState())
        .modelContainer(PlannerSchema.makeContainer(inMemory: true))
        .frame(width: 520, height: 480)
}
