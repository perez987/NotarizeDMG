import SwiftUI
import AppKit

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
//                    helpSection(
//                        icon: "4.circle.fill",
//                        title: NSLocalizedString("help_workflow_title", comment: "Help workflow title"),
//                        body: NSLocalizedString("help_workflow_body", comment: "Help workflow body")
//                    )
                }
                .padding()
                .textSelection(.enabled)
            }

            Divider()

            HStack {
                Spacer()
                Button(NSLocalizedString("ok", comment: "OK button")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 560, height: 440)
        .navigationTitle(NSLocalizedString("help_title", comment: "Help window title"))
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }

    private func helpSection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                markdownText(body)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func markdownText(_ string: String) -> Text {
        if let attributed = try? AttributedString(markdown: string,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(string)
    }
}
