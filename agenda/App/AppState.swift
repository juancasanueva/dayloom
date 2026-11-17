import Foundation
import Observation
import SwiftData

enum SidebarSelection: Hashable {
    case calendar
    case habits
    case tasks(TaskScope)
}

/// Window-level navigation state shared by the sidebar, lists, calendar, and menu commands.
@Observable
final class AppState {
    var selection: SidebarSelection? = .tasks(.today)
    private(set) var selectedTaskID: PersistentIdentifier?
    var isInspectorPresented = false
    var isLauncherPresented = false
    /// Set by the "New Task" command; the visible task list consumes it by focusing quick add.
    var pendingQuickAdd = false

    func select(task id: PersistentIdentifier?) {
        selectedTaskID = id
        isInspectorPresented = id != nil
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
