import Foundation
import Security

enum KeychainHelper {
    private static let service: String = Bundle.main.bundleIdentifier ?? "com.notarizedmg.app"

    // MARK: - String helpers (used for legacy migration)

    /// Saves or updates a string value in the Keychain for the given key.
    @discardableResult
    static func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return setData(data, forKey: key)
    }

    /// Returns the string value stored in the Keychain for the given key, or nil if absent.
    static func load(key: String) -> String? {
        guard let data = loadData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the Keychain item for the given key.
    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Dictionary helpers (stores all credentials in one keychain item)

    /// Saves or updates a [String: String] dictionary as a single JSON-encoded Keychain item.
    /// Returns true if the operation succeeded.
    @discardableResult
    static func setDictionary(_ dict: [String: String], forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(dict) else { return false }
        return setData(data, forKey: key)
    }

    /// Returns a [String: String] dictionary decoded from a single JSON-encoded Keychain item.
    static func loadDictionary(forKey key: String) -> [String: String]? {
        guard let data = loadData(forKey: key) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    // MARK: - Private raw data helpers

    private static func setData(_ data: Data, forKey key: String) -> Bool {
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary,
                                         [kSecValueData: data] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return updateStatus == errSecSuccess
    }

    private static func loadData(forKey key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }
}
