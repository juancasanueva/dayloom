import Foundation

/// Modifier keys held with a shortcut.
struct ShortcutModifiers: OptionSet, Hashable {
    let rawValue: Int

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let shift = ShortcutModifiers(rawValue: 1 << 1)
    static let option = ShortcutModifiers(rawValue: 1 << 2)
    static let control = ShortcutModifiers(rawValue: 1 << 3)

    /// Reads one modifier name, such as `cmd`, `shift`, `alt` or `⌃`.
    init?(token: String) {
        switch token {
        case "cmd", "command", "⌘": self = .command
        case "shift", "⇧": self = .shift
        case "option", "opt", "alt", "⌥": self = .option
        case "ctrl", "control", "⌃": self = .control
        default: return nil
        }
    }

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// The key pressed with the modifiers.
enum ShortcutKey: Hashable {
    /// A lowercase letter, a digit or punctuation.
    case character(Character)
    case left, right, up, down, space, returnKey, escape, tab, delete

    private static let punctuation: Set<Character> = ["`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/"]

    /// Reads a key, such as `n`, `1`, `,`, `left` or `space`.
    init?(token: String) {
        switch token {
        case "left", "←": self = .left
        case "right", "→": self = .right
        case "up", "↑": self = .up
        case "down", "↓": self = .down
        case "space": self = .space
        case "return", "enter", "↩": self = .returnKey
        case "escape", "esc", "⎋": self = .escape
        case "tab", "⇥": self = .tab
        case "delete", "backspace", "⌫": self = .delete
        default:
            guard token.count == 1, let character = token.first, character.isASCII,
                  character.isLetter || character.isNumber || Self.punctuation.contains(character) else { return nil }
            self = .character(character)
        }
    }

    /// How the key is written in keys.toml.
    var token: String {
        switch self {
        case .character(let character): String(character)
        case .left: "left"
        case .right: "right"
        case .up: "up"
        case .down: "down"
        case .space: "space"
        case .returnKey: "return"
        case .escape: "escape"
        case .tab: "tab"
        case .delete: "delete"
        }
    }

    /// How the key is shown, as on macOS menus.
    var symbol: String {
        switch self {
        case .character(let character): String(character).uppercased()
        case .left: "←"
        case .right: "→"
        case .up: "↑"
        case .down: "↓"
        case .space: String(appLocalized: "Space")
        case .returnKey: "↩"
        case .escape: "⎋"
        case .tab: "⇥"
        case .delete: "⌫"
        }
    }
}

/// A key with its modifiers, such as ⇧⌘N.
struct Shortcut: Hashable {
    let key: ShortcutKey
    let modifiers: ShortcutModifiers

    init(_ key: ShortcutKey, _ modifiers: ShortcutModifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Reads a shortcut as written in keys.toml, such as `cmd+shift+n` or `ctrl+option+space`.
    /// Modifier symbols (`⌘←`) work too. Returns nil for anything that isn't exactly one key with modifiers.
    init?(parsing text: String) {
        var normalized = text.lowercased()
        for (symbol, name) in [("⌘", "cmd+"), ("⇧", "shift+"), ("⌥", "option+"), ("⌃", "ctrl+")] {
            normalized = normalized.replacingOccurrences(of: symbol, with: name)
        }
        let tokens = normalized.split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let last = tokens.last, !last.isEmpty, let key = ShortcutKey(token: last) else { return nil }

        var modifiers: ShortcutModifiers = []
        for token in tokens.dropLast() {
            guard let modifier = ShortcutModifiers(token: token) else { return nil }
            modifiers.insert(modifier)
        }
        self.init(key, modifiers)
    }

    /// As written in keys.toml: modifiers in a fixed order, then the key.
    var tomlValue: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("cmd") }
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("option") }
        if modifiers.contains(.shift) { parts.append("shift") }
        return (parts + [key.token]).joined(separator: "+")
    }

    /// As macOS shows it: ⌃⌥⇧⌘ then the key.
    var displayText: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + key.symbol
    }
}

/// Where an action's shortcut appears in the Shortcuts tab and in keys.toml.
enum ShortcutGroup: String, CaseIterable, Identifiable {
    case general = "General"
    case goTo = "Go To"
    case calendar = "Calendar"
    case notes = "Notes"

    var id: Self { self }

