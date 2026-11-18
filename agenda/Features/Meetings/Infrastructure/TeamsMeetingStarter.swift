import AppKit

/// Opens Teams so the user can create a meeting link there and paste it into the task.
///
/// Microsoft Graph only creates Teams meetings for work or school accounts, so personal
/// accounts can't get a link from the app itself.
enum TeamsMeetingStarter {
    static let appURL = URL(string: "msteams:")!
    static let webURL = URL(string: "https://teams.live.com/")!

    /// The Teams app when it's installed, otherwise Teams on the web.
    static func destination(appInstalled: Bool) -> URL {
        appInstalled ? appURL : webURL
    }

    static func open(workspace: NSWorkspace = .shared) {
        workspace.open(destination(appInstalled: workspace.urlForApplication(toOpen: appURL) != nil))
    }
}
