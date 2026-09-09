import AppKit
import SwiftUI

@main
struct NotarizeDMGApp: App {
    private enum WindowID {
        static let help = "help"
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

        Window(NSLocalizedString("notarizeDMG_help", comment: "Help window title"), id: WindowID.help) {
            HelpView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(credentials)
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button(
                    NSLocalizedString(
                        "Check for Updates…",
                        comment: "Menu item to check for app updates"
                    ),
                       systemImage: "arrow.down"
                ){
                    GitHubUpdateChecker.shared.checkForUpdates(userInitiated: true)
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
            CommandMenu(NSLocalizedString("menu_language", comment: "Language menu")) {
                Button(NSLocalizedString("menu_select_language", comment: "Select language menu item")) {
                    isLanguageSelectorPresented = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }

    final class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationDidFinishLaunching(_ notification: Notification) {
            DispatchQueue.main.async {
                self.applyUpdateMenuItemImage()
            }
        }

        private func applyUpdateMenuItemImage() {
            let title = NSLocalizedString("Check for Updates…", comment: "Menu item to check for app updates")
            guard
                let mainMenu = NSApp.mainMenu,
                let menuItem = findMenuItem(withTitle: title, in: mainMenu.items),
                let image = NSImage(
                    systemSymbolName: "arrow.down",
                    accessibilityDescription: title
                )
            else {
                return
            }

            image.isTemplate = true
            menuItem.image = image
        }

        private func findMenuItem(withTitle title: String, in items: [NSMenuItem]) -> NSMenuItem? {
            for item in items {
                if item.title == title {
                    return item
                }

                if let submenu = item.submenu, let match = findMenuItem(withTitle: title, in: submenu.items) {
                    return match
                }
            }

            return nil
        }
    }
}
