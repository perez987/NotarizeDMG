import AppKit
import ApplicationServices
import Foundation

protocol AppleScriptRunning {
    func execute(_ source: String) async throws
}

struct DefaultAppleScriptRunner: AppleScriptRunning {
    private static let queue = DispatchQueue(
        label: "NotarizeDMG.applescript",
        qos: .userInitiated
    )

    func execute(_ source: String) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            Self.queue.async {
                do {
                    try Self.executeSynchronously(source)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func executeSynchronously(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptDMGBuilderError.appleScriptCompilationFailed
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message =
                errorInfo[NSAppleScript.errorMessage] as? String
                ?? "Unknown AppleScript error"
            let code =
                (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
                ?? -1
            throw NSError(
                domain: "NSAppleScript",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}

protocol FinderAutomationAuthorizing {
    func requestPermission() async throws
}

struct DefaultFinderAutomationAuthorizer: FinderAutomationAuthorizing {
    func requestPermission() async throws {
        var state = await Self.permissionState(askUserIfNeeded: false)
        if state == .targetNotRunning {
            guard await Self.launchFinderIfNeeded() else {
                throw FinderAutomationAuthorizationError(
                    state: .targetNotAccessible
                )
            }
            state = await Self.permissionState(askUserIfNeeded: false)
            if state == .targetNotRunning {
                state = .targetNotAccessible
            }
        }

        switch state {
        case .authorized:
            return
        case .notDetermined:
            let promptedState = await Self.permissionState(
                askUserIfNeeded: true
            )
            if promptedState == .authorized {
                return
            }
            throw FinderAutomationAuthorizationError(state: promptedState)
        default:
            throw FinderAutomationAuthorizationError(state: state)
        }
    }

    @MainActor
    private static func permissionState(askUserIfNeeded: Bool)
        -> FinderAutomationAuthorizationState
    {
        let finderBundleIdentifier = "com.apple.finder"
        var target = AEAddressDesc()
        let createStatus = finderBundleIdentifier.withCString {
            bundleIdentifier in
            AECreateDesc(
                typeApplicationBundleID,
                bundleIdentifier,
                finderBundleIdentifier.utf8.count,
                &target
            )
        }
        guard createStatus == noErr else {
            return .failed(OSStatus(createStatus))
        }
        defer { AEDisposeDesc(&target) }

        let status = AEDeterminePermissionToAutomateTarget(
            &target,
            AEEventClass(kCoreEventClass),
            AEEventID(kAEGetData),
            askUserIfNeeded
        )
        return FinderAutomationAuthorizationState(status: status)
    }

    private static func launchFinderIfNeeded() async -> Bool {
        if await isFinderRunning() {
            return true
        }

        let launched = await launchFinderApplication()
        guard launched else { return false }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !(await isFinderRunning()) {
            guard clock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return true
    }

    private static func isFinderRunning() async -> Bool {
        await MainActor.run {
            !NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.finder"
            ).isEmpty
        }
    }

    @MainActor
    private static func launchFinderApplication() async -> Bool {
        guard
            let finderURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.finder"
            )
        else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false

        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: finderURL,
                configuration: configuration
            )
            return true
        } catch {
            return false
        }
    }
}

private enum FinderAutomationAuthorizationState: Equatable {
    case authorized
    case notDetermined
    case denied
    case targetNotRunning
    case targetNotAccessible
    case failed(OSStatus)

    init(status: OSStatus) {
        switch status {
        case noErr:
            self = .authorized
        case OSStatus(errAEEventWouldRequireUserConsent):
            self = .notDetermined
        case OSStatus(errAEEventNotPermitted), OSStatus(errAEPrivilegeError),
            OSStatus(userCanceledErr):
            self = .denied
        case OSStatus(procNotFound):
            self = .targetNotRunning
        case OSStatus(errAETimeout), OSStatus(errAETargetAddressNotPermitted):
            self = .targetNotAccessible
        default:
            self = .failed(status)
        }
    }
}

private struct FinderAutomationAuthorizationError: LocalizedError {
    let state: FinderAutomationAuthorizationState

    var errorDescription: String? {
        switch state {
        case .denied, .notDetermined:
            return NSLocalizedString(
                "finder_automation_permission_message",
                comment: "Finder automation permission help"
            )
        case .targetNotRunning, .targetNotAccessible:
            return NSLocalizedString(
                "finder_automation_unavailable_message",
                comment: "Finder automation unavailable message"
            )
        case .failed(let status):
            return String(
                format: NSLocalizedString(
                    "finder_automation_failed_format",
                    comment: "Finder automation failure message"
                ),
                Int64(status)
            )
        case .authorized:
            return nil
        }
    }
}

struct AppleScriptDMGBuilder {
    private enum FinderLayout {
        static let windowOriginX = 100
        static let windowOriginY = 100
        static let backgroundWidth = 644
        static let backgroundHeight = 432
        // Finder's window bounds include its title bar, unlike the background.
        static let windowTitleBarHeight = 28
        static let iconSize = 128
        static let textSize = 12
        static let appPositionX = 160
        static let appPositionY = 195
        static let applicationsPositionX = 484
        static let applicationsPositionY = 195
        static let backgroundDirectoryName = ".background"
        static let backgroundFileName = "background.png"
        static let backgroundCornerRadius: CGFloat = 20
        static let arrowLineWidth: CGFloat = 2.5
        static let arrowHeadLength: CGFloat = 10
        static let arrowHeadHalfHeight: CGFloat = 9

        static var windowRight: Int {
            windowOriginX + backgroundWidth
        }

        static var windowBottom: Int {
            windowOriginY + backgroundHeight + windowTitleBarHeight
        }

        static var backgroundSize: NSSize {
            NSSize(
                width: CGFloat(backgroundWidth),
                height: CGFloat(backgroundHeight)
            )
        }
    }

    private struct Context {
        let workDirectory: URL
        let stagedDirectory: URL
        let readWriteImageURL: URL
        let compressedImageURL: URL
        let mountedVolumeURL: URL
        let finalOutputURL: URL
        let stagedAppName: String
    }

    private struct FileState: Equatable {
        let size: Int?
        let modificationDate: Date?
    }

    private let scriptRunner: AppleScriptRunning
    private let automationAuthorizer: FinderAutomationAuthorizing
    private let fileManager: FileManager

    init(
        scriptRunner: AppleScriptRunning = DefaultAppleScriptRunner(),
        automationAuthorizer: FinderAutomationAuthorizing =
            DefaultFinderAutomationAuthorizer(),
        fileManager: FileManager = .default
    ) {
        self.scriptRunner = scriptRunner
        self.automationAuthorizer = automationAuthorizer
        self.fileManager = fileManager
    }

    func build(
        appURL: URL,
        outputFolder: URL,
        outputDMGName: String,
        runProcess:
            @escaping (_ executable: String, _ args: [String]) async -> Int32,
        onOutput: @escaping (_ text: String) -> Void = { _ in }
    ) async throws -> URL {
        let context = createContext(
            appURL: appURL,
            outputFolder: outputFolder,
            outputDMGName: outputDMGName
        )

        do {
            guard !fileManager.fileExists(atPath: context.finalOutputURL.path)
            else {
                throw AppleScriptDMGBuilderError.outputAlreadyExists(
                    context.finalOutputURL.lastPathComponent
                )
            }

            try clean(context: context)
            try fileManager.createDirectory(
                at: context.workDirectory,
                withIntermediateDirectories: true
            )
            try stageVolume(appURL: appURL, context: context)
            try await createReadWriteImage(
                appURL: appURL,
                context: context,
                runProcess: runProcess
            )
            try await applyFinderLayout(
                appURL: appURL,
                context: context,
                runProcess: runProcess,
                onOutput: onOutput
            )
            try await convertCompressedImage(
                context: context,
                runProcess: runProcess
            )

            try fileManager.moveItem(
                at: context.compressedImageURL,
                to: context.finalOutputURL
            )
            try clean(context: context)
            return context.finalOutputURL
        } catch {
            try? clean(context: context)
            throw error
        }
    }

    private func createContext(
        appURL: URL,
        outputFolder: URL,
        outputDMGName: String
    ) -> Context {
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("NotarizeDMG", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let volumeName = sanitizedVolumeName(for: appURL)
        return Context(
            workDirectory: base,
            stagedDirectory: base.appendingPathComponent(
                "stage",
                isDirectory: true
            ),
            readWriteImageURL: base.appendingPathComponent(
                "\(volumeName).rw.dmg"
            ),
            compressedImageURL: base.appendingPathComponent(outputDMGName),
            mountedVolumeURL: base.appendingPathComponent(
                "mount",
                isDirectory: true
            ),
            finalOutputURL: outputFolder.appendingPathComponent(outputDMGName),
            stagedAppName: appURL.lastPathComponent
        )
    }

    private func sanitizedVolumeName(for appURL: URL) -> String {
        let bundle = Bundle(url: appURL)
        let names = [
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName")
                as? String,
            bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
            appURL.deletingPathExtension().lastPathComponent,
        ]

        for name in names {
            let trimmed = (name ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Application"
    }

    private func stageVolume(appURL: URL, context: Context) throws {
        try fileManager.createDirectory(
            at: context.stagedDirectory,
            withIntermediateDirectories: true
        )

        let appDestination = context.stagedDirectory.appendingPathComponent(
            context.stagedAppName,
            isDirectory: true
        )
        try fileManager.copyItem(at: appURL, to: appDestination)

        let applicationsAlias = context.stagedDirectory.appendingPathComponent(
            "Applications"
        )
        try fileManager.createSymbolicLink(
            at: applicationsAlias,
            withDestinationURL: URL(
                fileURLWithPath: "/Applications",
                isDirectory: true
            )
        )

        let backgroundDirectory = context.stagedDirectory
            .appendingPathComponent(
                FinderLayout.backgroundDirectoryName,
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: backgroundDirectory,
            withIntermediateDirectories: true
        )
        try createBackgroundImage(
            at: backgroundDirectory.appendingPathComponent(
                FinderLayout.backgroundFileName
            )
        )
    }

    private func createReadWriteImage(
        appURL: URL,
        context: Context,
        runProcess:
            @escaping (_ executable: String, _ args: [String]) async -> Int32
    ) async throws {
        try await runCheckedProcess(
            "/usr/bin/hdiutil",
            [
                "create",
                "-volname", sanitizedVolumeName(for: appURL),
                "-srcfolder", context.stagedDirectory.path,
                "-ov",
                "-format", "UDRW",
                context.readWriteImageURL.path,
            ],
            runProcess: runProcess
        )
    }

    private func applyFinderLayout(
        appURL _: URL,
        context: Context,
        runProcess:
            @escaping (_ executable: String, _ args: [String]) async -> Int32,
        onOutput _: @escaping (_ text: String) -> Void
    ) async throws {
        try fileManager.createDirectory(
            at: context.mountedVolumeURL,
            withIntermediateDirectories: true
        )

        try await automationAuthorizer.requestPermission()
        try await preflightFinderAutomation()

        do {
            try await runCheckedProcess(
                "/usr/bin/hdiutil",
                [
                    "attach",
                    context.readWriteImageURL.path,
                    "-readwrite",
                    "-noverify",
                    "-noautoopen",
                    "-mountpoint",
                    context.mountedVolumeURL.path,
                ],
                runProcess: runProcess
            )

            let initialDSStoreState = fileState(
                at: context.mountedVolumeURL.appendingPathComponent(".DS_Store")
            )
            try await scriptRunner.execute(
                finderLayoutScript(
                    appName: context.stagedAppName,
                    mountPath: context.mountedVolumeURL.path
                )
            )
            try await waitForDSStore(
                at: context.mountedVolumeURL,
                initialState: initialDSStoreState
            )

            _ = await runProcess("/bin/sync", [])
        } catch {
            _ = await runProcess(
                "/usr/bin/hdiutil",
                ["detach", context.mountedVolumeURL.path, "-force"]
            )
            await activateCurrentApplication()
            throw error
        }

        try await detachMountedVolume(
            context: context,
            force: false,
            runProcess: runProcess
        )
        await activateCurrentApplication()
    }

    private func convertCompressedImage(
        context: Context,
        runProcess:
            @escaping (_ executable: String, _ args: [String]) async -> Int32
    ) async throws {
        try await runCheckedProcess(
            "/usr/bin/hdiutil",
            [
                "convert",
                context.readWriteImageURL.path,
                "-format",
                "UDZO",
                "-imagekey",
                "zlib-level=9",
                "-o",
                context.compressedImageURL.path,
            ],
            runProcess: runProcess
        )
    }

    private func detachMountedVolume(
        context: Context,
        force: Bool,
        runProcess:
            @escaping (_ executable: String, _ args: [String]) async -> Int32
    ) async throws {
        var arguments = ["detach", context.mountedVolumeURL.path]
        if force {
            arguments.append("-force")
        }

        if force {
            try await runCheckedProcess(
                "/usr/bin/hdiutil",
                arguments,
                runProcess: runProcess
            )
            return
        }

        var lastExitCode: Int32 = 1
        for attempt in 0..<6 {
            let exitCode = await runProcess("/usr/bin/hdiutil", arguments)
            lastExitCode = exitCode
            if exitCode == 0 {
                return
            }
            if attempt < 5 {
                try await Task.sleep(for: .milliseconds(500))
            }
        }

        throw AppleScriptDMGBuilderError.commandFailed(
            executable: "/usr/bin/hdiutil",
            exitCode: lastExitCode
        )
    }

    private func runCheckedProcess(
        _ executable: String,
        _ args: [String],
        runProcess:
            @escaping (_ executable: String, _ args: [String]) async -> Int32
    ) async throws {
        let exitCode = await runProcess(executable, args)
        guard exitCode == 0 else {
            throw AppleScriptDMGBuilderError.commandFailed(
                executable: executable,
                exitCode: exitCode
            )
        }
    }

    private func preflightFinderAutomation() async throws {
        do {
            try await scriptRunner.execute(
                """
                tell application "Finder" to name
                """
            )
        } catch {
            let nsError = error as NSError
            switch nsError.code {
            case Int(errAEEventWouldRequireUserConsent):
                throw FinderAutomationAuthorizationError(state: .notDetermined)
            case Int(errAEEventNotPermitted), Int(errAEPrivilegeError),
                Int(userCanceledErr):
                throw FinderAutomationAuthorizationError(state: .denied)
            case Int(procNotFound), Int(errAETimeout),
                Int(errAETargetAddressNotPermitted):
                throw FinderAutomationAuthorizationError(
                    state: .targetNotAccessible
                )
            default:
                throw error
            }
        }
    }

    private func finderLayoutScript(appName: String, mountPath: String)
        -> String
    {
        let backgroundPath = URL(fileURLWithPath: mountPath, isDirectory: true)
            .appendingPathComponent(
                FinderLayout.backgroundDirectoryName,
                isDirectory: true
            )
            .appendingPathComponent(FinderLayout.backgroundFileName)
            .path

        return """
            tell application "Finder"
                set diskFolder to POSIX file \(mountPath.debugDescription) as alias
                open diskFolder
                delay 2
                set diskWindow to container window of diskFolder
                set backgroundImageFile to POSIX file \(backgroundPath.debugDescription) as alias
                tell diskWindow
                    set current view to icon view
                    set toolbar visible to false
                    set statusbar visible to false
                    set bounds to {\(FinderLayout.windowOriginX), \(FinderLayout.windowOriginY), \(FinderLayout.windowRight), \(FinderLayout.windowBottom)}
                end tell
                set iconViewOptions to icon view options of diskWindow
                set arrangement of iconViewOptions to not arranged
                set background picture of iconViewOptions to backgroundImageFile
                set icon size of iconViewOptions to \(FinderLayout.iconSize)
                set text size of iconViewOptions to \(FinderLayout.textSize)
                set label position of iconViewOptions to bottom
                set appItem to item \(appName.debugDescription) of diskWindow
                set applicationsItem to item "Applications" of diskWindow
                set position of appItem to {\(FinderLayout.appPositionX), \(FinderLayout.appPositionY)}
                set position of applicationsItem to {\(FinderLayout.applicationsPositionX), \(FinderLayout.applicationsPositionY)}
                update diskFolder without registering applications
                delay 2
                close diskWindow
                delay 5
            end tell
            """
    }

    private func waitForDSStore(
        at volumeURL: URL,
        initialState: FileState?
    ) async throws {
        let dsStoreURL = volumeURL.appendingPathComponent(".DS_Store")
        let deadline = Date().addingTimeInterval(10)

        while true {
            if let currentState = fileState(at: dsStoreURL),
                currentState != initialState
            {
                return
            }

            guard Date() < deadline else {
                throw AppleScriptDMGBuilderError.finderLayoutNotPersisted
            }
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    @MainActor
    private func activateCurrentApplication() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func clean(context: Context) throws {
        if fileManager.fileExists(atPath: context.workDirectory.path) {
            try fileManager.removeItem(at: context.workDirectory)
        }
    }

    private func fileState(at url: URL) -> FileState? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey, .contentModificationDateKey,
        ])
        return FileState(
            size: values?.fileSize,
            modificationDate: values?.contentModificationDate
        )
    }

    private func createBackgroundImage(at url: URL) throws {
        let imageSize = FinderLayout.backgroundSize
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let cgContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        let nsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

        let frame = CGRect(x: 43, y: 56, width: 558, height: 335)
        let framePath = CGPath(
            roundedRect: frame,
            cornerWidth: FinderLayout.backgroundCornerRadius,
            cornerHeight: FinderLayout.backgroundCornerRadius,
            transform: nil
        )
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor(srgbRed: 0, green: 0.76, blue: 0.92, alpha: 1).cgColor,
                NSColor(srgbRed: 0, green: 0.43, blue: 1, alpha: 1).cgColor,
            ] as CFArray,
            locations: nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        cgContext.saveGState()
        cgContext.addPath(framePath)
        cgContext.clip()
        let gridSpacing: CGFloat = 9.2
        for major in [false, true] {
            cgContext.beginPath()
            for index in 0...61 where (index % 4 == 0) == major {
                let x = frame.minX + CGFloat(index) * gridSpacing
                cgContext.move(to: CGPoint(x: x, y: frame.minY))
                cgContext.addLine(to: CGPoint(x: x, y: frame.maxY))
            }
            for index in 0...37 where (index % 4 == 0) == major {
                let y = frame.minY + CGFloat(index) * gridSpacing
                cgContext.move(to: CGPoint(x: frame.minX, y: y))
                cgContext.addLine(to: CGPoint(x: frame.maxX, y: y))
            }
            let gridColor = NSColor(
                srgbRed: 0, green: 0.75, blue: 0.85,
                alpha: major ? 0.22 : 0.10
            )
            cgContext.setStrokeColor(gridColor.cgColor)
            cgContext.setLineWidth(0.5)
            cgContext.strokePath()
        }
        cgContext.restoreGState()

        cgContext.saveGState()
        cgContext.addPath(framePath)
        cgContext.setLineWidth(4)
        cgContext.replacePathWithStrokedPath()
        cgContext.clip()
        cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: frame.minX, y: 0),
            end: CGPoint(x: frame.maxX, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        cgContext.restoreGState()

        cgContext.saveGState()
        cgContext.clip(
            to: CGRect(x: frame.minX, y: 116, width: frame.width, height: 2)
        )
        cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: frame.minX, y: 0),
            end: CGPoint(x: frame.maxX, y: 0),
            options: []
        )
        cgContext.restoreGState()

        let arrowY = imageSize.height - CGFloat(FinderLayout.appPositionY)
        let arrowCenterX = CGFloat(
            FinderLayout.appPositionX + FinderLayout.applicationsPositionX
        ) / 2
        let leftPoint = NSPoint(x: arrowCenterX - 56, y: arrowY)
        let rightPoint = NSPoint(x: arrowCenterX + 56, y: arrowY)
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(
            rect: NSRect(x: arrowCenterX - 68, y: arrowY - 16, width: 136, height: 32)
        ).fill()
        NSColor(srgbRed: 0, green: 0.69, blue: 0.91, alpha: 1).setStroke()
        let arrow = NSBezierPath()
        arrow.lineWidth = FinderLayout.arrowLineWidth
        arrow.lineCapStyle = .round
        arrow.move(to: leftPoint)
        arrow.line(to: rightPoint)
        arrow.stroke()

        let arrowHead = NSBezierPath()
        arrowHead.lineWidth = FinderLayout.arrowLineWidth
        arrowHead.lineCapStyle = .round
        arrowHead.lineJoinStyle = .round
        arrowHead.move(
            to: NSPoint(
                x: rightPoint.x - FinderLayout.arrowHeadLength,
                y: rightPoint.y + FinderLayout.arrowHeadHalfHeight
            )
        )
        arrowHead.line(to: rightPoint)
        arrowHead.line(
            to: NSPoint(
                x: rightPoint.x - FinderLayout.arrowHeadLength,
                y: rightPoint.y - FinderLayout.arrowHeadHalfHeight
            )
        )
        arrowHead.stroke()

        guard let cgImage = cgContext.makeImage() else {
            throw CocoaError(.fileWriteUnknown)
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: .atomic)
    }
}

enum AppleScriptDMGBuilderError: LocalizedError {
    case commandFailed(executable: String, exitCode: Int32)
    case appleScriptCompilationFailed
    case finderLayoutNotPersisted
    case outputAlreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let executable, let exitCode):
            return String(
                format: NSLocalizedString(
                    "fallback_command_failed_format",
                    comment: "Fallback command failure"
                ),
                executable,
                Int(exitCode)
            )
        case .appleScriptCompilationFailed:
            return NSLocalizedString(
                "fallback_applescript_compilation_failed",
                comment: "Fallback AppleScript compilation failure"
            )
        case .finderLayoutNotPersisted:
            return NSLocalizedString(
                "finder_layout_not_persisted_message",
                comment: "Finder layout persistence error"
            )
        case .outputAlreadyExists(let filename):
            return String(
                format: NSLocalizedString(
                    "fallback_output_exists_format",
                    comment: "Fallback output exists"
                ),
                filename
            )
        }
    }
}
