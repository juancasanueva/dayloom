import CloudKit
import Foundation

/// What the user is told about iCloud sync.
enum SyncStatus: Equatable {
    case checking
    case on
    case signedOut
    case restricted
    case unavailable
    /// Signed in, but the last sync attempt failed.
    case problem
    /// The store opened without iCloud, so nothing syncs until Agenda is reopened.
    case localOnly

    init(_ account: CKAccountStatus) {
        switch account {
        case .available: self = .on
        case .noAccount: self = .signedOut
        case .restricted: self = .restricted
        case .couldNotDetermine, .temporarilyUnavailable: self = .unavailable
        @unknown default: self = .unavailable
        }
    }

    var title: String {
        switch self {
        case .checking: "Checking iCloud…"
        case .on: "Syncing with iCloud"
        case .signedOut: "Not signed in to iCloud"
        case .restricted: "iCloud is restricted"
        case .unavailable: "iCloud is unavailable"
        case .problem: "iCloud sync hit a problem"
        case .localOnly: "iCloud sync is off on this Mac"
        }
    }

    var detail: String {
        switch self {
        case .checking: "Looking up your iCloud account."
        case .on: "Your tasks, notes, and habits stay up to date on every Mac signed in to this iCloud account."
        case .signedOut: "Sign in to iCloud in System Settings to sync. Until then, everything stays on this Mac."
        case .restricted: "This Mac's settings don't allow iCloud for Dayloom. Your data stays on this Mac."
        case .unavailable: "Dayloom syncs again once iCloud is reachable. Your changes are kept on this Mac."
        case .problem: "Your changes are kept on this Mac, and Dayloom keeps retrying."
        case .localOnly: "iCloud couldn't start when Dayloom opened, so changes stay on this Mac. Quit and reopen Dayloom to try again."
        }
    }

    var symbol: String {
        switch self {
        case .checking: "icloud"
        case .on: "checkmark.icloud"
        case .signedOut, .restricted, .localOnly: "icloud.slash"
        case .unavailable, .problem: "exclamationmark.icloud"
        }
    }
}

/// A finished or running sync step (setup, import, or export).
struct SyncEvent: Equatable {
    enum Kind: Equatable {
        case setup
        case `import`
        case export
    }

    /// `nil` while the step is still running.
    var endDate: Date?
    /// Set when the step failed.
    var errorDescription: String?
    var kind: Kind = .export
}

/// Port for reading the iCloud account state and sync activity.
protocol AccountStatusProvider {
    /// `nil` when the status couldn't be read.
    func accountStatus() async -> CKAccountStatus?
    /// Emits whenever the iCloud account changes.
    func changes() -> AsyncStream<Void>
    /// Emits every sync step the store reports.
    func syncEvents() -> AsyncStream<SyncEvent>
}

/// Fixed answer used by previews and tests.
struct StaticAccountStatusProvider: AccountStatusProvider {
    var status: CKAccountStatus?

    func accountStatus() async -> CKAccountStatus? { status }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func syncEvents() -> AsyncStream<SyncEvent> { AsyncStream { $0.finish() } }
}
