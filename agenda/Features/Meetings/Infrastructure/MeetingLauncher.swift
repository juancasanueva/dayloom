import AppKit

/// Opens a meeting in the service's desktop app when it's installed, otherwise in the browser.
enum MeetingLauncher {
    static func join(_ meeting: MeetingLink, workspace: NSWorkspace = .shared) {
        if let appURL = meeting.appURL, workspace.urlForApplication(toOpen: appURL) != nil {
            workspace.open(appURL)
        } else {
            workspace.open(meeting.url)
        }
    }
}
