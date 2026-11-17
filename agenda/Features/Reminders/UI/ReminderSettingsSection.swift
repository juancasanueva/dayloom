import AppKit
import SwiftUI

/// Settings for task reminders: on or off, how early for timed tasks, and when for tasks with only a due date.
struct ReminderSettingsSection: View {
    @Bindable private var store = ReminderSettingsStore.shared
    @State private var isDenied = false
    @Environment(\.openURL) private var openURL

    private static let notificationSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!

    var body: some View {
        PanelSection("Notifications") {
            Toggle(isOn: enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me about tasks")
                        .fontWeight(.medium)
                    Text("A notification before a task starts, or on the day it's due.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if store.settings.isEnabled {
                Divider()
                LabeledContent("Tasks with a time") {
                    Picker("Tasks with a time", selection: $store.settings.lead) {
                        ForEach(ReminderLead.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                LabeledContent("Tasks with only a due date") {
                    DatePicker("Tasks with only a due date", selection: allDayTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }

            if isDenied {
                HStack(spacing: 8) {
                    Text("Notifications are off for Dayloom in System Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Open System Settings") { openURL(Self.notificationSettingsURL) }
                }
            }
        }
        .task { isDenied = await NotificationScheduler.shared.isDenied() }
    }

    /// Turning reminders on asks macOS for permission first; they stay off if it's refused.
    private var enabled: Binding<Bool> {
        Binding(
            get: { store.settings.isEnabled },
            set: { isOn in
                guard isOn else {
                    store.settings.isEnabled = false
                    return
                }
                Task {
                    let granted = await NotificationScheduler.shared.requestAuthorization()
                    store.settings.isEnabled = granted
                    isDenied = !granted
                }
            }
        )
    }

    /// The all-day reminder time as a date today, for the time picker.
    private var allDayTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(store.settings.allDayMinutes) * 60)
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.settings.allDayMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
