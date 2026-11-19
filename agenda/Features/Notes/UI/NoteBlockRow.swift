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
    case dropImages([NSItemProvider])
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
        .onDrop(of: NoteImageSource.dropTypes, isTargeted: nil) { perform(.dropImages($0)) }
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

    /// Text-like and task blocks share one text field, so changing the kind while typing
    /// (a markdown shortcut, a slash command) keeps the field and its keystrokes intact.
    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .divider:
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.vertical, 12)
                .accessibilityHidden(true)
        case .event:
            EventBlockView(block: block)
        case .image:
            ImageBlockView(block: block)
        case .text, .heading, .bullet, .checklist, .task:
            textRow
        }
    }

    private var textRow: some View {
        let task = block.task
        let isDone = task?.isDone ?? (block.kind == .checklist && block.isChecked)
        let isTask = task != nil
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            leadingAccessory
            field(task.map(taskTitle) ?? $block.text, prompt: prompt, font: block.kind == .heading ? Self.headingFont : Self.bodyFont)
                .strikethrough(isDone)
                .foregroundStyle(isDone ? .secondary : .primary)
            if let task {
                taskAccessories(task)
            }
        }
        // A linked task sits on a soft tile so it reads apart from a plain checklist item.
        .padding(.horizontal, isTask ? 10 : 0)
        .padding(.vertical, isTask ? 6 : 0)
        .background(isTask ? Theme.card : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .padding(.top, block.kind == .heading ? 14 : 0)
    }

    private static let bodyFont = Font.system(size: 14)
    private static let headingFont = Font.system(size: 22, weight: .bold, design: .rounded)

    @ViewBuilder
    private var leadingAccessory: some View {
        switch block.kind {
        case .bullet:
            Text("•")
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        case .checklist:
            Button {
                block.isChecked.toggle()
            } label: {
                // The same check as a task's completion button.
                Image(systemName: block.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(block.isChecked ? "Uncheck" : "Check")
        case .task:
            if let task = block.task {
                CompletionButton(task: task)
            }
        case .text, .heading, .divider, .event, .image:
            EmptyView()
        }
    }

    private var prompt: String {
        switch block.kind {
        case .text: isFocused ? "Type / for blocks" : ""
        case .heading: String(appLocalized: "Heading")
        case .bullet: String(appLocalized: "List item")
        case .checklist: String(appLocalized: "To-do")
        case .task: String(appLocalized: "Task name")
        case .divider, .event, .image: ""
        }
    }

    @ViewBuilder
    private func taskAccessories(_ task: TaskItem) -> some View {
        if let due = task.dueDate {
            Text(DayFormatting.relativeTitle(for: due))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Theme.hairline, in: Capsule())
        }
        Button("Show Task Details", systemImage: "info.circle") {
            _ = perform(.openTask(task))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
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

    private func field(_ text: Binding<String>, prompt: String, font: Font) -> some View {
        TextField("", text: text, selection: $selection, prompt: Text(prompt), axis: .vertical)
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
        // Arrow keys arrive tagged with the numeric-pad/function flags; only real modifiers matter.
        let modifiers = press.modifiers.intersection([.shift, .control, .option, .command])
        // The Backspace key sends U+007F on the Mac.
        let isBackspace = press.key == .delete || press.characters == "\u{7F}" || press.characters == "\u{8}"

        if isBackspace {
            guard modifiers.isEmpty, isCaretAtStart(in: text) else { return .ignored }
            return perform(.backspaceAtStart) ? .handled : .ignored
        }

        switch press.key {
        case .return where modifiers.isEmpty:
            if !commands.isEmpty {
                _ = perform(.command(commands[min(highlightedCommand, commands.count - 1)]))
            } else {
                _ = perform(.split(caret: caretRange(in: text)?.lowerBound ?? text.count))
            }
            return .handled

        case .upArrow, .downArrow:
            let isUp = press.key == .upArrow
            if modifiers == [.option, .command] {
                _ = perform(.move(isUp ? -1 : 1))
                return .handled
            }
            guard modifiers.isEmpty else { return .ignored }
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
                        index == highlighted ? Theme.accent.opacity(0.14) : Color.clear,
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

/// A picture inside a note, as wide as the text at most. Decoded once per change of its data.
private struct ImageBlockView: View {
    let block: NoteBlock
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: image.size.width, maxHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                    .accessibilityLabel("Image")
            } else {
                Label("Image unavailable", systemImage: "photo")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .task(id: block.imageData?.count) {
            image = block.imageData.flatMap(NSImage.init(data:))
        }
    }
}

/// A calendar event inside a note. Marked unavailable when the event can't be found anymore.
private struct EventBlockView: View {
    let block: NoteBlock
    @Environment(WeekCalendarModel.self) private var calendarModel
    @State private var isUnavailable = false

    var body: some View {
        let tint = isUnavailable ? Color.secondary : Theme.accent

        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.text.isEmpty ? String(appLocalized: "Event") : block.text)
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
            } else {
                Image(systemName: "calendar")
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .task(id: calendarModel.access) { refresh() }
    }

    private var timeText: String {
        guard let start = block.eventStart else { return "" }
        let day = DayFormatting.relativeTitle(for: start)
        if block.eventIsAllDay { return "\(day) · All day" }
        let from = start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.app))
        guard let end = block.eventEnd else { return "\(day) · \(from)" }
        return "\(day) · \(from) – \(end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.app)))"
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
