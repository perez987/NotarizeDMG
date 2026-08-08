import SwiftUI
import UniformTypeIdentifiers

enum AppMode: Int {
    case notarize
    case build
}

struct ContentView: View {
    @EnvironmentObject private var credentials: CredentialsManager
    @StateObject private var manager = NotarizationManager()
    @AppStorage("lastOutputFolderPath") private var lastOutputFolderPath = ""

    @State private var mode: AppMode = .build
    @State private var showFilePicker = false
    @State private var showAppPicker = false
    @State private var showFolderPicker = false
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            modePicker

            if mode == .notarize {
                DropAreaView(
                    fileURL: $manager.dmgURL,
                    isTargeted: $isDropTargeted,
                    mode: .notarize,
                    onBrowse: { showFilePicker = true }
                )
            } else {
                DropAreaView(
                    fileURL: $manager.appURL,
                    isTargeted: $isDropTargeted,
                    mode: .build,
                    onBrowse: { showAppPicker = true }
                )
                outputFolderRow
            }

            controlsRow

            logBox
        }
        .padding()
        .frame(minWidth: 620, idealWidth: 620, maxWidth: 620,
               minHeight: windowHeight, idealHeight: windowHeight, maxHeight: windowHeight,
               alignment: .top)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "dmg") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result { manager.dmgURL = urls.first }
        }
        // .app bundle picker (Build mode)
        .fileImporter(
            isPresented: $showAppPicker,
            allowedContentTypes: [UTType(filenameExtension: "app") ?? .bundle],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result { manager.appURL = urls.first }
        }
        // Output folder picker (Build mode)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result { manager.outputFolder = urls.first }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(credentials)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .onAppear {
            guard
                manager.outputFolder == nil,
                !lastOutputFolderPath.isEmpty
            else { return }

            let savedFolder = URL(fileURLWithPath: lastOutputFolderPath, isDirectory: true)
            if FileManager.default.fileExists(atPath: savedFolder.path) {
                manager.outputFolder = savedFolder
            }
        }
        .onChange(of: manager.outputFolder) { _, newValue in
            lastOutputFolderPath = newValue?.path ?? ""
        }
    }

    // MARK: - Subviews

    private var windowHeight: CGFloat { mode == .build ? 580 : 520 }

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Text(NSLocalizedString("mode_notarize", comment: "Notarize mode label")).tag(AppMode.notarize)
            Text(NSLocalizedString("mode_build", comment: "Build & Notarize mode label")).tag(AppMode.build)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var outputFolderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            if let folder = manager.outputFolder {
                Text(folder.path)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(NSLocalizedString("output_folder_placeholder", comment: "Output folder placeholder"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(NSLocalizedString("choose_folder", comment: "Choose folder button")) {
                showFolderPicker = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.horizontal, 4)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Spacer()
            if !credentials.isValid {
                Label(NSLocalizedString("configure_credentials_in_settings", comment: "Missing credentials warning"),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            Spacer()
            Button(NSLocalizedString("settings", comment: "Settings button")) { showSettings = true }
            mainActionButton
            Button { showHelp = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 22))
            }
            .help(NSLocalizedString("notarizeDMG_help", comment: "Help button tooltip"))
        }
    }

    private var mainActionButton: some View {
        let isRunning = manager.isRunning
        let label: String
        let isDisabled: Bool

        if isRunning {
            label = NSLocalizedString("cancel", comment: "Cancel button")
            isDisabled = false
        } else if mode == .notarize {
            label = NSLocalizedString("notarize", comment: "Notarize button")
            isDisabled = manager.dmgURL == nil || !credentials.isValid
        } else {
            label = NSLocalizedString("build_and_notarize", comment: "Build & Notarize button")
            isDisabled = manager.appURL == nil || manager.outputFolder == nil || !credentials.isValid
        }

        return Button(label) {
            if isRunning {
                manager.cancel()
            } else if mode == .notarize {
                manager.notarize(credentials: credentials)
            } else {
                manager.buildAndNotarize(credentials: credentials)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(isRunning ? .red : .accentColor)
        .disabled(isDisabled)
    }

    private var logBox: some View {
        GroupBox {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(manager.log.isEmpty ? NSLocalizedString("ready", comment: "Log ready") : manager.log)
                        .font(.system(.body))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .id("logBottom")
                }
                .onChange(of: manager.log) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: .infinity)
        } label: {
            VStack {
                HStack {
                    Label("Log", systemImage: "doc.text.magnifyingglass")
                        .font(.system(.body))
                    Spacer()
                    Button("copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(manager.log, forType: .string)
                    }
                    .disabled(manager.log.isEmpty)
                    Button("clear") { manager.log = "" }
                        .disabled(manager.log.isEmpty)
                }
                Spacer()
            }
        }
    }
}
