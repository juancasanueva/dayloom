import Foundation
import Testing
@testable import agenda

@MainActor
@Suite("Shortcuts: keys and keys.toml")
struct ShortcutConfigTests {
    // MARK: Reading keys

    @Test(arguments: [
        ("cmd+n", "⌘N", "cmd+n"),
        ("cmd+shift+n", "⇧⌘N", "cmd+shift+n"),
        ("Command + Shift + N", "⇧⌘N", "cmd+shift+n"),
        ("ctrl+option+space", "⌃⌥Space", "ctrl+option+space"),
        ("alt+cmd+i", "⌥⌘I", "cmd+option+i"),
        ("⌘←", "⌘←", "cmd+left"),
        ("cmd+left", "⌘←", "cmd+left"),
        ("cmd+right", "⌘→", "cmd+right"),
        ("cmd+,", "⌘,", "cmd+,"),
        ("control+return", "⌃↩", "ctrl+return"),
        ("cmd+1", "⌘1", "cmd+1"),
    ])
    func readsKeys(text: String, display: String, normalized: String) throws {
        let shortcut = try #require(Shortcut(parsing: text))
        #expect(shortcut.displayText == display)
        #expect(shortcut.tomlValue == normalized)
    }

    @Test(arguments: ["", "cmd+", "cmd+shift", "cmd+nn", "hyper+n", "cmd+n+m", "cmd++"])
    func rejectsWhatIsNotAShortcut(text: String) {
        #expect(Shortcut(parsing: text) == nil)
    }

    // MARK: Defaults

    @Test func defaultsAreTodaysShortcuts() {
        let expected: [ShortcutAction: String] = [
            .newTask: "⌘N", .newNote: "⇧⌘N", .quickLauncher: "⌘K", .quickLauncherAnywhere: "⌃⌥Space",
            .toggleInspector: "⌥⌘I",
            .goCalendar: "⌘1", .goInbox: "⌘2", .goToday: "⌘3", .goUpcoming: "⌘4",
            .goCompleted: "⌘5", .goHabits: "⌘6", .goNotes: "⌘7",
            .calendarToday: "⌘T", .calendarPrevious: "⌘←", .calendarNext: "⌘→",
            .searchNotes: "⌘F",
        ]
        #expect(Set(ShortcutAction.allCases) == Set(expected.keys))
        for action in ShortcutAction.allCases {
            #expect(action.defaultShortcut.displayText == expected[action], "\(action.rawValue)")
        }
    }

    @Test func onlyTheAnywhereLauncherIsSystemWide() {
        #expect(ShortcutAction.allCases.filter(\.isSystemWide) == [.quickLauncherAnywhere])
    }

    // MARK: The file

    @Test func theFileDayloomWritesListsEveryShortcutAndReadsBackAsTheDefaults() {
        let text = ShortcutConfig.defaultFileText()

        for action in ShortcutAction.allCases {
            #expect(text.contains("\(action.rawValue) = \"\(action.defaultShortcut.tomlValue)\""), "\(action.rawValue)")
            #expect(text.contains(action.summary), "\(action.rawValue) summary")
        }
        let config = ShortcutConfig.parse(text)
        #expect(config.issues.isEmpty)
        for action in ShortcutAction.allCases {
            #expect(config.shortcut(for: action) == action.defaultShortcut)
        }
    }

    @Test func aChangedLineReplacesOnlyThatShortcut() {
        let config = ShortcutConfig.parse("""
        # my shortcuts
        [shortcuts]
        new_task = "cmd+shift+t"   # quicker for me
        calendar_previous = 'cmd+up'
        """)

        #expect(config.issues.isEmpty)
        #expect(config.shortcut(for: .newTask).displayText == "⇧⌘T")
        #expect(config.shortcut(for: .calendarPrevious).displayText == "⌘↑")
        #expect(config.shortcut(for: .newNote) == ShortcutAction.newNote.defaultShortcut)
    }

    @Test func linesItCantUseKeepTheirDefaultAndAreReported() {
        let config = ShortcutConfig.parse("""
        new_task = "cmd+shift+nope"
        new_note = "n"
        go_inbox = "cmd+2
        unknown_action = "cmd+u"
        this is not a setting
        """)

        #expect(config.shortcut(for: .newTask) == ShortcutAction.newTask.defaultShortcut)
        #expect(config.shortcut(for: .newNote) == ShortcutAction.newNote.defaultShortcut)
        #expect(config.shortcut(for: .goInbox) == ShortcutAction.goInbox.defaultShortcut)
        #expect(config.issues.map(\.line) == [1, 2, 3, 4, 5])
        #expect(config.issues[0].message.contains("new_task"))
        #expect(config.issues[1].message.contains("⌘ or ⌃"))
        #expect(config.issues[3].message.contains("unknown_action"))
    }

    @Test func theSystemWideShortcutNeedsAModifier() {
        let bare = ShortcutConfig.parse(#"quick_launcher_anywhere = "space""#)
        #expect(bare.shortcut(for: .quickLauncherAnywhere) == ShortcutAction.quickLauncherAnywhere.defaultShortcut)
        #expect(bare.issues.count == 1)

        let option = ShortcutConfig.parse(#"quick_launcher_anywhere = "option+space""#)
        #expect(option.issues.isEmpty)
        #expect(option.shortcut(for: .quickLauncherAnywhere).displayText == "⌥Space")
    }

    @Test func twoActionsOnTheSameKeysAreReported() {
        let config = ShortcutConfig.parse(#"new_note = "cmd+n""#)

        #expect(config.issues.count == 1)
        #expect(config.issues[0].line == nil)
        #expect(config.issues[0].message.contains("⌘N"))
    }

    @Test func anOtherSectionIsReportedAndItsLinesStillApply() {
        let config = ShortcutConfig.parse("""
        [colors]
        new_task = "cmd+j"
        """)
        #expect(config.issues.map(\.line) == [1])
        #expect(config.issues[0].message.contains("read as shortcuts"))
        #expect(config.shortcut(for: .newTask).displayText == "⌘J")
    }

    @Test func windowsLineEndingsKeepTheRightLineNumbers() {
        let config = ShortcutConfig.parse("# mine\r\n\r\nnew_task = \"n\"\r\n")
        #expect(config.issues.map(\.line) == [3])
    }

    @Test func aByteOrderMarkIsIgnored() {
        let config = ShortcutConfig.parse("\u{FEFF}new_task = \"cmd+j\"\n")
        #expect(config.issues.isEmpty)
        #expect(config.shortcut(for: .newTask).displayText == "⌘J")
    }

    @Test func anActionSetTwiceIsReportedAndTheLastLineWins() {
        let config = ShortcutConfig.parse("""
        new_task = "cmd+j"
        new_task = "cmd+shift+j"
        """)
        #expect(config.issues.map(\.line) == [2])
        #expect(config.issues[0].message.contains("new_task"))
        #expect(config.shortcut(for: .newTask).displayText == "⇧⌘J")
    }
}
