import Foundation
import Security

/// Minimal Keychain wrapper for credentials that must not live in
/// UserDefaults (private keys, session blobs). Tiny surface — just
/// `set(data:forKey:)` / `data(forKey:)` / `remove(forKey:)`.
///
/// Accessibility defaults to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:
/// blob is readable after the device has been unlocked at least once
/// since boot, never synced to iCloud, never restored from device-to-
/// device backup. Reasonable tradeoff for wallet sessions — survives
/// reboots, can't leak via iCloud backup.
enum KeychainStore {
    /// Service identifier written into every Keychain item we create,
    /// so test runs / other apps don't collide with ours.
    private static let service = "Wave.Pulsoria.Keychain"

    /// Writes `data` under `key`, overwriting any existing item.
    @discardableResult
    static func set(_ data: Data, forKey key: String) -> Bool {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        // Try to update first; if no existing item, add.
        let updateStatus = SecItemUpdate(
            baseQuery(for: key) as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    /// Returns the bytes stored under `key`, or nil if the item is
    /// missing / the Keychain query fails.
    static func data(forKey key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func remove(forKey key: String) -> Bool {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
