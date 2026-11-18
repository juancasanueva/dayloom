import SwiftUI

/// "Join Zoom", "Join Google Meet"…: opens the meeting in its app or the browser.
struct JoinMeetingButton: View {
    let meeting: MeetingLink

    var body: some View {
        Button {
            MeetingLauncher.join(meeting)
        } label: {
            Label(meeting.joinTitle, systemImage: "video.fill")
        }
        .help("Open \(meeting.url.host() ?? meeting.provider.name)")
    }
}

/// A small camera button for a calendar block that is a video call.
struct JoinMeetingIconButton: View {
    let meeting: MeetingLink
    var tint: Color

    var body: some View {
        Button {
            MeetingLauncher.join(meeting)
        } label: {
            Image(systemName: "video.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .padding(3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(meeting.joinTitle)
        .accessibilityLabel(meeting.joinTitle)
    }
}
