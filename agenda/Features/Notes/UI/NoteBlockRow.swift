import SwiftData
import SwiftUI

/// What a block row asks its editor to do. The editor returns `false` when nothing happened.
enum BlockAction {
    case textChanged
    case split(caret: Int)
    case backspaceAtStart
    case focusPrevious
    case focusNext
    case move(Int)
    case command(SlashCommand)
    case convertToTask
    case openTask(TaskItem)
    case delete
}

/// One block of a note, drawn for its kind, with keyboard handling and the slash menu.
struct NoteBlockRow: View {
    @Bindable var block: NoteBlock
    var focus: FocusState<ObjectIdentifier?>.Binding
    let caretRequest: CaretRequest?
    let perform: (BlockAction) -> Bool

    @State private var selection: TextSelection?
    @State private var highlightedCommand = 0
    @State private var isSlashMenuDismissed = false

    private var isFocused: Bool { focus.wrappedValue == block.objectID }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let commands = slashCommands, !commands.isEmpty {
                SlashMenu(commands: commands, highlighted: highlightedCommand) { command in
                    _ = perform(.command(command))
                }
            }
        }
        .contextMenu { blockMenu }
        .onChange(of: block.text) {
            highlightedCommand = 0
            if SlashCommand.query(in: block.text) == nil {
                isSlashMenuDismissed = false
            }
            _ = perform(.textChanged)
        }
        .onChange(of: caretRequest, initial: true) { _, request in
            guard let request, request.blockID == block.objectID else { return }
            focus.wrappedValue = block.objectID
            // Placing the caret after focus lands keeps the field from selecting all its text.
            Task { @MainActor in
                await Task.yield()
                let text = editedText
                let offset = min(request.caret, text.count)
                selection = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: offset))
            }
        }
    }

    // MARK: Kinds

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .text:
            field($block.text, prompt: isFocused ? "Type / for blocks" : nil)
        case .heading:
            field($block.text, prompt: "Heading", font: .title2.weight(.semibold))
                .padding(.top, 8)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                field($block.text, prompt: "List item")
            }
        case .checklist:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    block.isChecked.toggle()
                } label: {
                    Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(block.isChecked ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(block.isChecked ? "Uncheck" : "Check")
                field($block.text, prompt: "To-do")
                    .strikethrough(block.isChecked)
                    .foregroundStyle(block.isChecked ? .secondary : .primary)
            }
        case .divider:
            Divider().padding(.vertical, 10)
        case .task:
            if let task = block.task {
                taskContent(task)
            }
        case .event:
            EventBlockView(block: block)
        }
    }

    private func taskContent(_ task: TaskItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CompletionButton(task: task)
            field(taskTitle(task), prompt: "Task name")
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? .secondary : .primary)
            if let due = task.dueDate {
                Text(DayFormatting.relativeTitle(for: due))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Show Task Details", systemImage: "info.circle") {
                _ = perform(.openTask(task))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .onAppear { block.syncTaskSnapshot() }
        .onChange(of: task.isDone) { block.syncTaskSnapshot() }
    }

    /// Edits the task title and keeps the block's snapshot in step.
    private func taskTitle(_ task: TaskItem) -> Binding<String> {
        Binding(
            get: { task.title },
            set: { task.title = $0; block.syncTaskSnapshot() }
        )
    }

    private func field(_ text: Binding<String>, prompt: String?, font: Font = .body) -> some View {
        TextField("Block", text: text, selection: $selection, prompt: prompt.map { Text($0) }, axis: .vertical)
            .labelsHidden()
            .textFieldStyle(.plain)
            .font(font)
            .focused(focus, equals: block.objectID)
            .onKeyPress(phases: .down) { handleKey($0) }
    }

    @ViewBuilder
    private var blockMenu: some View {
        if block.kind == .text || block.kind == .checklist {
            Button("Convert to Task") { _ = perform(.convertToTask) }
        }
        if let task = block.task {
            Button("Show Task Details") { _ = perform(.openTask(task)) }
        }
        Button("Move Up") { _ = perform(.move(-1)) }
        Button("Move Down") { _ = perform(.move(1)) }
        Divider()
        Button("Delete Block", role: .destructive) { _ = perform(.delete) }
    }

    // MARK: Keyboard

    /// The text the caret moves through: the task title for task blocks.
    private var editedText: String { block.task?.title ?? block.text }

    private var slashCommands: [SlashCommand]? {
        guard block.kind == .text, isFocused, !isSlashMenuDismissed,
              let query = SlashCommand.query(in: block.text) else { return nil }
        return SlashCommand.matching(query)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let text = editedText
        let commands = slashCommands ?? []
        switch press.key {
        case .return where press.modifiers.isEmpty:
            if !commands.isEmpty {
                _ = perform(.command(commands[min(highlightedCommand, commands.count - 1)]))
            } else {
                _ = perform(.split(caret: caretRange(in: text)?.lowerBound ?? text.count))
            }
            return .handled

        case .delete where press.modifiers.isEmpty:
            guard isCaretAtStart(in: text) else { return .ignored }
            return perform(.backspaceAtStart) ? .handled : .ignored

        case .upArrow, .downArrow:
            let isUp = press.key == .upArrow
            if press.modifiers == [.option, .command] {
                _ = perform(.move(isUp ? -1 : 1))
                return .handled
            }
            guard press.modifiers.isEmpty else { return .ignored }
            if !commands.isEmpty {
                highlightedCommand = (highlightedCommand + (isUp ? -1 : 1) + commands.count) % commands.count
                return .handled
            }
            let isAtEdge = isUp ? isOnFirstLine(text) : isOnLastLine(text)
            guard isAtEdge else { return .ignored }
            return perform(isUp ? .focusPrevious : .focusNext) ? .handled : .ignored

        case .escape where slashCommands != nil:
            isSlashMenuDismissed = true
            return .handled

        default:
            return .ignored
        }
    }

    /// Caret or selected range as character offsets, when the field has reported one.
    private func caretRange(in text: String) -> Range<Int>? {
        guard let selection, case .selection(let range) = selection.indices,
              range.upperBound <= text.endIndex else { return nil }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        return lower..<upper
    }

    private func isCaretAtStart(in text: String) -> Bool {
        guard let range = caretRange(in: text) else { return text.isEmpty }
        return range == 0..<0
    }

    private func isOnFirstLine(_ text: String) -> Bool {
        guard let range = caretRange(in: text) else { return true }
        return !text.prefix(range.lowerBound).contains("\n")
    }

    private func isOnLastLine(_ text: String) -> Bool {
        guard let range = caretRange(in: text) else { return true }
        return !text.dropFirst(range.upperBound).contains("\n")
    }
}

