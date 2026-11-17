import SwiftData
import SwiftUI

/// Keeps the scheduled reminders in step with the tasks and the reminder settings.
/// Invisible; any change to a task's title, dates or status replans its reminder.
struct ReminderSync: View {
    @Query private var tasks: [TaskItem]
    private let store = ReminderSettingsStore.shared

    var body: some View {
        let plan = ReminderPlanner().plan(candidates, settings: store.settings)

        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: plan, initial: true) { _, plan in
                Task { await NotificationScheduler.shared.replace(with: plan) }
            }
    }

    private var candidates: [ReminderCandidate] {
        tasks.compactMap { task in
            guard task.dueDate != nil || task.scheduledStart != nil,
                  let key = TaskReminderKey.key(for: task.persistentModelID) else { return nil }
            return ReminderCandidate(key: key, title: task.title, dueDate: task.dueDate, scheduledStart: task.scheduledStart, isDone: task.isDone)
        }
    }
}
