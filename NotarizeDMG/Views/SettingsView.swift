import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var credentials: CredentialsManager
    @Environment(\.dismiss) private var dismiss

    @State private var signingIdentity = ""
    @State private var appleID         = ""
    @State private var teamID          = ""
    @State private var appPassword     = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent(NSLocalizedString("signing_identity", comment: "Signing identity field")) {
                        VStack(alignment: .trailing, spacing: 3) {
                            TextField("", text: $signingIdentity)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                                .foregroundStyle(.secondary)
                            Text(NSLocalizedString("signing_identity_example", comment: "Signing identity example"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("code_signing", comment: "Code signing section title"))
                }

                Section {
                    LabeledContent(NSLocalizedString("apple_id", comment: "Apple ID field")) {
                        TextField(NSLocalizedString("apple_email_placeholder", comment: "Apple email placeholder"), text: $appleID)
                            .foregroundStyle(.secondary)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                    }
                    LabeledContent(NSLocalizedString("team_id", comment: "Team ID field")) {
                        TextField(NSLocalizedString("team_id_placeholder", comment: "Team ID placeholder"), text: $teamID)
                            .foregroundStyle(.secondary)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .font(.body)
                    }
                    LabeledContent(NSLocalizedString("app_specific_password", comment: "App-specific password field")) {
                        VStack(alignment: .leading, spacing: 3) {
                            SecureField("", text: $appPassword)
                                .foregroundStyle(.secondary)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("app_specific_password_placeholder", comment: "App password example"))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("apple_developer_account", comment: "Apple developer section title"))
                } footer: {
                    let footerString = NSLocalizedString("generate_app_password_footer", comment: "App password footer")
                    Text((try? AttributedString(markdown: footerString)) ?? AttributedString(footerString))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(NSLocalizedString("cancel", comment: "Cancel button")) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(NSLocalizedString("save", comment: "Save button")) {
                    credentials.signingIdentity = signingIdentity
                    credentials.appleID         = appleID
                    credentials.teamID          = teamID
                    credentials.appPassword     = appPassword
                    credentials.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(signingIdentity.isEmpty || appleID.isEmpty ||
                          teamID.isEmpty          || appPassword.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 380)
        .onAppear {
            signingIdentity = credentials.signingIdentity
            appleID         = credentials.appleID
            teamID          = credentials.teamID
            appPassword     = credentials.appPassword

        }
    }
}