    /// The group's heading in the Shortcuts tab; keys.toml uses the raw value.
    var title: String {
        switch self {
        case .general: String(appLocalized: "General")
        case .goTo: String(appLocalized: "Go To")
        case .calendar: String(appLocalized: "Calendar")
        case .notes: String(appLocalized: "Notes")
        }
    }
}

/// Everything a shortcut can do. The raw value is the action's name in keys.toml.
enum ShortcutAction: String, CaseIterable, Identifiable {
    case newTask = "new_task"
    case newNote = "new_note"
    case quickLauncher = "quick_launcher"
    case quickLauncherAnywhere = "quick_launcher_anywhere"
    case toggleInspector = "toggle_inspector"
    case goCalendar = "go_calendar"
    case goInbox = "go_inbox"
    case goToday = "go_today"
    case goUpcoming = "go_upcoming"
    case goCompleted = "go_completed"
    case goHabits = "go_habits"
    case goNotes = "go_notes"
    case calendarToday = "calendar_today"
    case calendarPrevious = "calendar_previous"
    case calendarNext = "calendar_next"
    case searchNotes = "search_notes"

    var id: Self { self }

    /// What the shortcut does, in a few words, in the app language.
    var summary: String {
        summary(bundle: AppLocalization.shared.bundle)
    }

    /// What the shortcut does, in the language of `bundle`.
    func summary(bundle: Bundle) -> String {
        switch self {
        case .newTask: String(appLocalized: "New task", bundle: bundle)
        case .newNote: String(appLocalized: "New note", bundle: bundle)
        case .quickLauncher: String(appLocalized: "Quick Launcher", bundle: bundle)
        case .quickLauncherAnywhere: String(appLocalized: "Quick Launcher from any app", bundle: bundle)
        case .toggleInspector: String(appLocalized: "Show or hide the inspector", bundle: bundle)
        case .goCalendar: String(appLocalized: "Calendar", bundle: bundle)
        case .goInbox: String(appLocalized: "Inbox", bundle: bundle)
        case .goToday: String(appLocalized: "Today", bundle: bundle)
        case .goUpcoming: String(appLocalized: "Upcoming", bundle: bundle)
        case .goCompleted: String(appLocalized: "Completed", bundle: bundle)
        case .goHabits: String(appLocalized: "Habits", bundle: bundle)
        case .goNotes: String(appLocalized: "Notes", bundle: bundle)
        case .calendarToday: String(appLocalized: "Back to today", bundle: bundle)
        case .calendarPrevious: String(appLocalized: "Previous day, week or month", bundle: bundle)
        case .calendarNext: String(appLocalized: "Next day, week or month", bundle: bundle)
        case .searchNotes: String(appLocalized: "Search notes", bundle: bundle)
        }
    }

    var group: ShortcutGroup {
        switch self {
        case .newTask, .newNote, .quickLauncher, .quickLauncherAnywhere, .toggleInspector: .general
        case .goCalendar, .goInbox, .goToday, .goUpcoming, .goCompleted, .goHabits, .goNotes: .goTo
        case .calendarToday, .calendarPrevious, .calendarNext: .calendar
        case .searchNotes: .notes
        }
    }

    /// Works while another app is in front; every other shortcut works only inside Dayloom.
    var isSystemWide: Bool { self == .quickLauncherAnywhere }

    var defaultShortcut: Shortcut {
        switch self {
        case .newTask: Shortcut(.character("n"), .command)
        case .newNote: Shortcut(.character("n"), [.command, .shift])
        case .quickLauncher: Shortcut(.character("k"), .command)
        case .quickLauncherAnywhere: Shortcut(.space, [.control, .option])
        case .toggleInspector: Shortcut(.character("i"), [.command, .option])
        case .goCalendar: Shortcut(.character("1"), .command)
        case .goInbox: Shortcut(.character("2"), .command)
        case .goToday: Shortcut(.character("3"), .command)
        case .goUpcoming: Shortcut(.character("4"), .command)
        case .goCompleted: Shortcut(.character("5"), .command)
        case .goHabits: Shortcut(.character("6"), .command)
        case .goNotes: Shortcut(.character("7"), .command)
        case .calendarToday: Shortcut(.character("t"), .command)
        case .calendarPrevious: Shortcut(.left, .command)
        case .calendarNext: Shortcut(.right, .command)
        case .searchNotes: Shortcut(.character("f"), .command)
        }
    }
}
