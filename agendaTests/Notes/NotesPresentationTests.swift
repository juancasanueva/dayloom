import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Notes presentation")
struct NotesPresentationTests {
    // MARK: Page subtitle

    @Test func noNotesInvitesTheFirstOne() {
        #expect(NotesHeading.subtitle(for: []) == "No notes yet")
    }

    @Test func countsNotesInTheSingular() throws {
        let context = try makeInMemoryContext()
        let note = Note(title: "Plan")
        context.insert(note)

        #expect(NotesHeading.subtitle(for: [note]) == "1 note")
    }

    @Test func countsNotesAndPinnedOnes() throws {
        let context = try makeInMemoryContext()
        let notes = ["Plan", "Ideas", "Trip"].map { Note(title: $0) }
        for note in notes { context.insert(note) }
        notes[0].isPinned = true
        notes[2].isPinned = true

        #expect(NotesHeading.subtitle(for: notes) == "3 notes · 2 pinned")
    }

    // MARK: Card preview

    @Test func previewIsTheFirstLineOfATitledNote() throws {
        let context = try makeInMemoryContext()
        let note = Note(title: "Plan")
        context.insert(note)
        note.appendBlock(.text, text: "Book the venue")
        note.appendBlock(.text, text: "Send invites")

        #expect(NotePreview.line(for: note) == "Book the venue")
    }

    @Test func previewSkipsTheLineUsedAsTitle() throws {
        let context = try makeInMemoryContext()
        let note = Note(title: "")
        context.insert(note)
        note.appendBlock(.text, text: "Groceries")
        note.appendBlock(.bullet, text: "Milk")

        #expect(note.displayTitle == "Groceries")
        #expect(NotePreview.line(for: note) == "Milk")
    }

    @Test func previewIsEmptyWithoutText() throws {
        let context = try makeInMemoryContext()
        let note = Note(title: "Empty")
        context.insert(note)
        note.appendBlock(.text)

        #expect(NotePreview.line(for: note) == "")
    }
}
