import Foundation
import Observation
import SwiftData

enum SidebarSelection: Hashable {
    case calendar
    case habits
    case notes
    case tasks(TaskScope)
}

/// Window-level navigation state shared by the sidebar, lists, calendar, and menu commands.
@Observable
final class AppState {
    /// Moving to another view drops the selected task, so its details don't linger next to a list that doesn't show it.
    var selection: SidebarSelection? = .tasks(.today) {
        didSet {
            if selection != oldValue { select(task: nil) }
        }
    }
    private(set) var selectedTaskID: PersistentIdentifier?
    var isInspectorPresented = false
    var isLauncherPresented = false
    /// Set by the "New Task" command; the visible task list consumes it by focusing quick add.
    var pendingQuickAdd = false
    var selectedNoteID: PersistentIdentifier?
    /// Set by the "New Note" command; the notes screen consumes it by creating a note.
    var pendingNewNote = false

    func select(task id: PersistentIdentifier?) {
        selectedTaskID = id
        isInspectorPresented = id != nil
    }

    func requestNewNote() {
        selection = .notes
        pendingNewNote = true
    }

    func requestQuickAdd() {
        switch selection {
        case .tasks(let scope) where scope != .completed:
            break // Add to the list the user is looking at.
        default:
            selection = .tasks(.inbox)
        }
        pendingQuickAdd = true
    }
}
