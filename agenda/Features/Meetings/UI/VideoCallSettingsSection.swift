import SwiftUI

/// The Google account used to create meetings: whether it's connected, and a way to disconnect it.
struct VideoCallSettingsSection: View {
    private var meetings = GoogleMeetService.shared
    @State private var isDisconnecting = false

    var body: some View {
        PanelSection("Video Calls") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: meetings.isConnected ? "checkmark.circle.fill" : "video.circle")
                    .font(.title3)
                    .foregroundStyle(meetings.isConnected ? Color.green : Color.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Google Meet")
                        .fontWeight(.medium)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if meetings.isConnected {
                    Button("Disconnect") {
                        isDisconnecting = true
                        Task {
                            await meetings.disconnect()
                            isDisconnecting = false
                        }
                    }
                    .disabled(isDisconnecting)
                    .help("Sign out of Google and forget the sign-in on this Mac")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var detail: String {
        if !meetings.isConfigured { return "Google sign-in isn't set up in this build." }
        if meetings.isConnected { return "Signed in. New meetings are created with your Google account." }
        return "Not connected. You'll sign in to Google the first time you create a meeting."
    }
}
