import SwiftData
import SwiftUI

/// Notes screen: a searchable list of notes beside the selected note's editor.
struct NotesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]

    @State private var search = ""
    @State private var notePendingDeletion: Note?
    /// The note just created with "New Note", whose title gets focus.
    @State private var newNoteID: PersistentIdentifier?

    var body: some View {
        HSplitView {
            noteList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 380)
            detail
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Notes")
        .searchable(text: $search, prompt: "Search Notes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Today's Note", systemImage: "sun.max", action: openTodaysNote)
                    .help("Open today's note")
                Button("New Note", systemImage: "square.and.pencil", action: createNote)
                    .help("New note (⇧⌘N)")
            }
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

    // MARK: List

    private var noteList: some View {
        @Bindable var appState = appState
        let visible = NoteQuery.notes(from: notes, matching: search)

        return List(selection: $appState.selectedNoteID) {
            ForEach(visible) { note in
                NoteListRow(note: note)
                    .tag(note.persistentModelID)
                    .contextMenu { noteMenu(note) }
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

private struct NoteListRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if note.dailyDate != nil {
                    Image(systemName: "sun.max").foregroundStyle(.orange)
                }
                Text(note.displayTitle)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Pinned")
                }
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        let preview = note.plainText
            .split(separator: "\n")
            .first { $0.trimmingCharacters(in: .whitespaces) != note.displayTitle }
            .map(String.init) ?? ""
        let day = DayFormatting.relativeTitle(for: note.updatedAt)
        return preview.isEmpty ? day : "\(day) · \(preview)"
    }
}
