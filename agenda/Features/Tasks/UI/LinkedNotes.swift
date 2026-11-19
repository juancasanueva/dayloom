import SwiftData
import SwiftUI

/// One note in a task's details. Clicking it opens the note; a note linked by hand can be unlinked.
struct LinkedNoteRow: View {
    let related: RelatedNote
    let open: () -> Void
    let unlink: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: open) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(related.note.displayTitle)
                            .lineLimit(1)
                        if related.containsTask {
                            Text("Contains this task")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open in Notes")

            if related.isLinked {
                Button("Unlink Note", systemImage: "xmark", action: unlink)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Unlink Note")
                    .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .plannerCard(isHovered: isHovered)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// Searches notes so one can be linked to a task. Notes already listed on the task aren't offered.
struct NotePickerSheet: View {
    let task: TaskItem
    let pick: (Note) -> Void

    @Query private var notes: [Note]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var candidates: [Note] { task.linkableNotes(from: notes, matching: query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Link a Note")
                .font(Theme.sectionTitle)
            TextField("Search notes", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    if let first = candidates.first { choose(first) }
                }
            noteList
        }
        .padding(20)
        .frame(width: 400, height: 380)
        .background(Theme.panel)
        .onAppear { isSearchFocused = true }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var noteList: some View {
        let candidates = candidates
        if candidates.isEmpty {
            ContentUnavailableView(
                query.isEmpty ? "No Notes" : "No Matches",
                systemImage: "note.text",
                description: Text(query.isEmpty ? "Every note is already linked." : "No note contains “\(query)”.")
            )
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(candidates) { note in
                        Button { choose(note) } label: { NotePickerRow(note: note) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func choose(_ note: Note) {
        pick(note)
        dismiss()
    }
}

/// One note in the picker, as a soft card.
private struct NotePickerRow: View {
    let note: Note

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: note.dailyDate == nil ? "note.text" : "sun.max")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayTitle)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("Edited \(note.updatedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(.app)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(isHovered: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
