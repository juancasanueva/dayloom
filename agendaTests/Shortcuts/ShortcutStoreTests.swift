import Foundation
import Testing
@testable import agenda

@MainActor
@Suite("Shortcuts: the keys.toml file", .serialized)
struct ShortcutStoreTests {
    /// A dayloom folder whose parent exists, as ~/.config does on most Macs.
    private func makeDirectory() -> URL {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ShortcutStoreTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        return parent.appendingPathComponent("dayloom")
    }

    @Test func createsTheFileWithEveryShortcutWhenItIsMissing() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = ShortcutStore(directory: directory)

        store.load()

        let text = try String(contentsOf: directory.appendingPathComponent("keys.toml"), encoding: .utf8)
        #expect(text == ShortcutConfig.defaultFileText())
        #expect(store.fileURL == directory.appendingPathComponent("keys.toml"))
        #expect(store.config == ShortcutConfig.parse(text))
        #expect(store.problem == nil)
    }

    @Test func neverOverwritesTheUsersFile() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let mine = "new_task = \"cmd+shift+t\"\n"
        try mine.write(to: directory.appendingPathComponent("keys.toml"), atomically: true, encoding: .utf8)
        let store = ShortcutStore(directory: directory)

        store.load()

        #expect(try String(contentsOf: directory.appendingPathComponent("keys.toml"), encoding: .utf8) == mine)
        #expect(store.shortcut(for: .newTask).displayText == "⇧⌘T")
        #expect(store.shortcut(for: .newNote) == ShortcutAction.newNote.defaultShortcut)
    }

    @Test func savingTheFileAppliesTheChange() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = ShortcutStore(directory: directory)
        store.load()
        store.startWatching()
        defer { store.stopWatching() }

        // Rewritten in place, as many editors save.
        let file = directory.appendingPathComponent("keys.toml")
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data("go_inbox = \"cmd+i\"\n".utf8))
        try handle.close()

        for _ in 0..<40 where store.shortcut(for: .goInbox).displayText != "⌘I" {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(store.shortcut(for: .goInbox).displayText == "⌘I")

        // Replaced through a rename, as Vim and other editors save.
        let replacement = directory.appendingPathComponent("keys.toml.tmp")
        try "go_inbox = \"cmd+shift+i\"\n".write(to: replacement, atomically: false, encoding: .utf8)
        _ = try FileManager.default.replaceItemAt(file, withItemAt: replacement)

        for _ in 0..<40 where store.shortcut(for: .goInbox).displayText != "⇧⌘I" {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(store.shortcut(for: .goInbox).displayText == "⇧⌘I")
    }

    @Test func aFileItCantCreateIsReportedAndTheDefaultsApply() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ShortcutStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: parent) }
        // A plain file where the folder should be.
        try Data().write(to: parent)
        let store = ShortcutStore(directory: parent.appendingPathComponent("dayloom"))

        store.load()

        #expect(store.problem != nil)
        #expect(store.config == ShortcutConfig.defaults)
    }

    @Test func aMissingParentFolderIsExplainedInsteadOfCreated() {
        // The sandbox only allows ~/.config/dayloom/, so a missing ~/.config can't be created.
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ShortcutStoreTests-\(UUID().uuidString)")
        let store = ShortcutStore(directory: parent.appendingPathComponent("dayloom"))

        store.load()

        #expect(!FileManager.default.fileExists(atPath: parent.path))
        #expect(store.problem?.contains("mkdir") == true)
        #expect(store.config == ShortcutConfig.defaults)
    }

    @Test func aSystemWideShortcutThatCantBeRegisteredIsReported() {
        let store = ShortcutStore(directory: makeDirectory())

        store.reportSystemWideShortcut(registered: false)
        #expect(store.systemWideProblem?.contains("⌃⌥Space") == true)

        store.reportSystemWideShortcut(registered: true)
        #expect(store.systemWideProblem == nil)
    }

    @Test func theRealFileLivesInConfigDayloomUnderTheUsersHome() {
        let path = ShortcutStore.defaultDirectory.path
        #expect(path.hasSuffix("/.config/dayloom"))
        #expect(!path.contains("/Library/Containers/"))
    }
}
