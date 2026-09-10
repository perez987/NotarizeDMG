import AppKit
import SwiftUI

struct HelpView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.windowGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                headerCard

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        helpSection(
                            icon: "1.circle.fill",
                            title: NSLocalizedString("help_step1_title", comment: "Help step 1 title"),
                            body: NSLocalizedString("help_step1_body", comment: "Help step 1 body")
                        )
                        helpSection(
                            icon: "2.circle.fill",
                            title: NSLocalizedString("help_step2_title", comment: "Help step 2 title"),
                            body: NSLocalizedString("help_step2_body", comment: "Help step 2 body")
                        )
                        helpSection(
                            icon: "3.circle.fill",
                            title: NSLocalizedString("help_step3_title", comment: "Help step 3 title"),
                            body: NSLocalizedString("help_step3_body", comment: "Help step 3 body")
                        )
                    }
                    .padding(18)
                    .textSelection(.enabled)
                }
                .scrollIndicators(.hidden)
                .glassCard(colorScheme: colorScheme, cornerRadius: 28, accentOpacity: 0.18)

                HStack {
                    Spacer()
                    Button(NSLocalizedString("ok", comment: "OK button")) { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(18)
                .glassCard(colorScheme: colorScheme, cornerRadius: 24, accentOpacity: 0.16)
            }
            .padding(20)
        }
        .frame(width: 620, height: 560)
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accentGradient)
                    .opacity(0.2)
                    .frame(width: 50, height: 50)
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("help_title", comment: "Help window title"))
                    .font(.title2.weight(.semibold))
                Text(NSLocalizedString("notarizeDMG_help", comment: "Help window title"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .glassCard(colorScheme: colorScheme, cornerRadius: 26, accentOpacity: 0.28)
    }

    private func helpSection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.accentGradient)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                markdownText(body)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.raisedSurfaceFill(for: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.accentGlow(for: colorScheme))
                        .opacity(0.16)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient(for: colorScheme), lineWidth: 1)
                }
        }
    }

    private func markdownText(_ string: String) -> Text {
        if let attributed = try? AttributedString(markdown: string,
                                                  options: AttributedString.MarkdownParsingOptions(
                                                      interpretedSyntax: .inlineOnlyPreservingWhitespace
                                                  ))
        {
            return Text(attributed)
        }
        return Text(string)
    }
}
