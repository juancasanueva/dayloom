import Foundation
import SwiftData

/// A note shown in a task's details: linked by hand, holding the task as a block, or both.
struct RelatedNote: Identifiable {
    let note: Note
    /// Linked by hand, so it can be unlinked.
    let isLinked: Bool
    /// Holds the task as a block, so it stays listed while the block is there.
    let containsTask: Bool

    var id: PersistentIdentifier { note.persistentModelID }
}

extension TaskItem {
    /// Notes linked by hand and notes holding the task, each once, in the Notes list's order.
    var relatedNotes: [RelatedNote] {
        let linked = linkedNotes ?? []
        let holding = (noteBlocks ?? []).compactMap(\.note)
        var seen = Set<PersistentIdentifier>()
        let unique = (linked + holding).filter { seen.insert($0.persistentModelID).inserted }
        return NoteQuery.notes(from: unique, matching: "").map { note in
            RelatedNote(
                note: note,
                isLinked: linked.contains { $0 === note },
                containsTask: holding.contains { $0 === note }
            )
        }
    }

    func link(_ note: Note) {
        guard !(linkedNotes ?? []).contains(where: { $0 === note }) else { return }
        linkedNotes = (linkedNotes ?? []) + [note]
    }

    func unlink(_ note: Note) {
        linkedNotes = (linkedNotes ?? []).filter { $0 !== note }
    }

    /// Notes the picker offers: those not listed on the task yet, searched like the Notes list.
    func linkableNotes(from notes: [Note], matching search: String) -> [Note] {
        let listed = Set(relatedNotes.map(\.id))
        return NoteQuery.notes(from: notes, matching: search).filter { !listed.contains($0.persistentModelID) }
    }
}
