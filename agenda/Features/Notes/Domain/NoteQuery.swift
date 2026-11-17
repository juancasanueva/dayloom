import Foundation

enum NoteQuery {
    /// Pinned notes first, then the most recently updated. A blank search keeps every note;
    /// otherwise title or text must contain it, ignoring case and accents.
    static func notes(from notes: [Note], matching search: String) -> [Note] {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = search.isEmpty ? notes : notes.filter {
            $0.title.localizedStandardContains(search) || $0.plainText.localizedStandardContains(search)
        }
        return matches.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
