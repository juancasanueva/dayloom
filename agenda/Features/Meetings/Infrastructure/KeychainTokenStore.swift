import Foundation
import Security

/// Keeps a sign-in in this Mac's Keychain. It is never synced to iCloud.
struct KeychainTokenStore: TokenStore {
    /// The item Google's sign-in has used since it shipped; renaming it would sign the user out.
    static let google = KeychainTokenStore(service: "com.juancasanueva.agenda.google-oauth", account: "google-meet", serviceName: "Google")
    static let zoom = KeychainTokenStore(service: "com.juancasanueva.agenda.zoom-oauth", account: "zoom", serviceName: "Zoom")

    let service: String
    let account: String
    /// Names the service in error messages, such as "Google".
    let serviceName: String

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> OAuthTokens? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    func save(_ tokens: OAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw KeychainError(status: updated, serviceName: serviceName) }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw KeychainError(status: added, serviceName: serviceName) }
    }

    func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    let serviceName: String

    var errorDescription: String? {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
        return String(appLocalized: "Couldn't save the \(serviceName) sign-in to the Keychain: \(message).")
    }
}
