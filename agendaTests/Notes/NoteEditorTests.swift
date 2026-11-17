import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Note editing")
struct NoteEditorTests {
    let editor = NoteEditor(now: TestClock.now, calendar: TestClock.calendar)

    private func makeNote(_ blocks: [(NoteBlockKind, String)], in context: ModelContext) -> Note {
        let note = Note(title: "Plan", createdAt: TestClock.date(2026, 11, 1))
        context.insert(note)
        for (kind, text) in blocks {
            note.appendBlock(kind, text: text)
        }
        return note
    }

    // MARK: Markdown shortcuts (S1.3)

    @Test(arguments: [
        ("# Title", NoteBlockKind.heading, "Title", false),
        ("- item", .bullet, "item", false),
        ("* item", .bullet, "item", false),
        ("[] buy milk", .checklist, "buy milk", false),
        ("[ ] buy milk", .checklist, "buy milk", false),
        ("[x] done", .checklist, "done", true),
    ])
    func markdownShortcutConvertsTextBlock(typed: String, kind: NoteBlockKind, text: String, checked: Bool) throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "")], in: context)
        let block = note.orderedBlocks[0]
        block.text = typed

        let focus = editor.applyShortcut(to: block)

        #expect(focus?.block === block)
        #expect(focus?.caret == 0)
        #expect(block.kind == kind)
        #expect(block.text == text)
        #expect(block.isChecked == checked)
    }

    @Test func dashesBecomeDividerFollowedByEmptyText() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "")], in: context)
        let block = note.orderedBlocks[0]
        block.text = "---"

        let focus = editor.applyShortcut(to: block)

        #expect(note.orderedBlocks.map(\.kind) == [.divider, .text])
        #expect(block.text == "")
        #expect(focus?.block === note.orderedBlocks[1])
    }

    @Test func shortcutsOnlyApplyToTextBlocks() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.heading, "")], in: context)
        let block = note.orderedBlocks[0]
        block.text = "- not a bullet"

        #expect(editor.applyShortcut(to: block) == nil)
        #expect(block.kind == .heading)
        #expect(block.text == "- not a bullet")
    }

    @Test func plainTextIsNotAShortcut() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "")], in: context)
        let block = note.orderedBlocks[0]
        block.text = "#hashtag and -dash"

        #expect(editor.applyShortcut(to: block) == nil)
        #expect(block.kind == .text)
    }

    // MARK: Return (S1.4)

    @Test func returnSplitsAtCaret() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "Hello world")], in: context)
        let block = note.orderedBlocks[0]

        let focus = editor.split(block, at: 5)

        #expect(note.orderedBlocks.map(\.text) == ["Hello", " world"])
        #expect(focus.block === note.orderedBlocks[1])
        #expect(focus.caret == 0)
    }

    @Test func returnInMiddleOfNoteInsertsDirectlyBelow() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "a"), (.text, "c")], in: context)

        editor.split(note.orderedBlocks[0], at: 1).block.text = "b"

        #expect(note.orderedBlocks.map(\.text) == ["a", "b", "c"])
    }

    @Test(arguments: [NoteBlockKind.bullet, .checklist])
    func returnContinuesLists(kind: NoteBlockKind) throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(kind, "one")], in: context)
        note.orderedBlocks[0].isChecked = true

        let focus = editor.split(note.orderedBlocks[0], at: 3)

        #expect(focus.block.kind == kind)
        #expect(focus.block.isChecked == false)
    }

    @Test func returnAfterHeadingStartsText() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.heading, "Goals")], in: context)

        let focus = editor.split(note.orderedBlocks[0], at: 5)

        #expect(focus.block.kind == .text)
        #expect(note.orderedBlocks[0].kind == .heading)
    }

    @Test(arguments: [NoteBlockKind.bullet, .checklist])
    func returnInEmptyListItemEndsTheList(kind: NoteBlockKind) throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(kind, "")], in: context)
        let block = note.orderedBlocks[0]

        let focus = editor.split(block, at: 0)

        #expect(note.orderedBlocks.count == 1)
        #expect(block.kind == .text)
        #expect(focus.block === block)
    }

    @Test(arguments: [NoteBlockKind.divider, .event])
    func returnOnNonTextBlockAddsTextBelow(kind: NoteBlockKind) throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(kind, "keep")], in: context)

        let focus = editor.split(note.orderedBlocks[0], at: 2)

        #expect(note.orderedBlocks.map(\.kind) == [kind, .text])
        #expect(note.orderedBlocks[0].text == "keep")
        #expect(focus.block.text == "")
    }

    // MARK: Backspace at start (S1.4)

    @Test(arguments: [NoteBlockKind.heading, .bullet, .checklist])
    func backspaceTurnsFormattedBlockIntoText(kind: NoteBlockKind) throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "above"), (kind, "item")], in: context)
        let block = note.orderedBlocks[1]

        let focus = editor.backspaceAtStart(block)

        #expect(block.kind == .text)
        #expect(block.text == "item")
        #expect(note.orderedBlocks.count == 2)
        #expect(focus?.block === block)
        #expect(focus?.caret == 0)
    }

    @Test func backspaceMergesTextIntoPreviousBlock() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.bullet, "Hello"), (.text, " world")], in: context)
        let previous = note.orderedBlocks[0]

        let focus = editor.backspaceAtStart(note.orderedBlocks[1])

        #expect(note.orderedBlocks.count == 1)
        #expect(previous.text == "Hello world")
        #expect(previous.kind == .bullet)
        #expect(focus?.block === previous)
        #expect(focus?.caret == 5)
    }

    @Test func backspaceAfterDividerRemovesTheDivider() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "a"), (.divider, ""), (.text, "b")], in: context)
        let block = note.orderedBlocks[2]

        let focus = editor.backspaceAtStart(block)

        #expect(note.orderedBlocks.map(\.kind) == [.text, .text])
        #expect(note.orderedBlocks.map(\.text) == ["a", "b"])
        #expect(focus?.block === block)
    }

    @Test func backspaceInEmptyBlockAfterEventRemovesTheEmptyBlock() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.event, "Standup"), (.text, "")], in: context)

        let focus = editor.backspaceAtStart(note.orderedBlocks[1])

        #expect(note.orderedBlocks.map(\.kind) == [.event])
        #expect(focus?.block === note.orderedBlocks[0])
    }

    @Test func backspaceInFirstTextBlockDoesNothing() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "only")], in: context)

        #expect(editor.backspaceAtStart(note.orderedBlocks[0]) == nil)
        #expect(note.orderedBlocks.map(\.text) == ["only"])
    }

    // MARK: Moving (S1.4)

    @Test func moveSwapsWithNeighbor() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "a"), (.text, "b"), (.text, "c")], in: context)

        editor.move(note.orderedBlocks[2], by: -1)
        #expect(note.orderedBlocks.map(\.text) == ["a", "c", "b"])

        editor.move(note.orderedBlocks[0], by: 1)
        #expect(note.orderedBlocks.map(\.text) == ["c", "a", "b"])
    }

    @Test func moveStopsAtEdges() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "a"), (.text, "b")], in: context)

        editor.move(note.orderedBlocks[0], by: -1)
        editor.move(note.orderedBlocks[1], by: 1)

        #expect(note.orderedBlocks.map(\.text) == ["a", "b"])
    }

    // MARK: Slash commands (S1.4)

    @Test func slashListsEveryCommand() {
        #expect(SlashCommand.matching("") == SlashCommand.allCases)
    }

    @Test func slashFiltersByTypedWord() {
        #expect(SlashCommand.matching("che") == [.checklist])
        #expect(SlashCommand.matching("TA") == [.task])
        #expect(SlashCommand.matching("list") == [.bullet, .checklist])
        #expect(SlashCommand.matching("zzz").isEmpty)
    }

    @Test func slashQueryOnlyInSlashOnlyBlock() {
        #expect(SlashCommand.query(in: "/hea") == "hea")
        #expect(SlashCommand.query(in: "/") == "")
        #expect(SlashCommand.query(in: "a/b") == nil)
        #expect(SlashCommand.query(in: "/two words") == nil)
    }

    @Test func applyingCommandClearsSlashText() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "/hea")], in: context)
        let block = note.orderedBlocks[0]

        let focus = editor.apply(.heading, to: block, in: context)

        #expect(block.kind == .heading)
        #expect(block.text == "")
        #expect(focus.block === block)
    }

    @Test func dividerCommandAddsTextBelow() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "/div")], in: context)

        let focus = editor.apply(.divider, to: note.orderedBlocks[0], in: context)

        #expect(note.orderedBlocks.map(\.kind) == [.divider, .text])
        #expect(focus.block === note.orderedBlocks[1])
    }

    // MARK: Tasks (S1.5)

    @Test func convertingChecklistCreatesInboxTask() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.checklist, "  Call the bank ")], in: context)
        let block = note.orderedBlocks[0]

        let task = editor.convertToTask(block, in: context)

        let stored = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(stored.count == 1)
        #expect(task.title == "Call the bank")
        #expect(task.dueDate == nil)
        #expect(task.createdAt == TestClock.now)
        #expect(block.kind == .task)
        #expect(block.task === task)
        #expect(TaskQuery(now: TestClock.now, calendar: TestClock.calendar).tasks(from: stored, in: .inbox).count == 1)
    }

    @Test func convertingCheckedItemCreatesDoneTask() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.checklist, "Paid")], in: context)
        note.orderedBlocks[0].isChecked = true

        let task = editor.convertToTask(note.orderedBlocks[0], in: context)

        #expect(task.isDone)
        #expect(task.completedAt == TestClock.now)
    }

    @Test func taskFromDailyNoteIsDueThatDay() throws {
        let context = try makeInMemoryContext()
        let note = editor.dailyNote(for: TestClock.date(2026, 11, 20, 15), in: context)
        let block = note.orderedBlocks[0]
        block.text = "Pack bags"

        let task = editor.convertToTask(block, in: context)

        #expect(task.dueDate == TestClock.date(2026, 11, 20))
    }

    @Test func taskCommandConvertsBlock() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "/task")], in: context)
        let block = note.orderedBlocks[0]

        editor.apply(.task, to: block, in: context)

        #expect(block.kind == .task)
        #expect(block.task?.title == "")
    }

    @Test func deletedTaskLeavesChecklistWithLastTitle() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.checklist, "Draft")], in: context)
        let block = note.orderedBlocks[0]
        let task = editor.convertToTask(block, in: context)
        task.title = "Final draft"
        block.syncTaskSnapshot()
        try context.save()

        context.delete(task)
        try context.save()

        #expect(block.task == nil)
        #expect(block.kind == .checklist)
        #expect(block.text == "Final draft")
    }

    @Test func deletingBlockKeepsTask() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.checklist, "Keep me")], in: context)
        let block = note.orderedBlocks[0]
        editor.convertToTask(block, in: context)
        try context.save()

        editor.delete(block)
        try context.save()

        #expect(note.orderedBlocks.isEmpty)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).map(\.title) == ["Keep me"])
    }

    // MARK: Events (S1.6)

    @Test func eventBlockKeepsSnapshot() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "")], in: context)
        let block = note.orderedBlocks[0]
        let entry = CalendarEntry(
            id: "event-1", title: "Standup",
            start: TestClock.date(2026, 11, 17, 9), end: TestClock.date(2026, 11, 17, 9, 15),
            isAllDay: false, kind: .event, tint: .accent
        )

        editor.setEvent(entry, on: block)

        #expect(block.kind == .event)
        #expect(block.eventID == "event-1")
        #expect(block.text == "Standup")
        #expect(block.eventStart == entry.start)
        #expect(block.eventEnd == entry.end)
        #expect(block.eventIsAllDay == false)
    }

    @Test func eventRefreshUpdatesOrReportsMissing() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "")], in: context)
        let block = note.orderedBlocks[0]
        var entry = CalendarEntry(
            id: "event-1", title: "Standup",
            start: TestClock.date(2026, 11, 17, 9), end: TestClock.date(2026, 11, 17, 9, 15),
            isAllDay: false, kind: .event, tint: .accent
        )
        editor.setEvent(entry, on: block)

        entry.title = "Daily standup"
        #expect(block.refreshEvent(from: [entry]))
        #expect(block.text == "Daily standup")

        #expect(!block.refreshEvent(from: []))
        #expect(block.text == "Daily standup")
    }

    // MARK: Updated date

    @Test func editsTouchTheNote() throws {
        let context = try makeInMemoryContext()
        let note = makeNote([(.text, "a")], in: context)
        note.updatedAt = TestClock.date(2026, 1, 1)

        editor.split(note.orderedBlocks[0], at: 1)

        #expect(note.updatedAt == TestClock.now)
    }
}
