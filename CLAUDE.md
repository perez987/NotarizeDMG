# Context for AI agents working

This file provides context for AI agents working in this repository.

## Project overview

**NotarizeDMG** is a macOS SwiftUI utility (macOS 14 Sonoma+, Xcode 15+) that:

1. **Notarize DMG mode** — signs and notarizes an existing `.dmg` file using `codesign`, `xcrun notarytool`, and `xcrun stapler`.
2. **Build & Notarize mode** — calls the third-party CLI tool `create-dmg` to build a polished DMG from a `.app` bundle, then runs the same three-step notarization pipeline on the result.

There are no tests and no CI pipeline. The project is built exclusively with Xcode on macOS.

## Repository structure

```
NotarizeDMG.xcodeproj/          Xcode project file
NotarizeDMG/
  NotarizeDMGApp.swift          App entry point; registers Settings scene and Language menu (⌘L)
  Views/
    ContentView.swift           Main window: mode picker, drop area, controls row, log box
    DropAreaView.swift          Reusable drop-zone for .dmg (Notarize) or .app (Build) files
    SettingsView.swift          Credentials form sheet (signing identity, Apple ID, Team ID, password)
    HelpView.swift              In-app help sheet explaining create-dmg install and usage
  Model/
    NotarizationManager.swift   ObservableObject; owns the Process execution, log streaming, cancel logic
    CredentialsManager.swift    ObservableObject; loads/saves credentials as a single JSON Keychain item
    KeychainHelper.swift        Low-level Keychain read/write/delete helpers
  Languages/
    LanguageSelectorView.swift  Sheet to pick UI language; persists via UserDefaults "AppleLanguages"
    en.lproj/Localizable.strings
    es.lproj/Localizable.strings
    de.lproj/Localizable.strings
    fr.lproj/Localizable.strings
    it.lproj/Localizable.strings
Images/                         Screenshots used in README.md
```

## Key design decisions

- **App Sandbox is disabled** — required to launch `codesign`, `xcrun`, and `create-dmg` as child processes.
- **Keychain storage** — all four credentials are stored as a single JSON item (key `"credentials"`, service `perez987.notarizedmg`). `CredentialsManager` auto-migrates legacy per-field items on first launch.
- **PATH injection** — `NotarizationManager.shell()` injects `/opt/homebrew/bin`, `/opt/homebrew/sbin`, `/usr/local/bin`, etc. so GUI-launched processes can find Homebrew tools like `node` (required by `create-dmg`).
- **create-dmg detection** — checked at `/usr/local/bin/create-dmg` (Intel) and `/opt/homebrew/bin/create-dmg` (Apple Silicon). If absent, a clear error is shown in the log.
- **Output folder persistence** — last chosen output folder is stored in `@AppStorage("lastOutputFolderPath")` and restored on launch.
- **Localization** — all user-visible strings use `NSLocalizedString`. Add new strings to all five `.lproj/Localizable.strings` files.

## Build and run

Open `NotarizeDMG.xcodeproj` in Xcode, set your Team under *Signing & Capabilities*, and press ⌘R. There is no command-line build script.

## Coding conventions

- Swift, SwiftUI, macOS-only. Target macOS 14+.
- `@MainActor` on `ObservableObject` classes (`NotarizationManager`, `CredentialsManager`).
- No third-party Swift dependencies; `create-dmg` is a runtime tool, not a build dependency.
- Localized strings for every user-visible label. Keys follow `snake_case`.
- Comments are minimal; add them only where logic is non-obvious.
