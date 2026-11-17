import CloudKit
import SwiftData
import SwiftUI

@main
struct AgendaApp: App {
    @State private var appState = AppState()
    @State private var calendarModel = WeekCalendarModel(source: EventKitCalendarSource())
    /// Kept alive for the app's lifetime; releasing it unregisters the shortcut.
    @State private var launcherHotKey: GlobalHotKey?
    @State private var syncStatus: SyncStatusModel
    private let modelContainer: ModelContainer

    init() {
        let store = PlannerSchema.openAppStore()
        let container = store.container
        modelContainer = container
        // The CloudKit account lookup traps without the entitlement; a local-only copy reports that instead.
        let provider: AccountStatusProvider = PlannerSchema.hasICloudEntitlement
            ? CloudKitAccountStatusProvider()
            : StaticAccountStatusProvider(status: .available)
        let syncStatus = SyncStatusModel(
            provider: provider,
            storeSyncs: store.syncs,
            storeError: store.syncError,
            onImportFinished: { Self.mergeSyncDuplicates(in: container) }
        )
        // Followed for the app's lifetime, so closing a window neither freezes Settings nor stops merges.
        // Unit tests never reach CloudKit.
        if !PlannerSchema.isRunningTests {
            syncStatus.startObserving()
        }
        _syncStatus = State(initialValue: syncStatus)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(calendarModel)
                .themedAppearance()
                .task { registerLauncherHotKey() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)
        .commands {
            PlannerCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environment(syncStatus)
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

    /// Sync can't enforce uniqueness, so copies made on two Macs are folded together after each
    /// finished import, never mid-import, when a copy could be missing its blocks or task links.
    private static func mergeSyncDuplicates(in container: ModelContainer) {
        let context = container.mainContext
        DuplicateMerger().mergeDuplicates(in: context)
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            PlannerSchema.log("Could not save merged duplicates", error)
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
