import CloudKit
import SwiftData
import SwiftUI

@main
struct AgendaApp: App {
    @State private var appState: AppState
    @State private var calendarModel: WeekCalendarModel
    /// Kept alive for the app's lifetime; releasing it unregisters the shortcut.
    @State private var launcherHotKey: GlobalHotKey?
    @State private var syncStatus: SyncStatusModel
    private let modelContainer: ModelContainer

    init() {
        // Debug builds launched with -DayloomDemo show sample data for screenshots, never the user's own.
        let isDemo = DemoData.isEnabled()
        let store = isDemo ? PlannerSchema.openStore(inMemory: true) : PlannerSchema.openAppStore()
        let container = store.container
        modelContainer = container

        let appState = AppState()
        if isDemo {
            appState.select(task: DemoData.seed(container.mainContext).persistentModelID)
        }
        _appState = State(initialValue: appState)
        _calendarModel = State(initialValue: WeekCalendarModel(
            source: isDemo ? DemoData.calendarSource() : EventKitCalendarSource()
        ))

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
        if !PlannerSchema.isRunningTests && !isDemo {
            syncStatus.startObserving()
        }
        // Unit tests load XCTest; reminders stay out of them. The UI sandbox (an in-memory store) still gets them.
        if NSClassFromString("XCTestCase") == nil && !isDemo {
            NotificationScheduler.shared.start()
        }
        // ~/.config/dayloom/keys.toml: written with the defaults the first time, then kept current.
        // Tests and the screenshot demo use the defaults and never touch the user's file.
        if !PlannerSchema.isRunningTests && !isDemo {
            ShortcutStore.shared.load()
            ShortcutStore.shared.startWatching()
        }
        _syncStatus = State(initialValue: syncStatus)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .appLanguage()
                .environment(appState)
                .environment(calendarModel)
                .themedAppearance()
                .task { registerLauncherHotKey() }
                .onChange(of: ShortcutStore.shared.shortcut(for: .quickLauncherAnywhere)) {
                    // Releasing the old hotkey unregisters it before the new one is registered.
                    launcherHotKey = nil
                    registerLauncherHotKey()
                }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)
        .commands {
            PlannerCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .appLanguage()
                .environment(syncStatus)
        }
    }

    /// The launcher's system-wide shortcut (⌃⌥Space unless keys.toml says otherwise) brings the
    /// app forward with the launcher open, even from another app.
    private func registerLauncherHotKey() {
        guard launcherHotKey == nil else { return }
        let appState = appState
        launcherHotKey = GlobalHotKey.launcher(shortcut: ShortcutStore.shared.shortcut(for: .quickLauncherAnywhere)) {
            NSApp.activate()
            appState.isLauncherPresented = true
        }
        ShortcutStore.shared.reportSystemWideShortcut(registered: launcherHotKey != nil)
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

/// The menus Dayloom adds. Their titles are built in the app language, and reading it here
/// redraws them when it changes; the menus macOS draws follow from the next launch.
private struct PlannerCommands: Commands {
    let appState: AppState
    private let language = LanguageStore.shared

    var body: some Commands {
        // Read for its observation only: the titles below resolve through AppLocalization.
        let _ = language.language
        CommandGroup(replacing: .appInfo) {
            Button(String(appLocalized: "About Dayloom")) { AboutCredits.showAboutPanel() }
        }

        CommandGroup(replacing: .newItem) {
            Button(String(appLocalized: "New Task")) { appState.requestQuickAdd() }
                .keyboardShortcut(for: .newTask)
            Button(String(appLocalized: "New Note")) { appState.requestNewNote() }
                .keyboardShortcut(for: .newNote)
            Button(String(appLocalized: "Quick Launcher")) { appState.isLauncherPresented.toggle() }
                .keyboardShortcut(for: .quickLauncher)
        }

        CommandGroup(after: .sidebar) {
            Button(appState.isInspectorPresented ? String(appLocalized: "Hide Inspector") : String(appLocalized: "Show Inspector")) {
                appState.isInspectorPresented.toggle()
            }
            .keyboardShortcut(for: .toggleInspector)
        }

        CommandMenu(String(appLocalized: "Go")) {
            Button(String(appLocalized: "Calendar")) { appState.selection = .calendar }
                .keyboardShortcut(for: .goCalendar)
            Button(String(appLocalized: "Inbox")) { appState.selection = .tasks(.inbox) }
                .keyboardShortcut(for: .goInbox)
            Button(String(appLocalized: "Today")) { appState.selection = .tasks(.today) }
                .keyboardShortcut(for: .goToday)
            Button(String(appLocalized: "Upcoming")) { appState.selection = .tasks(.upcoming) }
                .keyboardShortcut(for: .goUpcoming)
            Button(String(appLocalized: "Completed")) { appState.selection = .tasks(.completed) }
                .keyboardShortcut(for: .goCompleted)
            Button(String(appLocalized: "Habits")) { appState.selection = .habits }
                .keyboardShortcut(for: .goHabits)
            Button(String(appLocalized: "Notes")) { appState.selection = .notes }
                .keyboardShortcut(for: .goNotes)
        }
    }
}
