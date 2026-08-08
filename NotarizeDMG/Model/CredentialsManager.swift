import Foundation

/// Stores and retrieves the four credentials needed for DMG notarization.
/// All values are persisted as a single Keychain item so the login password
/// is requested only once instead of four times consecutively.
@MainActor
final class CredentialsManager: ObservableObject {
    static let shared = CredentialsManager()

    @Published var signingIdentity = ""
    @Published var appleID = ""
    @Published var teamID = ""
    @Published var appPassword = ""

    /// The single Keychain account key used to store all credentials as JSON.
    private static let combinedKey = "credentials"

    /// Individual keys from the legacy (pre-combined) storage format.
    private static let legacyKeys = ["signingIdentity", "appleID", "teamID", "appPassword"]

    private init() {
        load()
    }

    /// True when every required field is non-empty.
    var isValid: Bool {
        !signingIdentity.isEmpty && !appleID.isEmpty && !teamID.isEmpty && !appPassword.isEmpty
    }

    /// Reads all credentials from the Keychain into the published properties.
    /// Migrates legacy per-field items to the combined format on first run.
    func load() {
        if let dict = KeychainHelper.loadDictionary(forKey: Self.combinedKey) {
            signingIdentity = dict["signingIdentity"] ?? ""
            appleID = dict["appleID"] ?? ""
            teamID = dict["teamID"] ?? ""
            appPassword = dict["appPassword"] ?? ""
        } else {
            // Migrate from legacy individual keychain items if they exist.
            let legacy = Dictionary(uniqueKeysWithValues: Self.legacyKeys.compactMap { key -> (String, String)? in
                guard let value = KeychainHelper.load(key: key), !value.isEmpty else { return nil }
                return (key, value)
            })
            if !legacy.isEmpty {
                signingIdentity = legacy["signingIdentity"] ?? ""
                appleID = legacy["appleID"] ?? ""
                teamID = legacy["teamID"] ?? ""
                appPassword = legacy["appPassword"] ?? ""
                // Persist in the new combined format; only remove old items on success.
                if save() {
                    Self.legacyKeys.forEach { KeychainHelper.delete(key: $0) }
                }
            }
        }
    }

    /// Writes all published properties back to the Keychain as a single item.
    /// Returns true if the operation succeeded.
    @discardableResult
    func save() -> Bool {
        let dict: [String: String] = [
            "signingIdentity": signingIdentity,
            "appleID": appleID,
            "teamID": teamID,
            "appPassword": appPassword,
        ]
        return KeychainHelper.setDictionary(dict, forKey: Self.combinedKey)
    }
}
