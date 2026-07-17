import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var credentials: CredentialsManager
    @StateObject private var manager = NotarizationManager()

    @State private var showFilePicker  = false
    @State private var showSettings    = false
    @State private var isDropTargeted  = false

    var body: some View {
        VStack(spacing: 16) {
            DropAreaView(
                dmgURL:     $manager.dmgURL,
                isTargeted: $isDropTargeted,
                onBrowse:   { showFilePicker = true }
            )

            controlsRow

            logBox
        }
        .padding()
        .frame(minWidth: 620, idealWidth: 620, maxWidth: 620, minHeight: 520, idealHeight: 520, maxHeight: 520)
        .fileImporter(
            isPresented:          $showFilePicker,
            allowedContentTypes:  [UTType(filenameExtension: "dmg") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                manager.dmgURL = urls.first
            case .failure(let err):
                manager.log += "File picker error: \(err.localizedDescription)\n"
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(credentials)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            if !credentials.isValid {
                Label(NSLocalizedString("configure_credentials_in_settings", comment: "Missing credentials warning"),
                      systemImage: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(.blue)
            }
            Spacer()
            Button(NSLocalizedString("settings", comment: "Settings button")) { showSettings = true }
            notarizeButton
        }
    }

    private var notarizeButton: some View {
        Button(manager.isRunning
               ? NSLocalizedString("cancel", comment: "Cancel button")
               : NSLocalizedString("notarize", comment: "Notarize button")) {
            if manager.isRunning { manager.cancel() }
            else                 { manager.notarize(credentials: credentials) }
        }
        .buttonStyle(.borderedProminent)
        .tint(manager.isRunning ? .red : .accentColor)
        .disabled(!manager.isRunning &&
                  (manager.dmgURL == nil || !credentials.isValid))
    }

    private var logBox: some View {
        GroupBox {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(manager.log.isEmpty ? "Ready." : manager.log)
                        .font(.system(.body))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .id("logBottom")
                }
                .onChange(of: manager.log) { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: .infinity)
        } label: {
            HStack {
                Label("Log", systemImage: "doc.text.magnifyingglass")
                Spacer()
                Button("copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(manager.log, forType: .string)
                }
                .disabled(manager.log.isEmpty)
                Button("clear") { manager.log = "" }
                    .disabled(manager.log.isEmpty)
            }
        }
    }
}
