import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Window navigation state")
struct AppStateTests {
    private func selectedTask(in state: AppState) throws -> (AppState, PersistentIdentifier) {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Report")
        context.insert(task)
        try context.save()
        state.select(task: task.persistentModelID)
        return (state, task.persistentModelID)
    }

    @Test(arguments: [SidebarSelection.tasks(.upcoming), .calendar, .habits, .notes])
    func movingToAnotherViewClearsTheSelectedTask(destination: SidebarSelection) throws {
        let state = AppState()
        state.selection = .tasks(.today)
        _ = try selectedTask(in: state)

        state.selection = destination

        #expect(state.selectedTaskID == nil)
        #expect(!state.isInspectorPresented)
    }

    @Test func reselectingTheSameViewKeepsTheSelectedTask() throws {
        let state = AppState()
        state.selection = .tasks(.today)
        let (_, id) = try selectedTask(in: state)

        state.selection = .tasks(.today)

        #expect(state.selectedTaskID == id)
        #expect(state.isInspectorPresented)
    }

    /// A note linked to a task opens in Notes, leaving the task's details behind.
    @Test func openingANoteShowsItInNotes() throws {
        let context = try makeInMemoryContext()
        let note = Note(title: "Research")
        context.insert(note)
        try context.save()
        let state = AppState()
        state.selection = .tasks(.today)
        _ = try selectedTask(in: state)

        state.open(note: note.persistentModelID)

        #expect(state.selection == .notes)
        #expect(state.selectedNoteID == note.persistentModelID)
        #expect(state.selectedTaskID == nil)
        #expect(!state.isInspectorPresented)
    }

    /// The quick launcher opens a task's details without changing the view.
    @Test func selectingATaskWithoutChangingViewShowsIt() throws {
        let state = AppState()
        state.selection = .calendar
        let (_, id) = try selectedTask(in: state)

        #expect(state.selection == .calendar)
        #expect(state.selectedTaskID == id)
        #expect(state.isInspectorPresented)
    }
}
