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

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Text"
        case .heading: "Heading"
        case .bullet: "Bulleted List"
        case .checklist: "Checklist"
        case .divider: "Divider"
        case .task: "Task"
        case .existingTask: "Existing Task"
        case .event: "Calendar Event"
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
