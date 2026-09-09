import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var credentials: CredentialsManager
    @Environment(\.dismiss) private var dismiss

    @State private var signingIdentity = ""
    @State private var appleID = ""
    @State private var teamID = ""
    @State private var appPassword = ""

    var body: some View {
        ZStack {
            AppTheme.windowGradient
                .ignoresSafeArea()

            VStack(spacing: 18) {
                headerCard

                ScrollView {
                    VStack(spacing: 18) {
                        signingSection
                        accountSection
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                actionsCard
            }
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .onAppear {
            signingIdentity = credentials.signingIdentity
            appleID = credentials.appleID
            teamID = credentials.teamID
            appPassword = credentials.appPassword
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accentGradient)
                    .opacity(0.2)
                    .frame(width: 50, height: 50)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("settings", comment: "Settings button"))
                    .font(.title2.weight(.semibold))
                Text("\n• \(NSLocalizedString("code_signing", comment: "Code signing section title")) \n• \(NSLocalizedString("apple_developer_account", comment: "Apple developer section title"))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .glassCard(cornerRadius: 26, accentOpacity: 0.28)
    }

    private var signingSection: some View {
        settingsSection(title: NSLocalizedString("code_signing", comment: "Code signing section title")) {
            fieldRow(NSLocalizedString("signing_identity", comment: "Signing identity field")) {
                VStack(alignment: .trailing, spacing: 8) {
                    inputField {
                        TextField("", text: $signingIdentity)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                            
                    }
                    .help(NSLocalizedString("signing_identity_example", comment: "Signing identity example"))

                    Text(NSLocalizedString("signing_identity_example", comment: "Signing identity example"))
                        .multilineTextAlignment(.trailing)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var accountSection: some View {
        settingsSection(title: NSLocalizedString("apple_developer_account", comment: "Apple developer section title")) {
            fieldRow(NSLocalizedString("apple_id", comment: "Apple ID field")) {
                inputField {
                    TextField(NSLocalizedString("apple_email_placeholder", comment: "Apple email placeholder"), text: $appleID)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.primary)
                }
            }

            fieldRow(NSLocalizedString("team_id", comment: "Team ID field")) {
                inputField {
                    TextField(NSLocalizedString("team_id_placeholder", comment: "Team ID placeholder"), text: $teamID)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.primary)
                }
            }

            fieldRow(NSLocalizedString("app_specific_password", comment: "App-specific password field")) {
                VStack(alignment: .leading, spacing: 8) {
                    inputField {
                        SecureField("", text: $appPassword)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }
                    Text(NSLocalizedString("app_specific_password_placeholder", comment: "App password example"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            let footerString = NSLocalizedString("generate_app_password_footer", comment: "App password footer")
            Text((try? AttributedString(markdown: footerString)) ?? AttributedString(footerString))
                .font(.callout)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(.bottom, 10)
    }

    private var actionsCard: some View {
        HStack(spacing: 12) {
            Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(NSLocalizedString("save", comment: "Save button")) {
                credentials.signingIdentity = signingIdentity
                credentials.appleID = appleID
                credentials.teamID = teamID
                credentials.appPassword = appPassword
                credentials.save()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(signingIdentity.isEmpty || appleID.isEmpty || teamID.isEmpty || appPassword.isEmpty)
        }
        .padding(18)
        .glassCard(cornerRadius: 24, accentOpacity: 0.16)
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.semibold))

            content()
        }
        .padding(18)
        .glassCard(cornerRadius: 28, accentOpacity: 0.18)
    }

    private func fieldRow<Content: View>(
        _ title: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(width: 150, alignment: .leading)

            field()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.34))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.accentGlow)
                            .opacity(0.18)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                    }
            }
    }
}
