import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appearsActive) private var appearsActive
    @Query private var allTasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var isAddingTag = false
    @State private var newTagName = ""
    @State private var tagBeingRenamed: Tag?
    @State private var renameText = ""

    var body: some View {
        @Bindable var appState = appState
        let query = TaskQuery()

        List(selection: $appState.selection) {
            Section {
                row("Calendar", systemImage: "calendar", for: .calendar)
                row("Habits", systemImage: "flame", for: .habits)
                row("Notes", systemImage: "note.text", for: .notes)
            }

            Section {
                row("Inbox", systemImage: "tray", for: .tasks(.inbox), count: query.tasks(from: allTasks, in: .inbox).count)
                row("Today", systemImage: "sun.max", for: .tasks(.today), count: query.tasks(from: allTasks, in: .today).count)
                row("Upcoming", systemImage: "calendar.badge.clock", for: .tasks(.upcoming))
                row("Completed", systemImage: "checkmark.circle", for: .tasks(.completed))
            } header: {
                SidebarHeader("Tasks")
            }

            Section {
                ForEach(tags) { tag in
                    row(tag.name, systemImage: "number", for: .tasks(.tag(tag.persistentModelID)), iconColor: tag.color.color)
                        .contextMenu { tagMenu(tag) }
                }
                newTagButton
            } header: {
                SidebarHeader("Tags")
            }
        }
        // The sidebar sits on the same warm canvas as the content panel beside it.
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        // A little air between the window controls and the first row.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 24)
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        .safeAreaInset(edge: .bottom) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(SidebarFooterButtonStyle())
            .focusEffectDisabled()
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Theme.canvas)
        }
        // Sheets, not alerts: alerts keep focus on their buttons, so typing wouldn't reach the name.
        .sheet(isPresented: $isAddingTag) {
            TagNameSheet(title: "New Tag", actionTitle: "Add", name: $newTagName, onSave: addTag)
        }
        .sheet(item: $tagBeingRenamed) { tag in
            TagNameSheet(title: "Rename Tag", actionTitle: "Rename", name: $renameText) { rename(tag) }
        }
    }

    private func row(
        _ title: String, systemImage: String, for selection: SidebarSelection, count: Int = 0, iconColor: Color? = nil
    ) -> some View {
        SidebarRow(title: title, systemImage: systemImage, iconColor: iconColor, count: count, isSelected: appState.selection == selection)
            .tag(selection)
    }

    /// Sits under the tags as an outlined row, so it reads as an action rather than a tag.
    private var newTagButton: some View {
        Button {
            newTagName = ""
            isAddingTag = true
        } label: {
            Label {
                Text("New Tag")
            } icon: {
                // Accent only while the window is active, like the sidebar's other icons.
                Image(systemName: "plus.circle")
                    .foregroundStyle(appearsActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.14))
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func tagMenu(_ tag: Tag) -> some View {
        Button("Rename…") {
            renameText = tag.name
            tagBeingRenamed = tag
        }
        Menu("Color") {
            ForEach(TagColor.allCases) { color in
                Button(color.rawValue.capitalized) { tag.color = color }
            }
        }
        Divider()
        Button("Delete Tag", role: .destructive) { delete(tag) }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = Tag(name: name, color: TagColor.next(after: tags.count))
        modelContext.insert(tag)
        try? modelContext.save() // Swap the temporary ID for a permanent one before selecting it.
        appState.selection = .tasks(.tag(tag.persistentModelID))
    }

    private func rename(_ tag: Tag) {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { tag.name = name }
    }

    private func delete(_ tag: Tag) {
        if appState.selection == .tasks(.tag(tag.persistentModelID)) {
            appState.selection = .tasks(.today)
        }
        modelContext.delete(tag)
    }
}

/// A sidebar row in the theme's accent. The system draws its selection and icons in the
/// System Settings accent whatever the theme, so its highlight is turned off and drawn here.
private struct SidebarRow: View {
    let title: String
    let systemImage: String
    /// The icon's color when the row isn't highlighted; the theme's accent when `nil`.
    let iconColor: Color?
    /// Shown at the trailing edge when above zero, like a badge.
    let count: Int
    let isSelected: Bool

    @Environment(\.appearsActive) private var appearsActive

    /// Like the system's, the highlight turns gray while the window is in the background.
    private var isHighlighted: Bool { isSelected && appearsActive }

    var body: some View {
        HStack(spacing: 6) {
            Label {
                Text(title)
                    .foregroundStyle(isHighlighted ? Theme.onAccent : .primary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(iconStyle)
            }
            Spacer(minLength: 0)
            if count > 0 {
                Text(count, format: .number)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(isHighlighted ? AnyShapeStyle(Theme.onAccent.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
        }
        // The sidebar ignores row backgrounds, so the highlight reaches past the row's insets instead.
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(isSelected ? Theme.hairline : Color.clear))
                .padding(.horizontal, -8)
                .padding(.vertical, -4)
        }
        .background(SystemSelectionHidden())
    }

    private var iconStyle: AnyShapeStyle {
        if isHighlighted { return AnyShapeStyle(Theme.onAccent) }
        guard appearsActive else { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(iconColor ?? Theme.accent)
    }
}

/// Turns off the selection highlight of the table a row sits in, so the row can draw its own.
private struct SystemSelectionHidden: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            var view = superview
            while let current = view, !(current is NSTableView) {
                view = current.superview
            }
            if let table = view as? NSTableView, table.selectionHighlightStyle != .none {
                table.selectionHighlightStyle = .none
            }
        }
    }
}

/// A quiet section heading, softer than the system's.
private struct SidebarHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

/// The pinned Settings row: secondary text, a soft card under the pointer.
private struct SidebarFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isHovered ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    configuration.isPressed ? Theme.hairline : (isHovered ? Theme.cardHover : Color.clear),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onHover { isHovered = $0 }
        }
    }
}

/// Asks for a tag's name, with the cursor already in the field.
private struct TagNameSheet: View {
    let title: String
    let actionTitle: String
    @Binding var name: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            TextField("Name", text: $name, prompt: Text("Name"))
                .labelsHidden()
                .focused($isNameFocused)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(actionTitle, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlank)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { isNameFocused = true }
    }

    private var isBlank: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard !isBlank else { return }
        onSave()
        dismiss()
    }
}
