import CloudKit
import Foundation

/// What the user is told about iCloud sync.
enum SyncStatus: Equatable {
    case checking
    case on
    case signedOut
    case restricted
    case unavailable

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
        }
    }

    var detail: String {
        switch self {
        case .checking: "Looking up your iCloud account."
        case .on: "Your tasks, notes, and habits stay up to date on every Mac signed in to this iCloud account."
        case .signedOut: "Sign in to iCloud in System Settings to sync. Until then, everything stays on this Mac."
        case .restricted: "This Mac's settings don't allow iCloud for Agenda. Your data stays on this Mac."
        case .unavailable: "Agenda syncs again once iCloud is reachable. Your changes are kept on this Mac."
        }
    }

    var symbol: String {
        switch self {
        case .checking: "icloud"
        case .on: "checkmark.icloud"
        case .signedOut, .restricted: "icloud.slash"
        case .unavailable: "exclamationmark.icloud"
        }
    }
}

/// Port for reading the iCloud account state.
protocol AccountStatusProvider {
    /// `nil` when the status couldn't be read.
    func accountStatus() async -> CKAccountStatus?
    /// Emits whenever the iCloud account changes.
    func changes() -> AsyncStream<Void>
}

/// Fixed answer used by previews and tests.
struct StaticAccountStatusProvider: AccountStatusProvider {
    var status: CKAccountStatus?

    func accountStatus() async -> CKAccountStatus? { status }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
