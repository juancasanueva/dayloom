import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Notes linked to a task")
struct TaskNoteLinksTests {
    let editor = NoteEditor(now: TestClock.now, calendar: TestClock.calendar)

    private func makeNote(_ title: String, updatedAt: Date = TestClock.now, in context: ModelContext) -> Note {
        let note = Note(title: title, createdAt: updatedAt)
        context.insert(note)
        return note
    }

    private func makeTask(_ title: String = "Write report", in context: ModelContext) -> TaskItem {
        let task = TaskItem(title: title)
        context.insert(task)
        return task
    }

    /// Adds a task block for `task` to `note`, as the `/existing task` command does.
    @discardableResult
    private func addTaskBlock(_ task: TaskItem, to note: Note) -> NoteBlock {
        let block = note.appendBlock(.text)
        editor.linkTask(task, to: block)
        return block
    }

    // MARK: Linking by hand (S1)

    @Test func linkingANoteListsItOnTheTask() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Research", in: context)

        task.link(note)
        try context.save()

        #expect(task.relatedNotes.map(\.note) == [note])
        #expect(task.relatedNotes.first?.isLinked == true)
        #expect(task.relatedNotes.first?.containsTask == false)
        #expect(note.linkedTasks?.contains { $0 === task } == true)
    }

    @Test func aNoteIsLinkedAtMostOnce() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Research", in: context)

        task.link(note)
        task.link(note)
        try context.save()

        #expect(task.linkedNotes?.count == 1)
        #expect(task.relatedNotes.count == 1)
    }

    @Test func severalNotesAreListedMostRecentlyEditedFirst() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let older = makeNote("Older", updatedAt: TestClock.date(2026, 11, 10), in: context)
        let newer = makeNote("Newer", updatedAt: TestClock.date(2026, 11, 16), in: context)

        task.link(older)
        task.link(newer)
        try context.save()

        #expect(task.relatedNotes.map(\.note) == [newer, older])
    }

    @Test func unlinkingRemovesOnlyThatNote() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let kept = makeNote("Kept", in: context)
        let dropped = makeNote("Dropped", in: context)
        task.link(kept)
        task.link(dropped)

        task.unlink(dropped)
        try context.save()

        #expect(task.relatedNotes.map(\.note) == [kept])
        #expect(dropped.linkedTasks?.isEmpty == true)
        #expect(try context.fetch(FetchDescriptor<Note>()).count == 2)
    }

    @Test func deletingALinkedNoteKeepsTheTask() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Research", in: context)
        task.link(note)
        try context.save()

        context.delete(note)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(task.relatedNotes.isEmpty)
    }

    @Test func deletingATaskKeepsItsLinkedNotes() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Research", in: context)
        task.link(note)
        try context.save()

        context.delete(task)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Note>()).count == 1)
        #expect(note.linkedTasks?.isEmpty == true)
    }

    // MARK: Notes that contain the task (S3)

    @Test func aNoteHoldingTheTaskIsListedWithoutLinkingIt() throws {
        let context = try makeInMemoryContext()
        let note = makeNote("Standup", in: context)
        let block = note.appendBlock(.checklist, text: "Write report")
        let task = editor.convertToTask(block, in: context)
        try context.save()

        #expect(task.relatedNotes.map(\.note) == [note])
        #expect(task.relatedNotes.first?.isLinked == false)
        #expect(task.relatedNotes.first?.containsTask == true)
        #expect(task.linkedNotes?.isEmpty == true)
    }

    @Test func aNoteHoldingTheTaskTwiceIsListedOnce() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Standup", in: context)
        addTaskBlock(task, to: note)
        addTaskBlock(task, to: note)
        try context.save()

        #expect(task.relatedNotes.map(\.note) == [note])
    }

    @Test func aNoteBothLinkedAndHoldingTheTaskIsListedOnce() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Standup", in: context)
        addTaskBlock(task, to: note)
        task.link(note)
        try context.save()

        let related = try #require(task.relatedNotes.first)
        #expect(task.relatedNotes.count == 1)
        #expect(related.isLinked)
        #expect(related.containsTask)
    }

    @Test func unlinkingANoteThatHoldsTheTaskKeepsItListed() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Standup", in: context)
        addTaskBlock(task, to: note)
        task.link(note)

        task.unlink(note)
        try context.save()

        #expect(task.relatedNotes.map(\.note) == [note])
        #expect(task.relatedNotes.first?.isLinked == false)
    }

    @Test func removingTheTaskBlockDropsTheNote() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let note = makeNote("Standup", in: context)
        let block = addTaskBlock(task, to: note)
        try context.save()

        editor.delete(block)
        try context.save()

        #expect(task.relatedNotes.isEmpty)
    }

    // MARK: Picking a note to link (S1)

    @Test func thePickerOffersOnlyNotesNotListedYet() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let linked = makeNote("Linked", in: context)
        let holding = makeNote("Holding", in: context)
        let free = makeNote("Free", in: context)
        task.link(linked)
        addTaskBlock(task, to: holding)
        try context.save()

        let offered = task.linkableNotes(from: [linked, holding, free], matching: "")

        #expect(offered == [free])
    }

    @Test func thePickerSearchesTitlesAndText() throws {
        let context = try makeInMemoryContext()
        let task = makeTask(in: context)
        let byTitle = makeNote("Budget plan", in: context)
        let byText = makeNote("Monday", updatedAt: TestClock.date(2026, 11, 16), in: context)
        byText.appendBlock(.text, text: "Review the budget")
        let other = makeNote("Groceries", in: context)
        try context.save()

        let offered = task.linkableNotes(from: [byTitle, byText, other], matching: "budget")

        #expect(offered == [byTitle, byText])
    }
}
