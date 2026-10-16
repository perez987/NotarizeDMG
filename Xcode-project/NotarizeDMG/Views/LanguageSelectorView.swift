import SwiftUI

struct LanguageItem: Identifiable {
    let id: String
    let code: String
    let name: String
    let flag: String

    init(code: String, name: String, flag: String) {
        id = code
        self.code = code
        self.name = name
        self.flag = flag
    }
}

struct LanguageSelectorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: String
    @State private var showRestartAlert = false
    private let initialLanguage: String

    private let languages: [LanguageItem] = [
        LanguageItem(code: "en", name: "English", flag: "🇬🇧"),
        LanguageItem(code: "es", name: "Español", flag: "🇪🇸"),
        LanguageItem(code: "de", name: "Deutsch", flag: "🇩🇪"),
        LanguageItem(code: "fr", name: "Français", flag: "🇫🇷"),
        LanguageItem(code: "it", name: "Italiano", flag: "🇮🇹"),
    ]

    private var hasLanguageChanged: Bool {
        selectedLanguage != initialLanguage
    }

    init() {
        let currentLang = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?
            .first?.components(separatedBy: "-").first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        _selectedLanguage = State(initialValue: currentLang)
        initialLanguage = currentLang
    }

    var body: some View {
        ZStack {
            AppTheme.windowGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("language_selector_title", comment: "Language selector title"))
                        .font(.title2.weight(.semibold))
                    Text(languages.first(where: { $0.code == selectedLanguage })?.name ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassCard(colorScheme: colorScheme, cornerRadius: 26, accentOpacity: 0.28)

                VStack(spacing: 12) {
                    ForEach(languages) { language in
                        Button {
                            selectedLanguage = language.code
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.system(size: 28))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.name)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(language.code.uppercased())
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: selectedLanguage == language.code ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(selectedLanguage == language.code ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.secondary))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        AppTheme.raisedSurfaceFill(
                                            for: colorScheme,
                                            emphasized: selectedLanguage == language.code
                                        )
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(AppTheme.accentGlow(for: colorScheme))
                                            .opacity(selectedLanguage == language.code ? (colorScheme == .dark ? 0.42 : 0.92) : (colorScheme == .dark ? 0.08 : 0.16))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .strokeBorder(
                                                selectedLanguage == language.code ? AppTheme.accentGradient : AppTheme.borderGradient(for: colorScheme),
                                                lineWidth: selectedLanguage == language.code ? 1.6 : 1
                                            )
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .glassCard(colorScheme: colorScheme, cornerRadius: 28, accentOpacity: 0.18)

                HStack(spacing: 12) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(NSLocalizedString("accept", comment: "Accept button")) {
                        if hasLanguageChanged {
                            saveLanguagePreference()
                            showRestartAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(18)
                .glassCard(colorScheme: colorScheme, cornerRadius: 24, accentOpacity: 0.16)
            }
            .padding(20)
        }
        .frame(width: 380)
        .alert(
            NSLocalizedString("language_changed_title", comment: "Language changed alert title"),
            isPresented: $showRestartAlert
        ) {
            Button(NSLocalizedString("ok", comment: "OK button")) {
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("language_changed_message", comment: "Language changed message"))
        }
    }

    private func saveLanguagePreference() {
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
    }
}

#Preview {
    LanguageSelectorView()
}

