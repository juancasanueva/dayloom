import SwiftData
import SwiftUI

/// Keyboard-first overlay: type to create a task or an event, or to jump to an existing task.
///
/// Place it in an overlay that fills the window. ↑/↓ move the selection, ↩ runs it, esc closes.
struct QuickLauncherView: View {
    @Binding var isPresented: Bool

    @Environment(AppState.self) private var appState
    @Environment(WeekCalendarModel.self) private var calendarModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [TaskItem]
    @Query private var tags: [Tag]

    @State private var text = ""
    @State private var selectedIndex = 0
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let input = LauncherParser.parse(text, now: .now, calendar: .current)
        let rows = LauncherResults.rows(for: input, query: text, tasks: allTasks, calendarAccess: calendarModel.access)

        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            card(input: input, rows: rows)
                .padding(.top, 96)
                .padding(.horizontal, 24)
        }
        // Focus once the overlay is on screen; set during appearance, the field isn't ready to take it.
        .task {
            await Task.yield()
            isFieldFocused = true
        }
        .onChange(of: text) {
            selectedIndex = 0
            errorMessage = nil
        }
    }

    private func card(input: LauncherInput, rows: [LauncherRow]) -> some View {
        VStack(spacing: 0) {
            searchField(rows: rows)

            if input.hasDateOrTime || input.duration != nil || input.priority != .none || !input.tagNames.isEmpty {
                ParsedTokensRow(input: input, previewTags: previewTags(for: input.tagNames))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }

            if !rows.isEmpty {
                results(rows)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                    .padding([.horizontal, .bottom], 10)
            }
        }
        .frame(maxWidth: 580)
        // A floating paper card: the panel surface, a hairline edge and a soft, wide shadow.
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                .strokeBorder(Theme.hairline)
        }
        .shadow(color: .black.opacity(0.18), radius: 30, y: 14)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
    }

    private func searchField(rows: [LauncherRow]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Add a task, plan an event, or search", text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isFieldFocused)
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1, count: rows.count)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1, count: rows.count)
                    return .handled
                }
                .onKeyPress(.return) {
                    if rows.indices.contains(selectedIndex) { run(rows[selectedIndex]) }
                    return .handled
                }
                .onKeyPress(.escape) {
                    close()
                    return .handled
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius + 2, style: .continuous))
        .padding(10)
    }

    private func results(_ rows: [LauncherRow]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        Button {
                            selectedIndex = index
                            run(row)
                        } label: {
                            LauncherRowView(row: row, isSelected: index == selectedIndex)
                        }
                        .buttonStyle(.plain)
                        .id(row.id)
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: 340)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedIndex) {
                guard rows.indices.contains(selectedIndex) else { return }
                proxy.scrollTo(rows[selectedIndex].id)
            }
        }
    }

    // MARK: Actions

    private func moveSelection(by offset: Int, count: Int) {
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), count - 1)
    }

    private func run(_ row: LauncherRow) {
        do {
            switch row {
            case .newTask(let input):
                try LauncherActions.createTask(from: input, in: modelContext)
            case .newEvent(let input):
                try LauncherActions.createEvent(from: input, in: calendarModel, calendar: .current)
            case .existing(let task):
                appState.select(task: task.persistentModelID)
            }
            close()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func close() {
        text = ""
        errorMessage = nil
        isPresented = false
    }

    /// Existing tags as they are, and unsaved stand-ins in the color a new tag would get.
    private func previewTags(for names: [String]) -> [Tag] {
        var newCount = 0
        return names.map { name in
            if let tag = tags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return tag
            }
            defer { newCount += 1 }
            return Tag(name: name, color: TagColor.next(after: tags.count + newCount))
        }
    }
}

/// Chips showing what the parser recognized.
private struct ParsedTokensRow: View {
    let input: LauncherInput
    let previewTags: [Tag]

