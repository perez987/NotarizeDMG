import SwiftUI
import UniformTypeIdentifiers

enum AppMode: Int {
    case notarize
    case build
}

struct ContentView: View {
    @EnvironmentObject private var credentials: CredentialsManager
    @Environment(\.openWindow) private var openWindow
    @StateObject private var manager = NotarizationManager()
    @AppStorage("lastOutputFolderPath") private var lastOutputFolderPath = ""

    @State private var mode: AppMode = .build
    @State private var showCreateDMGAlert = false
    @State private var showFilePicker = false
    @State private var showAppPicker = false
    @State private var showFolderPicker = false
    @State private var showSettings = false
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            AppTheme.windowGradient
                .ignoresSafeArea()

            VStack(spacing: 18) {
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
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 30)

            if showCreateDMGAlert {
                createDMGAlertOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .frame(minWidth: 660, idealWidth: 660, maxWidth: 660,
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
        .onAppear {
            if mode == .build && !manager.isCreateDMGInstalled {
                showCreateDMGAlert = true
            }
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
        .onChange(of: mode) { _, newMode in
            if newMode == .build && !manager.isCreateDMGInstalled {
                showCreateDMGAlert = true
            }
        }
    }

    // MARK: - Subviews

    private var windowHeight: CGFloat {
        mode == .build ? 700 : 640
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $mode) {
                Text(NSLocalizedString("mode_build", comment: "Build & Notarize mode label")).tag(AppMode.build)
                Text(NSLocalizedString("mode_notarize", comment: "Notarize mode label")).tag(AppMode.notarize)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(6)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(AppTheme.accentGlow)
                            .opacity(0.55)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                    }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 26, accentOpacity: 0.3)
    }

    private var outputFolderRow: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accentGradient)
                    .opacity(0.2)
                    .frame(width: 42, height: 42)
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accentGradient)
            }
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
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.24))
            .foregroundStyle(.primary)
            .controlSize(.regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24, accentOpacity: 0.18)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            if !credentials.isValid {
                Label(NSLocalizedString("configure_credentials_in_settings", comment: "Missing credentials warning"),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.35), in: Capsule(style: .continuous))
            }
            Spacer()
            Button(NSLocalizedString("settings", comment: "Settings button")) { showSettings = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
            mainActionButton
            Button {
                openWindow(id: "help")
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help(NSLocalizedString("help_button_tooltip", comment: "Help button tooltip"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24, accentOpacity: 0.2)
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
        .tint(isRunning ? .red : .accentColor.opacity(0.92))
        .controlSize(.large)
        .disabled(isDisabled)
    }

    private var createDMGAlertOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.18))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.accentGradient)
                        .opacity(0.22)
                        .frame(width: 52, height: 52)

                    Image(systemName: "shippingbox.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.accentGradient)
                }

                Text(NSLocalizedString("create_dmg_alert_title", comment: "create-dmg missing alert title"))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("create_dmg_alert_message", comment: "create-dmg missing alert message"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(NSLocalizedString("create_dmg_alert_button", comment: "create-dmg missing alert button")) {
                    showCreateDMGAlert = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            .frame(width: 420)
            .glassCard(cornerRadius: 30, accentOpacity: 0.24)
            .shadow(color: AppTheme.shadowColor, radius: 26, x: 0, y: 18)
        }
    }

    private var logBox: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Log", systemImage: "waveform.path.ecg.rectangle")
                    .font(.system(.body, weight: .semibold))
                Spacer()
                Button("copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(manager.log, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(manager.log.isEmpty)
                Button("clear") { manager.log = "" }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(manager.log.isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()
                .overlay(.white.opacity(0.32))

            ScrollViewReader { proxy in
                ScrollView {
                    Text(manager.log.isEmpty ? NSLocalizedString("ready", comment: "Log ready") : manager.log)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                        .id("logBottom")
                }
                .background(Color.white.opacity(0.12))
                .onChange(of: manager.log) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
//            .frame(minHeight: 200, maxHeight: .infinity)
        }
        .glassCard(cornerRadius: 28, accentOpacity: 0.16)
    }
}
