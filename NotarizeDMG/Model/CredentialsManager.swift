import Foundation

/// Stores and retrieves the four credentials needed for DMG notarization.
/// All values are persisted securely in the system Keychain.
@MainActor
final class CredentialsManager: ObservableObject {
    static let shared = CredentialsManager()

    @Published var signingIdentity = ""
    @Published var appleID         = ""
    @Published var teamID          = ""
    @Published var appPassword     = ""

    private init() {
        load()
    }

    /// True when every required field is non-empty.
    var isValid: Bool {
        !signingIdentity.isEmpty && !appleID.isEmpty && !teamID.isEmpty && !appPassword.isEmpty
    }

    /// Reads all credentials from the Keychain into the published properties.
    func load() {
        signingIdentity = KeychainHelper.load(key: "signingIdentity") ?? ""
        appleID         = KeychainHelper.load(key: "appleID")         ?? ""
        teamID          = KeychainHelper.load(key: "teamID")          ?? ""
        appPassword     = KeychainHelper.load(key: "appPassword")     ?? ""
    }

    /// Writes all published properties back to the Keychain.
    func save() {
        KeychainHelper.set(signingIdentity, forKey: "signingIdentity")
        KeychainHelper.set(appleID,         forKey: "appleID")
        KeychainHelper.set(teamID,          forKey: "teamID")
        KeychainHelper.set(appPassword,     forKey: "appPassword")
    }
}
