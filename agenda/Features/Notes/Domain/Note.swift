import Foundation
import SwiftData

enum NoteBlockKind: String, CaseIterable, Codable {
    case text
    case heading
    case bullet
    case checklist
    case divider
    case task
    case event

    /// Blocks edited as a line of text.
    var isTextLike: Bool {
        switch self {
        case .text, .heading, .bullet, .checklist: true
        case .divider, .task, .event: false
        }
    }

    /// Lists keep going when Return is pressed at the end of an item.
    var continuesOnReturn: Bool { self == .bullet || self == .checklist }
}

/// A page of blocks. Daily notes carry the day they belong to.
///
/// Every stored property has a default and relationships are optional so the
/// schema stays compatible with CloudKit-backed stores.
@Model
final class Note {
    var title: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isPinned: Bool = false
    /// Start of the day for a daily note, `nil` for any other note.
    var dailyDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.note)
    var blocks: [NoteBlock]? = []

    init(title: String, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var orderedBlocks: [NoteBlock] {
        (blocks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The title, or the first line of text when the note has none.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = orderedBlocks
            .lazy
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return firstLine ?? "Untitled"
    }

    /// All block text, used for search and previews.
    var plainText: String {
        orderedBlocks.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Adds a block at the end. The note must already be in a context.
    @discardableResult
    func appendBlock(_ kind: NoteBlockKind, text: String = "") -> NoteBlock {
        let block = NoteBlock(kind: kind, text: text)
        block.sortIndex = (orderedBlocks.last?.sortIndex ?? 0) + 1
        modelContext?.insert(block)
        block.note = self
        return block
    }

    /// Adds a block directly below `anchor`.
    @discardableResult
    func insertBlock(_ kind: NoteBlockKind, text: String = "", after anchor: NoteBlock) -> NoteBlock {
        let ordered = orderedBlocks
        guard let index = ordered.firstIndex(where: { $0 === anchor }) else {
            return appendBlock(kind, text: text)
        }
        let block = NoteBlock(kind: kind, text: text)
        let next = ordered.indices.contains(index + 1) ? ordered[index + 1].sortIndex : anchor.sortIndex + 2
        block.sortIndex = (anchor.sortIndex + next) / 2
        modelContext?.insert(block)
        block.note = self
        return block
    }
}

/// One line of a note: text, a divider, a linked task, or a calendar event snapshot.
@Model
final class NoteBlock {
    var kindRaw: String = NoteBlockKind.text.rawValue
    var text: String = ""
    var isChecked: Bool = false
    var sortIndex: Double = 0
    var note: Note?

    /// Linked task for `.task` blocks. Deleting the task leaves this `nil`.
    var task: TaskItem?

    /// Snapshot of the event for `.event` blocks, so they render without calendar access.
    var eventID: String?
    var eventStart: Date?
    var eventEnd: Date?
    var eventIsAllDay: Bool = false

    init(kind: NoteBlockKind, text: String = "") {
        self.kindRaw = kind.rawValue
        self.text = text
    }

    /// A task block whose task was deleted reads as a checklist item.
    var kind: NoteBlockKind {
        get {
            let stored = NoteBlockKind(rawValue: kindRaw) ?? .text
            return stored == .task && task == nil ? .checklist : stored
        }
        set { kindRaw = newValue.rawValue }
    }

    /// Copies the linked task's title and state, so they survive if the task is deleted.
    func syncTaskSnapshot() {
        guard let task else { return }
        if text != task.title { text = task.title }
        if isChecked != task.isDone { isChecked = task.isDone }
    }

    /// Updates the snapshot from freshly loaded events. Returns `false` when the event is gone.
    @discardableResult
    func refreshEvent(from entries: [CalendarEntry]) -> Bool {
        guard let entry = entries.first(where: { $0.id == eventID }) else { return false }
        text = entry.title
        eventStart = entry.start
        eventEnd = entry.end
        eventIsAllDay = entry.isAllDay
        return true
    }
}
