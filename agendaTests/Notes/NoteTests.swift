import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Notes")
struct NoteTests {
    let editor = NoteEditor(now: TestClock.now, calendar: TestClock.calendar)

    // MARK: New notes (S1.1, S2.3)

    @Test func newNoteStartsWithOneEmptyTextBlock() throws {
        let context = try makeInMemoryContext()

        let note = editor.newNote(in: context)

        #expect(note.title == "")
        #expect(note.createdAt == TestClock.now)
        #expect(note.dailyDate == nil)
        #expect(note.orderedBlocks.map(\.kind) == [.text])
        #expect(note.orderedBlocks.map(\.text) == [""])
    }

    @Test func deletingNoteDeletesBlocks() throws {
        let context = try makeInMemoryContext()
        let note = editor.newNote(in: context)
        note.appendBlock(.text, text: "more")
        try context.save()

        context.delete(note)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<NoteBlock>()).isEmpty)
    }

    // MARK: Daily note (S1.7)

    @Test func dailyNoteIsCreatedOnceAndTitledWithTheDate() throws {
        let context = try makeInMemoryContext()

        let first = editor.dailyNote(for: TestClock.date(2026, 11, 17, 8), in: context, locale: Locale(identifier: "en_US"))
        let second = editor.dailyNote(for: TestClock.date(2026, 11, 17, 22), in: context, locale: Locale(identifier: "en_US"))

        #expect(first === second)
        #expect(first.dailyDate == TestClock.date(2026, 11, 17))
        #expect(first.title == "Tuesday, November 17, 2026")
        #expect(first.orderedBlocks.map(\.kind) == [.text])
        #expect(try context.fetch(FetchDescriptor<Note>()).count == 1)
    }

    @Test func dailyNotePrefersOldestDuplicate() throws {
        let context = try makeInMemoryContext()
        let day = TestClock.date(2026, 11, 17)
        let newer = Note(title: "newer", createdAt: TestClock.date(2026, 11, 17, 9))
        newer.dailyDate = day
        let older = Note(title: "older", createdAt: TestClock.date(2026, 11, 17, 7))
        older.dailyDate = day
        context.insert(newer)
        context.insert(older)

        #expect(editor.dailyNote(for: day, in: context) === older)
    }

    @Test func otherDaysGetTheirOwnNote() throws {
        let context = try makeInMemoryContext()

        let today = editor.dailyNote(for: TestClock.now, in: context)
        let tomorrow = editor.dailyNote(for: TestClock.date(2026, 11, 18), in: context)

        #expect(today !== tomorrow)
    }

    // MARK: List and search (S1.8)

    @Test func listShowsPinnedFirstThenRecentlyUpdated() throws {
        let old = Note(title: "old", createdAt: TestClock.date(2026, 1, 1))
        old.updatedAt = TestClock.date(2026, 1, 1)
        let recent = Note(title: "recent", createdAt: TestClock.date(2026, 1, 1))
        recent.updatedAt = TestClock.date(2026, 11, 1)
        let pinned = Note(title: "pinned", createdAt: TestClock.date(2026, 1, 1))
        pinned.updatedAt = TestClock.date(2025, 1, 1)
        pinned.isPinned = true

        let titles = NoteQuery.notes(from: [old, recent, pinned], matching: "").map(\.title)

        #expect(titles == ["pinned", "recent", "old"])
    }

    @Test func searchMatchesTitleAndBlockText() throws {
        let context = try makeInMemoryContext()
        let trip = Note(title: "Trip to Cádiz")
        let groceries = Note(title: "Groceries")
        let other = Note(title: "Other")
        [trip, groceries, other].forEach(context.insert)
        groceries.appendBlock(.checklist, text: "Café beans")

        #expect(NoteQuery.notes(from: [trip, groceries, other], matching: "cadiz").map(\.title) == ["Trip to Cádiz"])
        #expect(NoteQuery.notes(from: [trip, groceries, other], matching: "CAFE").map(\.title) == ["Groceries"])
        #expect(NoteQuery.notes(from: [trip, groceries, other], matching: "  ").count == 3)
    }

    @Test func untitledNotesShowFirstLine() throws {
        let context = try makeInMemoryContext()
        let note = Note(title: "")
        context.insert(note)
        #expect(note.displayTitle == "Untitled")

        note.appendBlock(.divider, text: "")
        note.appendBlock(.text, text: "First thoughts")
        #expect(note.displayTitle == "First thoughts")
    }
}
