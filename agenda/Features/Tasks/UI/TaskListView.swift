import SwiftData
import SwiftUI

/// The list for one smart list or tag, with a quick-add field on top.
struct TaskListView: View {
    let scope: TaskScope

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]

    /// Each list remembers whether it shows the list or the board.
    private var layouts = TaskLayoutStore.shared
    @State private var newTitle = ""
    @FocusState private var isQuickAddFocused: Bool
    @FocusState private var isListFocused: Bool

    private var query: TaskQuery { TaskQuery() }

    /// Completed has no statuses to arrange, so it always shows the list.
    private var showsBoard: Bool { layouts.layout(for: scope) == .board }

    private var layout: Binding<TaskLayout> {
        Binding(get: { layouts.layout(for: scope) }, set: { layouts.setLayout($0, for: scope) })
    }

    private var scopeTag: Tag? {
        guard case .tag(let id) = scope else { return nil }
        return tags.first { $0.persistentModelID == id }
    }

    var body: some View {
        let query = query
        let tasks = query.tasks(from: allTasks, in: scope)

        Group {
            if showsBoard {
                boardPage(tasks, query: query)
            } else {
                listPage(tasks, query: query)
            }
        }
        .plannerPanel()
        .navigationTitle(title)
        .toolbar(removing: .title)
        .onChange(of: appState.pendingQuickAdd, initial: true) { _, pending in
            guard pending else { return }
            isQuickAddFocused = true
            appState.pendingQuickAdd = false
        }
    }

    // MARK: Pages

    private func header(_ tasks: [TaskItem]) -> some View {
        PageHeader(verbatim: title, subtitle: TaskListHeading.subtitle(for: scope, count: tasks.count)) {
            if scope != .completed {
                layoutPicker
            }
        }
    }

    /// Header and quick add above the content, shared by the list and the board.
    @ViewBuilder
    private func top(_ tasks: [TaskItem]) -> some View {
        header(tasks)
        if scope != .completed {
            quickAddBar
        }
        if scope == .today {
            TodayHabitsStrip()
        }
    }

    private func listPage(_ tasks: [TaskItem], query: TaskQuery) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                top(tasks)

                if tasks.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else if scope == .upcoming {
                    upcomingDays(query: query)
                } else {
                    cards(tasks, query: query, showsDay: scope != .today)
                }
            }
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .padding(Theme.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isListFocused)
        // The list is focusable for the arrow keys; still open with the cursor in quick add, as before.
        .onAppear { isQuickAddFocused = scope != .completed }
        .onKeyPress(.downArrow) { moveSelection(by: 1, in: orderedIDs(tasks, query: query)) }
        .onKeyPress(.upArrow) { moveSelection(by: -1, in: orderedIDs(tasks, query: query)) }
        .onDeleteCommand(perform: deleteSelectedTask)
    }

    private func boardPage(_ tasks: [TaskItem], query: TaskQuery) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                top(tasks)
            }
            .padding(Theme.pagePadding)
            .padding(.bottom, -Theme.pagePadding.bottom + 4)

            board(query: query)
        }
        .onDeleteCommand(perform: deleteSelectedTask)
    }

    /// Upcoming groups tasks by day: the day in a column on the left, its tasks beside it.
    private func upcomingDays(query: TaskQuery) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(query.upcomingSections(from: allTasks)) { section in
                HStack(alignment: .top, spacing: 16) {
                    DayColumnLabel(day: section.day)
                        .frame(width: Theme.dayColumnWidth, alignment: .leading)
                    cards(section.tasks, query: query, showsDay: false)
                }
            }
        }
    }

    private func cards(_ tasks: [TaskItem], query: TaskQuery, showsDay: Bool) -> some View {
        VStack(spacing: 6) {
            ForEach(tasks) { task in
                let id = task.persistentModelID
                TaskRowView(
                    task: task,
                    emphasis: query.timeEmphasis(for: task),
                    isSelected: appState.selectedTaskID == id,
                    showsDay: showsDay
                )
                .onTapGesture { select(id) }
                .contextMenu { contextMenu(for: task) }
                .accessibilityAddTraits(appState.selectedTaskID == id ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { select(id) }
            }
        }
    }

    private func board(query: TaskQuery) -> some View {
        TaskBoardView(
            columns: TaskBoard(now: query.now, calendar: query.calendar).columns(from: allTasks, in: scope),
            emphasis: query.timeEmphasis(for:),
            onDrop: { payloads, status in
                TaskBoard().drop(payloads, onto: status, from: allTasks)
            },
            cardMenu: contextMenu(for:)
        )
    }

    // MARK: Selection

    private func select(_ id: PersistentIdentifier) {
        appState.select(task: id)
        isListFocused = true
    }

    /// Tasks in the order they appear on screen, for the arrow keys.
    private func orderedIDs(_ tasks: [TaskItem], query: TaskQuery) -> [PersistentIdentifier] {
        let shown = scope == .upcoming ? query.upcomingSections(from: allTasks).flatMap(\.tasks) : tasks
        return shown.map(\.persistentModelID)
    }

    private func moveSelection(by offset: Int, in ids: [PersistentIdentifier]) -> KeyPress.Result {
        guard let next = ListNavigation.step(from: appState.selectedTaskID, in: ids, by: offset) else { return .ignored }
        appState.select(task: next)
        return .handled
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: layout) {
            ForEach(TaskLayout.allCases) { layout in
                Label(layout.title, systemImage: layout.systemImage)
                    .labelStyle(.iconOnly)
                    .tag(layout)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Show tasks as a list or a board")
    }

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            TextField(quickAddPlaceholder, text: $newTitle)
                .textFieldStyle(.plain)
                .focused($isQuickAddFocused)
                .onSubmit(addTask)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(isQuickAddFocused ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: 1)
        }
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
        case .inbox: String(appLocalized: "Inbox")
        case .today: String(appLocalized: "Today")
        case .upcoming: String(appLocalized: "Upcoming")
        case .completed: String(appLocalized: "Completed")
        case .tag: scopeTag?.name ?? String(appLocalized: "Tag")
        }
    }

    private var quickAddPlaceholder: String {
        switch scope {
        case .today: String(appLocalized: "Add a task for today")
        case .upcoming: String(appLocalized: "Add a task for tomorrow")
        case .tag: String(appLocalized: "Add a task tagged \(scopeTag?.name ?? "")")
        case .inbox, .completed: String(appLocalized: "Add a task")
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
