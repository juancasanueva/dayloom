import Foundation

/// Something in keys.toml Dayloom couldn't use. `line` is nil for problems between lines, such as two actions on the same keys.
struct ShortcutIssue: Hashable {
    let line: Int?
    let message: String
}

/// The shortcuts read from keys.toml: the user's changes over the defaults, and what couldn't be used.
struct ShortcutConfig: Equatable {
    private(set) var overrides: [ShortcutAction: Shortcut] = [:]
    private(set) var issues: [ShortcutIssue] = []

    /// Every action at its default.
    static let defaults = ShortcutConfig()

    func shortcut(for action: ShortcutAction) -> Shortcut {
        overrides[action] ?? action.defaultShortcut
    }

    // MARK: Reading

    /// Reads keys.toml: `action = "keys"` lines, `#` comments, and an optional `[shortcuts]` header.
    /// A line that can't be used keeps that action's default and is reported.
    static func parse(_ text: String) -> ShortcutConfig {
        var config = ShortcutConfig()
        var setOnLine: [ShortcutAction: Int] = [:]

        // A byte-order mark would otherwise stick to the first action's name; splitting on any line
        // break (\r\n counts as one) keeps line numbers right for files saved with Windows endings.
        let body = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let lines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        for (index, rawLine) in lines.enumerated() {
            let number = index + 1
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[") {
                if line != "[shortcuts]" {
                    config.issues.append(ShortcutIssue(line: number, message: "Line \(number): \(line) isn't a section Dayloom knows; the lines after it are still read as shortcuts."))
                }
                continue
            }

            guard let equals = line.firstIndex(of: "=") else {
                config.issues.append(malformed(number))
                continue
            }
            let name = line[..<equals].trimmingCharacters(in: .whitespaces)
            let quoted = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, let value = unquote(quoted) else {
                config.issues.append(malformed(number))
                continue
            }
            guard let action = ShortcutAction(rawValue: name) else {
                config.issues.append(ShortcutIssue(line: number, message: "Line \(number): \(name) isn't a Dayloom action."))
                continue
            }
            let keeping = "keeping \(action.defaultShortcut.displayText)"
            guard let shortcut = Shortcut(parsing: value) else {
                config.issues.append(ShortcutIssue(line: number, message: "Line \(number): \"\(value)\" for \(name) isn't a shortcut Dayloom understands; \(keeping)."))
                continue
            }
            if action.isSystemWide {
                guard !shortcut.modifiers.isEmpty, shortcut.modifiers != .shift else {
                    config.issues.append(ShortcutIssue(line: number, message: "Line \(number): \(name) works in every app, so it needs cmd, ctrl or option; \(keeping)."))
                    continue
                }
            } else {
                guard !shortcut.modifiers.isDisjoint(with: [.command, .control]) else {
                    config.issues.append(ShortcutIssue(line: number, message: "Line \(number): \(name) needs ⌘ or ⌃ so it doesn't take over typing; \(keeping)."))
                    continue
                }
            }
            if let earlier = setOnLine[action] {
                config.issues.append(ShortcutIssue(line: number, message: "Line \(number): \(name) is already set on line \(earlier); this line wins."))
            }
            setOnLine[action] = number
            config.overrides[action] = shortcut
        }

        // Two actions on the same keys: only one of them would run.
        let byShortcut = Dictionary(grouping: ShortcutAction.allCases) { config.shortcut(for: $0) }
        for action in ShortcutAction.allCases {
            let shortcut = config.shortcut(for: action)
            guard let sharing = byShortcut[shortcut], sharing.count > 1, sharing.first == action else { continue }
            let names = sharing.map(\.rawValue).joined(separator: " and ")
            config.issues.append(ShortcutIssue(line: nil, message: "\(names) both use \(shortcut.displayText); only one of them will work."))
        }
        return config
    }

    private static func malformed(_ number: Int) -> ShortcutIssue {
        ShortcutIssue(line: number, message: "Line \(number) isn't in the form action = \"keys\".")
    }

    /// Drops a `#` comment that isn't inside quotes.
    private static func stripComment(_ line: String) -> String {
        var quote: Character?
        for index in line.indices {
            let character = line[index]
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "#" {
                return String(line[..<index])
            }
        }
        return line
    }

    /// The text between matching double or single quotes, or nil.
    private static func unquote(_ value: String) -> String? {
        guard value.count >= 2, let first = value.first, first == "\"" || first == "'", value.last == first else { return nil }
        let inner = value.dropFirst().dropLast()
        guard !inner.contains(first) else { return nil }
        return String(inner)
    }

    // MARK: Writing

    /// The keys.toml Dayloom writes the first time: every action at its default, with what it does.
    static func defaultFileText() -> String {
        var lines = [
            "# Dayloom keyboard shortcuts",
            "#",
            "# Change a shortcut by editing its keys and saving this file; Dayloom applies it right away.",
            "# Delete a line to go back to its default.",
            "#",
            "# Modifiers: cmd, shift, option, ctrl. Shortcuts inside Dayloom need cmd or ctrl.",
            "# Keys: a letter, a digit, punctuation such as , . / ; or one of",
            "# left, right, up, down, space, return, escape, tab, delete.",
            "",
            "[shortcuts]",
        ]
        let width = ShortcutAction.allCases.map { "\($0.rawValue) = \"\($0.defaultShortcut.tomlValue)\"".count }.max() ?? 0
        for group in ShortcutGroup.allCases {
            lines.append("")
            lines.append("# \(group.rawValue)")
            for action in ShortcutAction.allCases where action.group == group {
                let setting = "\(action.rawValue) = \"\(action.defaultShortcut.tomlValue)\""
                let padding = String(repeating: " ", count: width - setting.count + 2)
                lines.append(setting + padding + "# " + action.summary)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
