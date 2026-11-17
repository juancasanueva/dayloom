import SwiftUI

/// Invites the user to connect their calendars, or explains how to re-enable access.
struct CalendarAccessBanner: View {
    @Environment(WeekCalendarModel.self) private var model
    @Environment(\.openURL) private var openURL

    private static let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!

    var body: some View {
        switch model.access {
        case .granted:
            EmptyView()
        case .notDetermined:
            banner(
                icon: "calendar.badge.plus",
                message: "Connect your calendars to see events next to your tasks.",
                action: "Connect Calendars"
            ) {
                Task { await model.requestAccess() }
            }
        case .denied:
            banner(
                icon: "calendar.badge.exclamationmark",
                message: "Calendar access is off. Turn it on in System Settings to see your events.",
                action: "Open System Settings"
            ) {
                openURL(Self.privacySettingsURL)
            }
        }
    }

    private func banner(icon: String, message: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action, action: perform)
                .buttonStyle(.borderedProminent)
                .fixedSize()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .plannerCard()
    }
}