private struct SlashMenu: View {
    let commands: [SlashCommand]
    let highlighted: Int
    let pick: (SlashCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(commands.enumerated()), id: \.element) { index, command in
                Label(command.title, systemImage: command.symbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        index == highlighted ? Color.accentColor.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { pick(command) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(index == highlighted ? .isSelected : [])
            }
        }
        .padding(6)
        .frame(width: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

/// A calendar event inside a note. Marked unavailable when the event can't be found anymore.
private struct EventBlockView: View {
    let block: NoteBlock
    @Environment(WeekCalendarModel.self) private var calendarModel
    @State private var isUnavailable = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isUnavailable ? Color.secondary : Color.accentColor)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.text.isEmpty ? "Event" : block.text)
                    .fontWeight(.medium)
                    .strikethrough(isUnavailable)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isUnavailable {
                Text("Unavailable")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .help("This event was moved or deleted in Calendar.")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .task(id: calendarModel.access) { refresh() }
    }

    private var timeText: String {
        guard let start = block.eventStart else { return "" }
        let day = DayFormatting.relativeTitle(for: start)
        if block.eventIsAllDay { return "\(day) · All day" }
        let from = start.formatted(date: .omitted, time: .shortened)
        guard let end = block.eventEnd else { return "\(day) · \(from)" }
        return "\(day) · \(from) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    /// Without calendar access the snapshot is all there is, so it isn't marked unavailable.
    private func refresh() {
        guard calendarModel.access == .granted, let start = block.eventStart else {
            isUnavailable = false
            return
        }
        isUnavailable = !block.refreshEvent(from: calendarModel.events(on: start))
    }
}
