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
                Label("Calendar", systemImage: "calendar")
                    .tag(SidebarSelection.calendar)
                Label("Habits", systemImage: "flame")
                    .tag(SidebarSelection.habits)
                Label("Notes", systemImage: "note.text")
                    .tag(SidebarSelection.notes)
            }

            Section {
                Label("Inbox", systemImage: "tray")
                    .badge(query.tasks(from: allTasks, in: .inbox).count)
                    .tag(SidebarSelection.tasks(.inbox))
                Label("Today", systemImage: "sun.max")
                    .badge(query.tasks(from: allTasks, in: .today).count)
                    .tag(SidebarSelection.tasks(.today))
                Label("Upcoming", systemImage: "calendar.badge.clock")
                    .tag(SidebarSelection.tasks(.upcoming))
                Label("Completed", systemImage: "checkmark.circle")
                    .tag(SidebarSelection.tasks(.completed))
            } header: {
                SidebarHeader("Tasks")
            }

            Section {
                ForEach(tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Image(systemName: "number")
                            .foregroundStyle(appearsActive ? AnyShapeStyle(tag.color.color) : AnyShapeStyle(.secondary))
                    }
                    .tag(SidebarSelection.tasks(.tag(tag.persistentModelID)))
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
