import Foundation

/// Block types offered after typing `/` in an empty block.
enum SlashCommand: CaseIterable, Identifiable {
    case text
    case heading
    case bullet
    case checklist
    case divider
    case task
    case existingTask
    case event
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .text: String(appLocalized: "Text")
        case .heading: String(appLocalized: "Heading")
        case .bullet: String(appLocalized: "Bulleted List")
        case .checklist: String(appLocalized: "Checklist")
        case .divider: String(appLocalized: "Divider")
        case .task: String(appLocalized: "Task")
        case .existingTask: String(appLocalized: "Existing Task")
        case .event: String(appLocalized: "Calendar Event")
        case .image: String(appLocalized: "Image")
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .heading: "textformat.size"
        case .bullet: "list.bullet"
        case .checklist: "checklist"
        case .divider: "minus"
        case .task: "checkmark.circle"
        case .existingTask: "link"
        case .event: "calendar"
        case .image: "photo"
        }
    }

    var kind: NoteBlockKind {
        switch self {
        case .text: .text
        case .heading: .heading
        case .bullet: .bullet
        case .checklist: .checklist
        case .divider: .divider
        case .task, .existingTask: .task
        case .event: .event
        case .image: .image
        }
    }

    private var keywords: [String] {
        switch self {
        case .text: ["text", "paragraph"]
        case .heading: ["heading", "title"]
        case .bullet: ["bulleted", "bullet", "list"]
        case .checklist: ["checklist", "checkbox", "list", "todo"]
        case .divider: ["divider", "line", "separator"]
        case .task: ["task"]
        case .existingTask: ["task", "existing", "link"]
        case .event: ["event", "calendar", "meeting"]
        case .image: ["image", "picture", "photo"]
        }
    }

    /// Commands with a keyword starting with `query`, in menu order. An empty query lists all of them.
    static func matching(_ query: String) -> [SlashCommand] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allCases }
        return allCases.filter { command in command.keywords.contains { $0.hasPrefix(query) } }
    }

    /// The word typed after `/` when the block holds only a slash command, otherwise `nil`.
    static func query(in text: String) -> String? {
        guard text.hasPrefix("/") else { return nil }
        let rest = text.dropFirst()
        guard !rest.contains(where: \.isWhitespace) else { return nil }
        return String(rest)
    }
}
