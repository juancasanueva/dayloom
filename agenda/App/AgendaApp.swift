import SwiftData
import SwiftUI

@main
struct AgendaApp: App {
    @State private var appState = AppState()
    @State private var calendarModel = WeekCalendarModel(source: EventKitCalendarSource())
    /// Kept alive for the app's lifetime; releasing it unregisters the shortcut.
    @State private var launcherHotKey: GlobalHotKey?
    @State private var syncStatus = SyncStatusModel(provider: CloudKitAccountStatusProvider())
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer = PlannerSchema.makeContainer(inMemory: PlannerSchema.isRunningTests)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(calendarModel)
                .task { registerLauncherHotKey() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)
        .commands {
            PlannerCommands(appState: appState)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { mergeSyncDuplicates() }
        }

        Settings {
            SettingsView()
                .environment(syncStatus)
        }
    }

    /// Sync can't enforce uniqueness, so copies made on two Macs are folded together
    /// at launch and whenever the app comes forward.
    private func mergeSyncDuplicates() {
        let context = modelContainer.mainContext
        DuplicateMerger().mergeDuplicates(in: context)
        if context.hasChanges {
            try? context.save()
        }
    }

    /// ⌃⌥Space brings the app forward with the launcher open, even from another app.
    private func registerLauncherHotKey() {
        guard launcherHotKey == nil else { return }
        let appState = appState
        launcherHotKey = GlobalHotKey.launcher {
            NSApp.activate()
            appState.isLauncherPresented = true
        }
    }
}

private struct PlannerCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { appState.requestQuickAdd() }
                .keyboardShortcut("n")
            Button("New Note") { appState.requestNewNote() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Quick Launcher") { appState.isLauncherPresented.toggle() }
                .keyboardShortcut("k")
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
            Button("Habits") { appState.selection = .habits }
                .keyboardShortcut("6")
            Button("Notes") { appState.selection = .notes }
                .keyboardShortcut("7")
        }
    }
}
