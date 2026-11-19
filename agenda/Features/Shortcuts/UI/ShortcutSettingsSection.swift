import AppKit
import SwiftUI

/// The Shortcuts tab: every shortcut and what it does, and the keys.toml file that changes them.
struct ShortcutSettingsSection: View {
    private var store = ShortcutStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(ShortcutGroup.allCases) { group in
                PanelSection(verbatim: group.title) {
                    ForEach(ShortcutAction.allCases.filter { $0.group == group }) { action in
                        ShortcutRow(action: action, shortcut: store.shortcut(for: action))
                    }
                }
            }
            fileSection
        }
    }

    private var fileSection: some View {
        PanelSection("Change Shortcuts") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Edit keys.toml and save it; Dayloom applies the changes right away. Delete a line to go back to its default.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.fileURL.path(percentEncoded: false))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Button("Open keys.toml", action: openFile)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                    }
                }
                .controlSize(.small)

                if let problem = store.problem {
                    issue(problem)
                }
                if let problem = store.systemWideProblem {
                    issue(problem)
                }
                ForEach(store.config.issues, id: \.self) { issue in
                    self.issue(issue.message)
                }
            }
        }
    }

    private func issue(_ message: String) -> some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .font(.callout)
    }

    /// Opens the file in the app set for .toml files, or in TextEdit when there's none.
    private func openFile() {
        let workspace = NSWorkspace.shared
        if workspace.urlForApplication(toOpen: store.fileURL) != nil {
            workspace.open(store.fileURL)
        } else if let textEdit = workspace.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
            workspace.open([store.fileURL], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

/// One action, what it does, and its keys; a changed shortcut also shows its default.
private struct ShortcutRow: View {
    let action: ShortcutAction
    let shortcut: Shortcut

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(action.summary)
                if action.isSystemWide {
                    Text("Works in every app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if shortcut != action.defaultShortcut {
                Text("Default \(action.defaultShortcut.displayText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            KeyCaps(shortcut: shortcut)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.summary), \(shortcut.displayText)")
    }
}

/// The shortcut's keys, each on a small key cap, as in ⌃ ⌥ Space.
private struct KeyCaps: View {
    let shortcut: Shortcut

    private var caps: [String] {
        var caps: [String] = []
        if shortcut.modifiers.contains(.control) { caps.append("⌃") }
        if shortcut.modifiers.contains(.option) { caps.append("⌥") }
        if shortcut.modifiers.contains(.shift) { caps.append("⇧") }
        if shortcut.modifiers.contains(.command) { caps.append("⌘") }
        return caps + [shortcut.key.symbol]
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(caps.enumerated()), id: \.offset) { _, cap in
                Text(cap)
                    .font(.callout.weight(.medium).monospaced())
                    .frame(minWidth: 22)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.hairline)
                    }
            }
        }
    }
}