    var body: some View {
        HStack(spacing: 6) {
            if let day = input.day {
                chip(DayFormatting.relativeTitle(for: day), systemImage: "calendar")
            }
            if let start = input.start {
                chip(start.formatted(date: .omitted, time: .shortened), systemImage: "clock")
            }
            if let duration = input.duration {
                chip(LauncherFormatting.duration(duration), systemImage: "hourglass")
            }
            if input.priority != .none {
                chip(input.priority.title, systemImage: "flag.fill", tint: input.priority.color)
            }
            ForEach(previewTags, id: \.name) { tag in
                TagChip(tag: tag)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recognized details")
    }

    /// The same soft pill as a tag: tinted text on a faint wash of its color.
    private func chip(_ title: String, systemImage: String, tint: Color = .secondary) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct LauncherRowView: View {
    let row: LauncherRow
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            icon
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .lineLimit(1)
                    .strikethrough(isDoneTask)
                    .foregroundStyle(isDoneTask ? .secondary : .primary)
                if subtitle != nil || !rowTags.isEmpty {
                    HStack(spacing: 6) {
                        if let subtitle {
                            Text(subtitle)
                                .foregroundStyle(subtitleColor)
                        }
                        ForEach(rowTags) { tag in
                            TagChip(tag: tag)
                        }
                    }
                    .font(.caption)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "return")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.14) : (isHovered ? Theme.cardHover : Color.clear),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .onHover { isHovered = $0 }
    }

    /// An existing task's tags, shown as the same pills as in the lists.
    private var rowTags: [Tag] {
        if case .existing(let task) = row { return task.orderedTags }
        return []
    }

    /// Overdue and later-today times stand out, as they do in the lists.
    private var subtitleColor: Color {
        if case .existing(let task) = row { return TaskQuery().timeEmphasis(for: task).color }
        return .secondary
    }

    @ViewBuilder
    private var icon: some View {
        switch row {
        case .newTask:
            Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
        case .newEvent:
            Image(systemName: "calendar.badge.plus").foregroundStyle(Color.accentColor)
        case .existing(let task):
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isDone ? Color.secondary : task.priority.color)
        }
    }

    private var title: String {
        switch row {
        case .newTask(let input): "New Task: \(input.title)"
        case .newEvent(let input): "New Event: \(input.title)"
        case .existing(let task): task.title.isEmpty ? "Untitled" : task.title
        }
    }

    private var subtitle: String? {
        switch row {
        case .newTask(let input):
            if let start = input.start {
                return "Scheduled \(LauncherFormatting.dayAndTime(start))"
            }
            return input.day.map { "Due \(DayFormatting.relativeTitle(for: $0))" } ?? "Inbox"
        case .newEvent(let input):
            guard let day = input.day else { return nil }
            guard let start = input.start else { return "All day, \(DayFormatting.relativeTitle(for: day))" }
            let end = start.addingTimeInterval(input.duration ?? LauncherInput.defaultEventDuration)
            return "\(LauncherFormatting.dayAndTime(start)) – \(end.formatted(date: .omitted, time: .shortened))"
        case .existing(let task):
            if let start = task.scheduledStart { return LauncherFormatting.dayAndTime(start) }
            return task.dueDate.map { "Due \(DayFormatting.relativeTitle(for: $0))" }
        }
    }

    private var isDoneTask: Bool {
        if case .existing(let task) = row { return task.isDone }
        return false
    }
}

private enum LauncherFormatting {
    static func dayAndTime(_ date: Date) -> String {
        "\(DayFormatting.relativeTitle(for: date)), \(date.formatted(date: .omitted, time: .shortened))"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

#Preview {
    QuickLauncherView(isPresented: .constant(true))
        .environment(AppState())
        .environment(WeekCalendarModel(source: StaticCalendarSource()))
        .modelContainer(PlannerSchema.makeContainer(inMemory: true))
        .frame(width: 900, height: 600)
}
