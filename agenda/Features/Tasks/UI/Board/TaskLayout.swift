import Foundation
import Observation

/// How a task list is presented.
enum TaskLayout: String, CaseIterable, Identifiable {
    case list
    case board

    /// The one app-wide choice used before each list had its own; lists without a choice start from it.
    static let storageKey = "taskLayout"

    var id: Self { self }

    var title: String {
        switch self {
        case .list: String(appLocalized: "List")
        case .board: String(appLocalized: "Board")
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        }
    }
}

/// The list or board choice of each task list, remembered across launches. Inbox, Today and
/// Upcoming each have their own; tag lists share one; Completed always shows the list.
@Observable
final class TaskLayoutStore {
    static let shared = TaskLayoutStore()

    @ObservationIgnored private let defaults: UserDefaults
    private var layouts: [String: TaskLayout] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let previous = defaults.string(forKey: TaskLayout.storageKey).flatMap(TaskLayout.init(rawValue:)) ?? .list
        for key in Self.keys {
            layouts[key] = defaults.string(forKey: key).flatMap(TaskLayout.init(rawValue:)) ?? previous
        }
    }

    func layout(for scope: TaskScope) -> TaskLayout {
        guard let key = Self.key(for: scope) else { return .list }
        return layouts[key] ?? .list
    }

    func setLayout(_ layout: TaskLayout, for scope: TaskScope) {
        guard let key = Self.key(for: scope) else { return }
        layouts[key] = layout
        defaults.set(layout.rawValue, forKey: key)
    }

    private static let keys = ["taskLayout.inbox", "taskLayout.today", "taskLayout.upcoming", "taskLayout.tags"]

    private static func key(for scope: TaskScope) -> String? {
        switch scope {
        case .inbox: "taskLayout.inbox"
        case .today: "taskLayout.today"
        case .upcoming: "taskLayout.upcoming"
        case .tag: "taskLayout.tags"
        case .completed: nil
        }
    }
}
