import Foundation

/// How a task list is presented. Stored app-wide under the `taskLayout` key.
enum TaskLayout: String, CaseIterable, Identifiable {
    case list
    case board

    static let storageKey = "taskLayout"

    var id: Self { self }

    var title: String {
        switch self {
        case .list: "List"
        case .board: "Board"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        }
    }
}
