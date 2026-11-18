import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var taskTarget: NoteBlock?
    @State private var imageTarget: NoteBlock?
    @State private var isImportingImage = false
    @State private var pasteMonitor: Any?

    /// Built per edit so each change is stamped with the current time.
    private var editor: NoteEditor { NoteEditor() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
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
                    .onDrop(of: NoteImageSource.dropTypes, isTargeted: nil) { providers in
                        dropImages(providers, at: endBlock())
                    }
                    .accessibilityHidden(true)
            }
            .lineSpacing(3)
            .frame(maxWidth: Self.writingWidth, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: note.title) { markEditedWhileTyping() }
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
        .sheet(item: $taskTarget) { block in
            TaskPickerSheet { task in
                editor.linkTask(task, to: block)
            }
        }
        .fileImporter(
            isPresented: $isImportingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            defer { imageTarget = nil }
            guard let block = imageTarget, case .success(let urls) = result else { return }
            addImages(NoteImageSource.images(at: urls), at: block)
        }
        .onAppear(perform: startPasteMonitor)
        .onDisappear(perform: stopPasteMonitor)
    }

    /// A comfortable line length for writing.
    private static let writingWidth: CGFloat = 680

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let day = note.dailyDate {
                Label(DayFormatting.relativeTitle(for: day), systemImage: "sun.max.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.14), in: Capsule())
            }
            TextField("Untitled", text: $note.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .focused($isTitleFocused)
                .onKeyPress(.return) {
                    focusFirstBlock()
                    return .handled
                }
            Text("Edited \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 18)
        }
    }

    // MARK: Actions

    private func handle(_ action: BlockAction, on block: NoteBlock) -> Bool {
        switch action {
        case .textChanged:
            markEditedWhileTyping()
            // Applied on the next turn: rewriting the text inside the field's own change
            // callback gets overwritten by the field.
            Task { @MainActor in
                if let focus = editor.applyShortcut(to: block) {
                    place(focus)
                }
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
            } else if command == .existingTask {
                taskTarget = block
            } else if command == .image {
                imageTarget = block
                isImportingImage = true
            }
        case .convertToTask:
            editor.convertToTask(block, in: modelContext)
        case .openTask(let task):
            try? modelContext.save() // Swap the temporary ID for a permanent one before selecting it.
            appState.select(task: task.persistentModelID)
        case .dropImages(let providers):
            return dropImages(providers, at: block)
        case .delete:
            let neighbor = focusableNeighbor(of: block, offset: -1) ?? focusableNeighbor(of: block, offset: 1)
            editor.delete(block)
            if let neighbor {
                place(NoteFocus(block: neighbor, caret: neighbor.text.count))
            }
        }
        return true
    }

    /// Re-stamping the note on every keystroke re-renders the whole screen and can drop
    /// keys typed during the refresh, so typing refreshes the edited time at most every 30 seconds.
    private func markEditedWhileTyping() {
        let now = Date.now
        if now.timeIntervalSince(note.updatedAt) > 30 {
            note.updatedAt = now
        }
    }

    private func place(_ focus: NoteFocus) {
        let id = focus.block.objectID
        // The focused field already shows the edit; moving its caret would fight the typing.
        guard focusedBlock != id else { return }
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
        place(NoteFocus(block: endBlock(), caret: 0))
    }

    /// The trailing empty text block, added when the note doesn't end with one.
    private func endBlock() -> NoteBlock {
        if let last = note.orderedBlocks.last, last.kind.isTextLike, last.text.isEmpty {
            return last
        }
        return note.appendBlock(.text)
    }

    // MARK: Images

    /// Shrinks pictures off the main thread, then adds them at `block` in order.
    private func addImages(_ images: [Data], at block: NoteBlock) {
        guard !images.isEmpty else { return }
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                images.compactMap(NoteImage.prepared)
            }.value
            // The block may have been deleted while the images were being shrunk.
            var target = block.note == nil ? endBlock() : block
            for data in prepared {
                target = editor.insertImage(data, at: target).block
            }
            if !prepared.isEmpty {
                place(NoteFocus(block: target, caret: 0))
            }
        }
    }

    private func dropImages(_ providers: [NSItemProvider], at block: NoteBlock) -> Bool {
        let accepted = providers.contains { provider in
            NoteImageSource.dropTypes.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        }
        guard accepted else { return false }
        Task {
            addImages(await NoteImageSource.images(from: providers), at: block)
        }
        return true
    }

    /// ⌘V reaches the text field before any SwiftUI paste handler, and a plain-text field
    /// ignores pictures, so pasted images are caught from the key event first.
    private func startPasteMonitor() {
        guard pasteMonitor == nil else { return }
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "v",
                  let id = focusedBlock,
                  let block = note.orderedBlocks.first(where: { $0.objectID == id }),
                  let images = NoteImageSource.images(on: .general) else { return event }
            addImages(images, at: block)
            return nil
        }
    }

    private func stopPasteMonitor() {
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
        pasteMonitor = nil
    }
}

extension NoteBlock {
    /// Stable for the object's lifetime, unlike `persistentModelID`, which changes on first save.
    var objectID: ObjectIdentifier { ObjectIdentifier(self) }

    var isFocusable: Bool { kind.isTextLike || kind == .task }
}
