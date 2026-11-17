import SwiftData
import SwiftUI

/// Notes screen: a searchable column of note cards beside the selected note's editor.
struct NotesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]

    @State private var search = ""
    @State private var notePendingDeletion: Note?
    /// The note just created with "New Note", whose title gets focus.
    @State private var newNoteID: PersistentIdentifier?
    @FocusState private var isListFocused: Bool
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Theme.pagePadding.leading)
                .padding(.top, Theme.pagePadding.top)
                .padding(.bottom, 14)

            HSplitView {
                noteList
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 400)
                detail
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .plannerPanel()
        .navigationTitle("Notes")
        .toolbar(removing: .title)
        // ⌘F reaches the search field, which lives above the list instead of in the toolbar.
        .background {
            Button("Search Notes") { isSearchFocused = true }
                .keyboardShortcut("f")
                .hidden()
        }
        .onAppear(perform: consumePendingNewNote)
        .onChange(of: appState.pendingNewNote) { consumePendingNewNote() }
        .confirmationDialog(
            "Delete this note?",
            isPresented: isConfirmingDeletion,
            presenting: notePendingDeletion
        ) { note in
            Button("Delete \u{201C}\(note.displayTitle)\u{201D}", role: .destructive) { delete(note) }
        } message: { _ in
            Text("Tasks created from it stay in your lists.")
        }
    }

    private var header: some View {
        PageHeader("Notes", subtitle: NotesHeading.subtitle(for: notes)) {
            HStack(spacing: 8) {
                Button("Today's Note", systemImage: "sun.max", action: openTodaysNote)
                    .help("Open today's note")
                Button("New Note", systemImage: "square.and.pencil", action: createNote)
                    .help("New note (⇧⌘N)")
            }
            .buttonStyle(PageControlStyle())
        }
    }

    // MARK: List

    private var noteList: some View {
        let visible = NoteQuery.notes(from: notes, matching: search)

        return VStack(spacing: 10) {
            searchField
                .padding(.leading, Theme.pagePadding.leading)
                .padding(.trailing, 14)
            noteCards(visible)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search Notes", text: $search, prompt: Text("Search Notes"))
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($isSearchFocused)
                .onExitCommand { search = "" }
            if !search.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") { search = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.6) : Theme.hairline, lineWidth: 1)
        }
    }

    private func noteCards(_ visible: [Note]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(visible) { note in
                        let id = note.persistentModelID
                        let isSelected = appState.selectedNoteID == id
                        NoteCard(note: note, isSelected: isSelected)
                            .id(id)
                            .onTapGesture { select(id) }
                            .contextMenu { noteMenu(note) }
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { select(id) }
                    }
                }
                .padding(.leading, Theme.pagePadding.leading)
                .padding(.trailing, 14)
                .padding(.top, 4)
                .padding(.bottom, Theme.pagePadding.bottom)
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isListFocused)
            .onKeyPress(.downArrow) { moveSelection(by: 1, in: visible) }
            .onKeyPress(.upArrow) { moveSelection(by: -1, in: visible) }
            .onChange(of: appState.selectedNoteID) { _, id in
                guard let id, visible.contains(where: { $0.persistentModelID == id }) else { return }
                withAnimation(.snappy) { proxy.scrollTo(id) }
            }
        }
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Write down ideas, plans, and meeting notes."))
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    @ViewBuilder
    private func noteMenu(_ note: Note) -> some View {
        Button(note.isPinned ? "Unpin" : "Pin") { note.isPinned.toggle() }
        Divider()
        Button("Delete Note…", role: .destructive) { notePendingDeletion = note }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let note = selectedNote {
            NoteEditorView(note: note, focusesTitle: note.persistentModelID == newNoteID)
                .id(note.persistentModelID)
        } else {
            ContentUnavailableView {
                Label("No Note Selected", systemImage: "note.text")
            } description: {
                Text("Pick a note, or start a new one.")
            } actions: {
                Button("New Note", action: createNote)
                Button("Today's Note", action: openTodaysNote)
            }
        }
    }

    private var selectedNote: Note? {
        guard let id = appState.selectedNoteID else { return nil }
        return notes.first { $0.persistentModelID == id }
    }

    // MARK: Actions

    private func createNote() {
        let note = NoteEditor().newNote(in: modelContext)
        select(note)
        newNoteID = note.persistentModelID
    }

    private func openTodaysNote() {
        select(NoteEditor().dailyNote(for: .now, in: modelContext))
    }

    private func select(_ note: Note) {
        try? modelContext.save() // Swap the temporary ID for a permanent one before selecting it.
        search = ""
        appState.selectedNoteID = note.persistentModelID
    }

    /// Selects a card from the list and keeps the arrow keys on the list.
    private func select(_ id: PersistentIdentifier) {
        appState.selectedNoteID = id
        isListFocused = true
    }

    private func moveSelection(by offset: Int, in visible: [Note]) -> KeyPress.Result {
        let ids = visible.map(\.persistentModelID)
        guard let next = ListNavigation.step(from: appState.selectedNoteID, in: ids, by: offset) else { return .ignored }
        appState.selectedNoteID = next
        return .handled
    }

    private func consumePendingNewNote() {
        guard appState.pendingNewNote else { return }
        appState.pendingNewNote = false
        createNote()
    }

    private func delete(_ note: Note) {
        if appState.selectedNoteID == note.persistentModelID {
            appState.selectedNoteID = nil
        }
        modelContext.delete(note)
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(get: { notePendingDeletion != nil }, set: { if !$0 { notePendingDeletion = nil } })
    }
}

/// The short line under the Notes title: how many notes there are, and how many are pinned.
enum NotesHeading {
    static func subtitle(for notes: [Note]) -> String {
        guard !notes.isEmpty else { return "No notes yet" }
        let count = notes.count == 1 ? "1 note" : "\(notes.count) notes"
        let pinned = notes.filter(\.isPinned).count
        return pinned == 0 ? count : "\(count) · \(pinned) pinned"
    }
}

/// The line a note card shows under its title.
enum NotePreview {
    /// The first line of text that isn't already shown as the title, or "" when there is none.
    static func line(for note: Note) -> String {
        let title = note.displayTitle
        return note.plainText
            .split(separator: "\n")
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && $0 != title } ?? ""
    }
}

/// One note as a soft card: title with its daily or pinned mark, a preview line, and when it was edited.
private struct NoteCard: View {
    let note: Note
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        let preview = NotePreview.line(for: note)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if note.dailyDate != nil {
                    Image(systemName: "sun.max.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Daily note")
                }
                Text(note.displayTitle)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Pinned")
                }
            }
            if !preview.isEmpty {
                Text(preview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(DayFormatting.relativeTitle(for: note.updatedAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(isSelected: isSelected, isHovered: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
    }
}
