import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
        } detail: {
            switch appState.selection {
            case .calendar:
                WeekView()
            case .habits:
                HabitsView()
            case .notes:
                NotesView()
            case .tasks(let scope):
                TaskListView(scope: scope)
            case nil:
                ContentUnavailableView("Pick a List", systemImage: "sidebar.left", description: Text("Choose a list or the calendar from the sidebar."))
            }
        }
        .toolbarBackground(Theme.canvas, for: .windowToolbar)
        .inspector(isPresented: $appState.isInspectorPresented) {
            TaskInspector()
                // Never narrower than its default: editing the notes briefly asks for a few more points,
                // and a narrower panel grew to give them, then shrank back on save.
                .inspectorColumnWidth(min: 340, ideal: 340, max: 460)
        }
        .toolbar {
            // Screens show their own large titles, so the toolbar's center holds the launcher instead.
            ToolbarItem(placement: .principal) {
                LauncherPill { appState.isLauncherPresented = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.isInspectorPresented.toggle()
                } label: {
                    Label(appState.isInspectorPresented ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                }
                .help(appState.isInspectorPresented ? "Hide Inspector (⌥⌘I)" : "Show Inspector (⌥⌘I)")
            }
        }
        .overlay {
            if appState.isLauncherPresented {
                QuickLauncherView(isPresented: $appState.isLauncherPresented)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(WeekCalendarModel(source: StaticCalendarSource()))
        .modelContainer(PlannerSchema.makeContainer(inMemory: true))
        .frame(width: 1100, height: 700)
}
