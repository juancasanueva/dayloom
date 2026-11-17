import AppKit
import Foundation
import SwiftData
import UserNotifications

/// Hands Dayloom's reminders to macOS and opens the task when a reminder is clicked.
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private var center: UNUserNotificationCenter { .current() }
    /// Called with the task key of a clicked reminder.
    var onOpenTask: ((String) -> Void)?

    /// Becomes the notification delegate, so reminders show while Dayloom is open and clicks reach it.
    func start() {
        center.delegate = self
    }

    /// Asks macOS for permission; answers whether reminders may be shown.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Whether the person turned Dayloom's notifications off in System Settings.
    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    /// Replaces every pending Dayloom reminder with `reminders`.
    func replace(with reminders: [PlannedReminder]) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = ["taskKey": reminder.taskKey]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let key = response.notification.request.content.userInfo["taskKey"] as? String else { return }
        await MainActor.run {
            NSApp.activate()
            onOpenTask?(key)
        }
    }
}

/// Turns a task's identifier into the text key a reminder carries, and back.
enum TaskReminderKey {
    static func key(for id: PersistentIdentifier) -> String? {
        (try? JSONEncoder().encode(id))?.base64EncodedString()
    }

    static func identifier(from key: String) -> PersistentIdentifier? {
        Data(base64Encoded: key).flatMap { try? JSONDecoder().decode(PersistentIdentifier.self, from: $0) }
    }
}
