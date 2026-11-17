import Foundation
import SwiftData

enum TagColor: String, CaseIterable, Codable, Identifiable {
    case blue, green, orange, pink, purple, red, teal, yellow, gray

    var id: Self { self }

    /// Picks the next palette color so new tags don't all look the same.
    static func next(after count: Int) -> TagColor {
        allCases[count % allCases.count]
    }
}

@Model
final class Tag {
    var name: String = ""
    var colorRaw: String = TagColor.blue.rawValue
    var createdAt: Date = Date.now

    var tasks: [TaskItem]? = []

    init(name: String, color: TagColor) {
        self.name = name
        self.colorRaw = color.rawValue
    }

    var color: TagColor {
        get { TagColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }
}
