import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
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
            }

            Section("Tasks") {
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
            }

            Section("Tags") {
                ForEach(tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Image(systemName: "number").foregroundStyle(tag.color.color)
                    }
                    .tag(SidebarSelection.tasks(.tag(tag.persistentModelID)))
                    .contextMenu { tagMenu(tag) }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        .safeAreaInset(edge: .bottom) {
            Button("New Tag", systemImage: "plus") {
                newTagName = ""
                isAddingTag = true
            }
            .buttonStyle(.borderless)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("New Tag", isPresented: $isAddingTag) {
            TextField("Name", text: $newTagName)
            Button("Add", action: addTag)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Tag", isPresented: isRenaming, presenting: tagBeingRenamed) { tag in
            TextField("Name", text: $renameText)
            Button("Rename") { rename(tag) }
            Button("Cancel", role: .cancel) {}
        }
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

    private var isRenaming: Binding<Bool> {
        Binding(get: { tagBeingRenamed != nil }, set: { if !$0 { tagBeingRenamed = nil } })
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
