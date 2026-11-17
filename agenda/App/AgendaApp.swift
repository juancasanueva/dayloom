import SwiftData
import SwiftUI

@main
struct AgendaApp: App {
    @State private var appState = AppState()
    @State private var calendarModel = WeekCalendarModel(source: EventKitCalendarSource())
    private let modelContainer = PlannerSchema.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(calendarModel)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)
        .commands {
            PlannerCommands(appState: appState)
        }
    }
}

private struct PlannerCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { appState.requestQuickAdd() }
                .keyboardShortcut("n")
        }

        CommandGroup(after: .sidebar) {
            Button(appState.isInspectorPresented ? "Hide Inspector" : "Show Inspector") {
                appState.isInspectorPresented.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandMenu("Go") {
            Button("Calendar") { appState.selection = .calendar }
                .keyboardShortcut("1")
            Button("Inbox") { appState.selection = .tasks(.inbox) }
                .keyboardShortcut("2")
            Button("Today") { appState.selection = .tasks(.today) }
                .keyboardShortcut("3")
            Button("Upcoming") { appState.selection = .tasks(.upcoming) }
                .keyboardShortcut("4")
            Button("Completed") { appState.selection = .tasks(.completed) }
                .keyboardShortcut("5")
        }
    }
}
