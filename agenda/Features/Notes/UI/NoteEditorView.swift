import SwiftData
import SwiftUI

/// Asks one block row to place its caret. The serial makes repeated requests distinct.
struct CaretRequest: Equatable {
    let blockID: ObjectIdentifier
    let caret: Int
    let serial: Int
}

/// Title and blocks of one note. Keyboard edits go through `NoteEditor`.
struct NoteEditorView: View {
    @Bindable var note: Note
    let focusesTitle: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @FocusState private var focusedBlock: ObjectIdentifier?
    @FocusState private var isTitleFocused: Bool
    @State private var caretRequest: CaretRequest?
    @State private var eventTarget: NoteBlock?

    /// Built per edit so each change is stamped with the current time.
    private var editor: NoteEditor { NoteEditor() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                header
                ForEach(note.orderedBlocks, id: \.objectID) { block in
                    NoteBlockRow(
                        block: block,
                        focus: $focusedBlock,
                        caretRequest: caretRequest,
                        perform: { handle($0, on: block) }
                    )
                }
                Color.clear
                    .frame(height: 160)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: focusEnd)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: note.title) { note.updatedAt = .now }
        .onAppear {
            if focusesTitle {
                isTitleFocused = true
            } else if note.orderedBlocks.allSatisfy({ $0.text.isEmpty }) {
                focusEnd()
            }
        }
        .sheet(item: $eventTarget) { block in
            EventPickerSheet(day: note.dailyDate ?? .now) { entry in
                editor.setEvent(entry, on: block)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let day = note.dailyDate {
                Label(DayFormatting.relativeTitle(for: day), systemImage: "sun.max")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            }
            TextField("Untitled", text: $note.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .bold))
                .focused($isTitleFocused)
                .onKeyPress(.return) {
                    focusFirstBlock()
                    return .handled
                }
            Text("Edited \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
    }

    // MARK: Actions

    private func handle(_ action: BlockAction, on block: NoteBlock) -> Bool {
        switch action {
        case .textChanged:
            note.updatedAt = .now
            if let focus = editor.applyShortcut(to: block) {
                place(focus)
            }
        case .split(let caret):
            place(editor.split(block, at: caret))
        case .backspaceAtStart:
            guard let focus = editor.backspaceAtStart(block) else { return false }
            place(focus)
        case .focusPrevious:
            if let previous = focusableNeighbor(of: block, offset: -1) {
                place(NoteFocus(block: previous, caret: previous.text.count))
            } else {
                isTitleFocused = true
            }
        case .focusNext:
            guard let next = focusableNeighbor(of: block, offset: 1) else { return false }
            place(NoteFocus(block: next, caret: 0))
        case .move(let offset):
            withAnimation(.snappy) { editor.move(block, by: offset) }
        case .command(let command):
            place(editor.apply(command, to: block, in: modelContext))
            if command == .event {
                eventTarget = block
            }
        case .convertToTask:
            editor.convertToTask(block, in: modelContext)
        case .openTask(let task):
            try? modelContext.save() // Swap the temporary ID for a permanent one before selecting it.
            appState.select(task: task.persistentModelID)
        case .delete:
            let neighbor = focusableNeighbor(of: block, offset: -1) ?? focusableNeighbor(of: block, offset: 1)
            editor.delete(block)
            if let neighbor {
                place(NoteFocus(block: neighbor, caret: neighbor.text.count))
            }
        }
        return true
    }

    private func place(_ focus: NoteFocus) {
        let id = focus.block.objectID
        caretRequest = CaretRequest(blockID: id, caret: focus.caret, serial: (caretRequest?.serial ?? 0) + 1)
        focusedBlock = id
    }

    private func focusableNeighbor(of block: NoteBlock, offset: Int) -> NoteBlock? {
        let blocks = note.orderedBlocks
        guard let index = blocks.firstIndex(where: { $0 === block }) else { return nil }
        let candidates = offset < 0 ? Array(blocks[..<index].reversed()) : Array(blocks[(index + 1)...])
        return candidates.first(where: \.isFocusable)
    }

    private func focusFirstBlock() {
        if let first = note.orderedBlocks.first(where: \.isFocusable) {
            place(NoteFocus(block: first, caret: 0))
        } else {
            focusEnd()
        }
    }

    /// Focuses the trailing empty text block, adding one when the note doesn't end with it.
    private func focusEnd() {
        if let last = note.orderedBlocks.last, last.kind.isTextLike, last.text.isEmpty {
            place(NoteFocus(block: last, caret: 0))
        } else {
            place(NoteFocus(block: note.appendBlock(.text), caret: 0))
        }
    }
}

extension NoteBlock {
    /// Stable for the object's lifetime, unlike `persistentModelID`, which changes on first save.
    var objectID: ObjectIdentifier { ObjectIdentifier(self) }

    var isFocusable: Bool { kind.isTextLike || kind == .task }
}
