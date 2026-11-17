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
        .inspector(isPresented: $appState.isInspectorPresented) {
            TaskInspector()
                .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
        }
        .toolbar {
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
