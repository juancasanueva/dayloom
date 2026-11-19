import Foundation
import SwiftData

/// Where the caret goes after an edit: a block and a character offset in its text.
struct NoteFocus: Equatable {
    let block: NoteBlock
    let caret: Int

    static func == (lhs: NoteFocus, rhs: NoteFocus) -> Bool {
        lhs.block === rhs.block && lhs.caret == rhs.caret
    }
}

/// Editing rules for notes. Every change marks the note as updated at `now`.
struct NoteEditor {
    var now: Date = .now
    var calendar: Calendar = .current

    // MARK: Notes

    func newNote(in context: ModelContext) -> Note {
        let note = Note(title: "", createdAt: now)
        context.insert(note)
        note.appendBlock(.text)
        return note
    }

    /// Finds or creates the note for the day containing `date`. With duplicates, the oldest wins.
    func dailyNote(for date: Date, in context: ModelContext, locale: Locale = .app) -> Note {
        let start = calendar.startOfDay(for: date)
        let day: Date? = start
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.dailyDate == day },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let note = newNote(in: context)
        note.dailyDate = start
        note.title = Self.dailyTitle(for: start, calendar: calendar, locale: locale)
        return note
    }

    static func dailyTitle(for day: Date, calendar: Calendar, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    // MARK: Typing

    private static let shortcuts: [(prefix: String, kind: NoteBlockKind, checked: Bool)] = [
        ("# ", .heading, false),
        ("- ", .bullet, false),
        ("* ", .bullet, false),
        ("[] ", .checklist, false),
        ("[ ] ", .checklist, false),
        ("[x] ", .checklist, true),
        ("[X] ", .checklist, true),
    ]

    /// Converts a text block whose text starts with a markdown marker. Returns `nil` when nothing matched.
    @discardableResult
    func applyShortcut(to block: NoteBlock) -> NoteFocus? {
        guard block.kind == .text else { return nil }
        if block.text == "---" {
            block.text = ""
            return makeDivider(block)
        }
        guard let rule = Self.shortcuts.first(where: { block.text.hasPrefix($0.prefix) }) else { return nil }
        block.text = String(block.text.dropFirst(rule.prefix.count))
        block.kind = rule.kind
        block.isChecked = rule.checked
        touch(block)
        return NoteFocus(block: block, caret: 0)
    }

    /// Return: splits the block at `caret`, ends an empty list, or adds text below a non-text block.
    @discardableResult
    func split(_ block: NoteBlock, at caret: Int) -> NoteFocus {
        defer { touch(block) }
        let kind = block.kind
        if kind.continuesOnReturn && block.text.isEmpty {
            block.kind = .text
            block.isChecked = false
            return NoteFocus(block: block, caret: 0)
        }
        guard kind.isTextLike, let note = block.note else {
            return NoteFocus(block: insertBelow(block, kind: .text), caret: 0)
        }
        let offset = min(max(caret, 0), block.text.count)
        let index = block.text.index(block.text.startIndex, offsetBy: offset)
        let tail = String(block.text[index...])
        block.text = String(block.text[..<index])
        let added = note.insertBlock(kind.continuesOnReturn ? kind : .text, text: tail, after: block)
        return NoteFocus(block: added, caret: 0)
    }

    /// Backspace with the caret at offset 0. Returns `nil` when nothing changed.
    @discardableResult
    func backspaceAtStart(_ block: NoteBlock) -> NoteFocus? {
        switch block.kind {
        case .heading, .bullet, .checklist:
            block.kind = .text
            block.isChecked = false
            touch(block)
            return NoteFocus(block: block, caret: 0)
        case .text:
            break
        case .divider, .task, .event, .image:
            return nil
        }

        guard let previous = neighbor(of: block, offset: -1) else { return nil }
        touch(block)
        switch previous.kind {
        case .text, .heading, .bullet, .checklist:
            let caret = previous.text.count
            previous.text += block.text
            delete(block)
            return NoteFocus(block: previous, caret: caret)
        case .divider:
            delete(previous)
            return NoteFocus(block: block, caret: 0)
        case .task, .event, .image:
            guard block.text.isEmpty else { return nil }
            delete(block)
            return NoteFocus(block: previous, caret: previous.text.count)
        }
    }

    /// Swaps the block with the one `offset` positions away (±1). Does nothing at the edges.
    func move(_ block: NoteBlock, by offset: Int) {
        guard let other = neighbor(of: block, offset: offset) else { return }
        swap(&block.sortIndex, &other.sortIndex)
        touch(block)
    }

    func delete(_ block: NoteBlock) {
        touch(block)
        block.note?.blocks?.removeAll { $0 === block }
        block.modelContext?.delete(block)
    }

    // MARK: Commands

    /// Applies a slash command, clearing the typed `/word`.
    /// `.event`, `.existingTask` and `.image` only clear the text: the caller picks the event,
    /// task or picture and calls `setEvent`, `linkTask` or `insertImage`.
    @discardableResult
    func apply(_ command: SlashCommand, to block: NoteBlock, in context: ModelContext) -> NoteFocus {
        block.text = ""
        block.isChecked = false
        touch(block)
        switch command {
        case .text, .heading, .bullet, .checklist:
            block.kind = command.kind
        case .divider:
            return makeDivider(block)
        case .task:
            convertToTask(block, in: context)
        case .event, .existingTask, .image:
            break
        }
        return NoteFocus(block: block, caret: 0)
    }

    /// Turns the block into a linked task. A daily note's tasks are due that day; others go to the Inbox.
    @discardableResult
    func convertToTask(_ block: NoteBlock, in context: ModelContext) -> TaskItem {
        let title = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = TaskItem(title: title, dueDate: block.note?.dailyDate, createdAt: now)
        context.insert(task)
        if block.isChecked {
            task.setCompleted(true, at: now, calendar: calendar)
        }
        block.task = task
        block.kind = .task
        block.text = title
        touch(block)
        return task
    }

    /// Shows an existing task in the block. The task itself is left unchanged.
    func linkTask(_ task: TaskItem, to block: NoteBlock) {
        block.task = task
        block.kind = .task
        block.syncTaskSnapshot()
        touch(block)
    }

    /// Puts an image in an empty text block, or below `block` otherwise, then adds text below
    /// the image and returns its focus, so several images stack in order.
    @discardableResult
    func insertImage(_ data: Data, at block: NoteBlock) -> NoteFocus {
        let target: NoteBlock
        if block.kind == .text, block.text.isEmpty {
            target = block
            target.kind = .image
        } else {
            target = insertBelow(block, kind: .image)
        }
        target.imageData = data
        touch(target)
        return NoteFocus(block: insertBelow(target, kind: .text), caret: 0)
    }

    func setEvent(_ entry: CalendarEntry, on block: NoteBlock) {
        block.kind = .event
        block.eventID = entry.id
        block.text = entry.title
        block.eventStart = entry.start
        block.eventEnd = entry.end
        block.eventIsAllDay = entry.isAllDay
        touch(block)
    }

    // MARK: Helpers

    private func makeDivider(_ block: NoteBlock) -> NoteFocus {
        block.kind = .divider
        touch(block)
        return NoteFocus(block: insertBelow(block, kind: .text), caret: 0)
    }

    private func insertBelow(_ block: NoteBlock, kind: NoteBlockKind) -> NoteBlock {
        guard let note = block.note else { return block }
        return note.insertBlock(kind, after: block)
    }

    private func neighbor(of block: NoteBlock, offset: Int) -> NoteBlock? {
        guard let ordered = block.note?.orderedBlocks,
              let index = ordered.firstIndex(where: { $0 === block }),
              ordered.indices.contains(index + offset) else { return nil }
        return ordered[index + offset]
    }

    private func touch(_ block: NoteBlock) {
        block.note?.updatedAt = now
    }
}
