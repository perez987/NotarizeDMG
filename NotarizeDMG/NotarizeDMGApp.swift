import SwiftUI

@main
struct NotarizeDMGApp: App {
    @StateObject private var credentials = CredentialsManager.shared
    @State private var isLanguageSelectorPresented = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(credentials)
                .sheet(isPresented: $isLanguageSelectorPresented) {
                    LanguageSelectorView()
                }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(credentials)
        }
        .commands {
            CommandMenu(NSLocalizedString("menu_language", comment: "Language menu")) {
                Button(NSLocalizedString("menu_select_language", comment: "Select language menu item")) {
                    isLanguageSelectorPresented = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
