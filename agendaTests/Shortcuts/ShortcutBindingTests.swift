import Carbon.HIToolbox
import SwiftUI
import Testing
@testable import agenda

@MainActor
@Suite("Shortcuts: menus and the system-wide hotkey")
struct ShortcutBindingTests {
    @Test func menusGetTheSameKeysAsTheShortcut() throws {
        let newNote = try #require(Shortcut(parsing: "cmd+shift+n")).keyboardShortcut
        #expect(newNote.key == KeyEquivalent("n"))
        #expect(newNote.modifiers == [.command, .shift])

        let previous = try #require(Shortcut(parsing: "cmd+left")).keyboardShortcut
        #expect(previous.key == .leftArrow)
        #expect(previous.modifiers == .command)

        let all = try #require(Shortcut(parsing: "ctrl+option+shift+cmd+space")).keyboardShortcut
        #expect(all.key == .space)
        #expect(all.modifiers == [.control, .option, .shift, .command])
    }

    @Test func theDefaultLauncherHotkeyIsControlOptionSpace() {
        let shortcut = ShortcutAction.quickLauncherAnywhere.defaultShortcut
        #expect(shortcut.carbonKeyCode == UInt32(kVK_Space))
        #expect(shortcut.carbonModifiers == UInt32(controlKey | optionKey))
    }

    @Test func everyKeyTheFileAcceptsCanBeASystemWideHotkey() throws {
        let tokens = "abcdefghijklmnopqrstuvwxyz0123456789".map(String.init)
            + ["`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/"]
            + ["left", "right", "up", "down", "space", "return", "escape", "tab", "delete"]
        for token in tokens {
            let shortcut = try #require(Shortcut(parsing: "ctrl+\(token)"), "\(token)")
            #expect(shortcut.carbonKeyCode != nil, "\(token)")
        }
        #expect(try #require(Shortcut(parsing: "cmd+k")).carbonKeyCode == UInt32(kVK_ANSI_K))
        #expect(try #require(Shortcut(parsing: "cmd+left")).carbonKeyCode == UInt32(kVK_LeftArrow))
        #expect(try #require(Shortcut(parsing: "cmd+shift+option+1")).carbonModifiers == UInt32(cmdKey | shiftKey | optionKey))
    }
}
