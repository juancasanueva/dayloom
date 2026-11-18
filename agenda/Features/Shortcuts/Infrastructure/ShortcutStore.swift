import CoreServices
import Foundation
import Observation

/// The user's keyboard shortcuts, read from `~/.config/dayloom/keys.toml` and kept current while it changes.
///
/// The app is sandboxed; a sandbox exception limited to `~/.config/dayloom/` lets it reach that folder.
@Observable
final class ShortcutStore {
    static let shared = ShortcutStore(directory: defaultDirectory)

    /// `~/.config/dayloom` in the user's real home. Inside the sandbox, `NSHomeDirectory()` is the
    /// app's container, so the home folder is looked up from the user account instead.
    static var defaultDirectory: URL {
        realHome.appendingPathComponent(".config", isDirectory: true).appendingPathComponent("dayloom", isDirectory: true)
    }

    let directory: URL
    private(set) var config = ShortcutConfig.defaults
    /// Why the file couldn't be created or read; the defaults apply meanwhile.
    private(set) var problem: String?
    /// Why the system-wide shortcut isn't working, for example because another app already uses it.
    private(set) var systemWideProblem: String?

    @ObservationIgnored private var stream: FSEventStreamRef?

    init(directory: URL) {
        self.directory = directory
    }

    var fileURL: URL { directory.appendingPathComponent("keys.toml") }

    func shortcut(for action: ShortcutAction) -> Shortcut {
        config.shortcut(for: action)
    }

    /// Reads the file, writing it with every default first when it doesn't exist. An existing file is never overwritten.
    func load() {
        let fileManager = FileManager.default
        let parent = directory.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: fileURL.path), !fileManager.fileExists(atPath: parent.path) {
            // The sandbox only reaches ~/.config/dayloom/, so it can't create a missing ~/.config.
            config = .defaults
            let folder = Self.displayPath(parent)
            problem = "Dayloom can only create keys.toml inside an existing \(folder) folder. Create it in Terminal with mkdir \(folder), then reopen Dayloom. The default shortcuts apply meanwhile."
            return
        }
        do {
            if !fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                do {
                    try Data(ShortcutConfig.defaultFileText().utf8).write(to: fileURL, options: .withoutOverwriting)
                } catch CocoaError.fileWriteFileExists {
                    // Another writer got there first; theirs is read below.
                }
            }
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let parsed = ShortcutConfig.parse(text)
            if parsed != config { config = parsed }
            problem = nil
        } catch {
            config = .defaults
            problem = "Dayloom couldn't use \(fileURL.path): \(error.localizedDescription) The default shortcuts apply."
        }
    }

    /// Records whether the system-wide shortcut could be registered.
    func reportSystemWideShortcut(registered: Bool) {
        let shortcut = shortcut(for: .quickLauncherAnywhere).displayText
        systemWideProblem = registered ? nil : "\(shortcut) couldn't be set up as the system-wide shortcut, probably because another app already uses it. Choose other keys for quick_launcher_anywhere."
    }

    /// A path with the home folder written as ~.
    private static func displayPath(_ url: URL) -> String {
        let home = realHome.path
        let path = url.path
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: Watching

    /// Reloads whenever something in the folder changes, whether an editor rewrites the file
    /// in place or replaces it through a rename.
    func startWatching() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let store = Unmanaged<ShortcutStore>.fromOpaque(info).takeUnretainedValue()
            // The stream delivers on the main queue (set below).
            MainActor.assumeIsolated { store.load() }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.2, flags
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stopWatching() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        // FSEvents holds an unretained pointer to the store; it must stop before the store goes away.
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    private static var realHome: URL {
        if let account = getpwuid(getuid()), let home = account.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
