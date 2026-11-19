import SwiftUI

/// The accounts used to create meetings: whether each is connected, and a way to disconnect it.
struct VideoCallSettingsSection: View {
    var body: some View {
        PanelSection("Video Calls") {
            MeetingAccountRow(name: "Google Meet", session: GoogleMeetService.shared.session)
            Divider()
            MeetingAccountRow(name: "Zoom", session: ZoomMeetingService.shared.session)
        }
    }
}

private struct MeetingAccountRow: View {
    let name: String
    let session: OAuthSession
    @State private var isDisconnecting = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.isConnected ? "checkmark.circle.fill" : "video.circle")
                .font(.title3)
                .foregroundStyle(session.isConnected ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if session.isConnected {
                Button("Disconnect") {
                    isDisconnecting = true
                    Task {
                        await session.disconnect()
                        isDisconnecting = false
                    }
                }
                .disabled(isDisconnecting)
                .help("Sign out of \(session.serviceName) and forget the sign-in on this Mac")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let service = session.serviceName
        if !session.isConfigured { return String(appLocalized: "\(service) sign-in isn't set up in this build.") }
        if session.isConnected { return String(appLocalized: "Signed in. New meetings are created with your \(service) account.") }
        return String(appLocalized: "Not connected. You'll sign in to \(service) the first time you create a meeting.")
    }
}
