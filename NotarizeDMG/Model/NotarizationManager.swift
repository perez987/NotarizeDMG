import Foundation

@MainActor
final class NotarizationManager: ObservableObject {
    @Published var log = ""
    @Published var isRunning = false
    @Published var dmgURL: URL?
    @Published var appURL: URL?
    @Published var outputFolder: URL?
    @Published var existingDMGConflictURL: URL?

    private var currentProcess: Process?
    private var isCancelled = false
    private var conflictAppURL: URL?
    private var conflictOutputFolderURL: URL?

    private enum ShellOutputMode {
        case live
        case liveStdoutOnly
        case quiet
        case quietAllowFailureOutput
    }

    private struct ShellResult {
        let exitCode: Int32
        let suppressedOutput: String
    }

    // MARK: - Public API

    func notarize(credentials: CredentialsManager) {
        guard let url = dmgURL else {
            appendLog("❌ No DMG file selected.\n")
            return
        }
        guard credentials.isValid else {
            appendLog("❌ Missing credentials — open Settings and fill in all fields.\n")
            return
        }

        isRunning = true
        isCancelled = false
        log = ""

        Task {
            await runNotarizationSteps(dmgPath: url.path, credentials: credentials, stepOffset: 0)
            isRunning = false
            currentProcess = nil
        }
    }

    func buildAndNotarize(credentials: CredentialsManager) {
        guard let appURL = appURL else {
            appendLog("❌ No .app file selected.\n")
            return
        }
        guard let outputFolder = outputFolder else {
            appendLog("❌ No output folder selected.\n")
            return
        }
        buildAndNotarize(credentials: credentials, appURL: appURL, outputFolder: outputFolder)
    }

    private func buildAndNotarize(credentials: CredentialsManager, appURL: URL, outputFolder: URL) {
        guard credentials.isValid else {
            appendLog("❌ Missing credentials — open Settings and fill in all fields.\n")
            return
        }

        isCancelled = false
        existingDMGConflictURL = nil
        conflictAppURL = nil
        conflictOutputFolderURL = nil

        if let conflictURL = findExistingExpectedDMG(in: outputFolder, appURL: appURL) {
            existingDMGConflictURL = conflictURL
            conflictAppURL = appURL
            conflictOutputFolderURL = outputFolder
            log = ""
            appendLog("⚠️ DMG already exists: \(conflictURL.lastPathComponent)\n")
            return
        }

        log = ""
        isRunning = true

        Task {
            let resultDMG: URL

            if let createDMGPath = findCreateDMG() {
                appendLog("🟦 ──── Step 1: Building DMG with create-dmg ────\n\n")
                appendLog("Using: \(createDMGPath)\n\n")

                let buildStartDate = Date()
                let buildLogStartIndex = log.endIndex
                let buildResult = await shell(createDMGPath, args: [appURL.path, outputFolder.path])
                let buildExit = buildResult.exitCode
                let buildLogOutput = String(log[buildLogStartIndex...])

                guard buildExit == 0, !isCancelled else {
                    if !isCancelled {
                        if buildLogOutput.localizedCaseInsensitiveContains("target already exists"),
                           let conflictURL = findExistingExpectedDMG(in: outputFolder, appURL: appURL) {
                            existingDMGConflictURL = conflictURL
                            conflictAppURL = appURL
                            conflictOutputFolderURL = outputFolder
                        }
                        appendLog("\n❌ create-dmg failed (exit \(buildExit)).\n")
                    }
                    isRunning = false
                    currentProcess = nil
                    return
                }

                guard let builtDMG = findResultingDMG(in: outputFolder, createdAfter: buildStartDate) else {
                    appendLog("\n❌ Could not find resulting DMG in: \(outputFolder.path)\n")
                    isRunning = false
                    currentProcess = nil
                    return
                }
                resultDMG = builtDMG
            } else {
                appendLog("🟦 ──── Step 1: Building DMG with AppleScript fallback ────\n\n")
                appendLog("Using the built-in Finder-based fallback because create-dmg is not installed.\n")
                appendLog("Finder Automation permission may be requested by macOS.\n\n")
                appendLog("- Creating DMG\n")

                let fallbackOutputName = expectedDMGNames(for: appURL).first
                    ?? "\(appURL.deletingPathExtension().lastPathComponent).dmg"

                do {
                    let builder = AppleScriptDMGBuilder()
                    resultDMG = try await builder.build(
                        appURL: appURL,
                        outputFolder: outputFolder,
                        outputDMGName: fallbackOutputName,
                        runProcess: { executable, arguments in
                            let result = await self.shell(executable, args: arguments, outputMode: .quietAllowFailureOutput)
                            if result.exitCode != 0, !result.suppressedOutput.isEmpty {
                                self.appendLog(result.suppressedOutput)
                            }
                            return result.exitCode
                        },
                        onOutput: { text in
                            self.appendLog(text)
                        }
                    )
                    appendLog("✔ Created \"\(resultDMG.lastPathComponent)\"\n")
                } catch {
                    if !isCancelled {
                        if case AppleScriptDMGBuilderError.outputAlreadyExists = error,
                           let conflictURL = findExistingExpectedDMG(in: outputFolder, appURL: appURL) {
                            existingDMGConflictURL = conflictURL
                            conflictAppURL = appURL
                            conflictOutputFolderURL = outputFolder
                            isRunning = false
                            currentProcess = nil
                            return
                        }
                        appendLog("\n❌ AppleScript fallback failed: \(error.localizedDescription)\n")
                    }
                    isRunning = false
                    currentProcess = nil
                    return
                }
            }

            appendLog("\n✅ DMG built: \(resultDMG.lastPathComponent)\n\n")

            await runNotarizationSteps(dmgPath: resultDMG.path, credentials: credentials, stepOffset: 1)
            isRunning = false
            currentProcess = nil
        }
    }

    func cancel() {
        isCancelled = true
        currentProcess?.interrupt()
        currentProcess = nil
        isRunning = false
        appendLog("\n⚠️  Cancelled by user.\n")
    }

    func dismissExistingDMGConflict() {
        clearConflictState()
    }

    func replaceExistingDMGAndRetry(credentials: CredentialsManager) {
        guard let conflictURL = existingDMGConflictURL,
              let appURL = conflictAppURL,
              let outputFolder = conflictOutputFolderURL
        else { return }
        guard credentials.isValid else {
            clearConflictState()
            appendLog("❌ Missing credentials — open Settings and fill in all fields.\n")
            return
        }
        do {
            let values = try conflictURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            guard values.isRegularFile == true else {
                appendLog("❌ Existing path is not a regular DMG file and cannot be replaced.\n")
                return
            }
        } catch {
            appendLog("❌ Could not validate existing DMG path: \(error.localizedDescription)\n")
            return
        }
        do {
            try FileManager.default.removeItem(at: conflictURL)
            if let remainingConflict = findExistingExpectedDMG(in: outputFolder, appURL: appURL) {
                existingDMGConflictURL = remainingConflict
                conflictAppURL = appURL
                conflictOutputFolderURL = outputFolder
                appendLog("❌ Existing DMG could not be replaced.\n")
                return
            }
            clearConflictState()
            appendLog("🗑️ Removed existing DMG: \(conflictURL.lastPathComponent)\n")
        } catch {
            appendLog("❌ Could not remove existing DMG: \(error.localizedDescription)\n")
            if !FileManager.default.fileExists(atPath: conflictURL.path) {
                clearConflictState()
            }
            return
        }
        buildAndNotarize(credentials: credentials, appURL: appURL, outputFolder: outputFolder)
    }

    // MARK: - Private helpers

    /// Returns the path to the `create-dmg` binary, checking both Intel and Apple Silicon locations.
    var isCreateDMGInstalled: Bool {
        findCreateDMG() != nil
    }

    private func findCreateDMG() -> String? {
        let candidates = ["/usr/local/bin/create-dmg", "/opt/homebrew/bin/create-dmg"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Scans `folder` for the most-recently-created DMG file whose creation date is
    /// after `date`. Using a pre-build timestamp rather than a name prefix avoids
    /// issues when create-dmg derives the output name from CFBundleName (which can
    /// differ from the .app bundle's Finder filename, e.g. hyphens vs spaces).
    private func findResultingDMG(in folder: URL, createdAfter date: Date) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let dmgs = files.filter {
            guard $0.pathExtension.lowercased() == "dmg" else { return false }
            let created = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return created >= date
        }
        return dmgs.sorted { a, b in
            let d1 = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let d2 = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return d1 > d2
        }.first
    }

    private func runNotarizationSteps(dmgPath: String, credentials: CredentialsManager, stepOffset: Int) async {
        appendLog("🟦 ──── Step \(1 + stepOffset): Signing the DMG ────\n\n")
        let verifyExit = await shell("/usr/bin/codesign", args: ["--verify", dmgPath], outputMode: .quiet).exitCode
        if verifyExit == 0 {
            appendLog("ℹ️ \(URL(fileURLWithPath: dmgPath).lastPathComponent): is already signed.\n")
        } else {
            let signResult = await shell("/usr/bin/codesign", args: [
                "--sign", credentials.signingIdentity,
                "--timestamp",
                dmgPath,
            ], outputMode: .quietAllowFailureOutput)
            let signExit = signResult.exitCode
            if signExit != 0, !signResult.suppressedOutput.isEmpty {
                appendLog(signResult.suppressedOutput)
            }
            guard signExit == 0 else {
                if !isCancelled {
                    appendLog("\n❌ Signing failed (exit \(signExit)).\n")
                }
                return
            }
            appendLog("✅ Signing completed.\n\n")
        }

        appendLog("\n🟦 ──── Step \(2 + stepOffset): Submitting for notarization ────\n\n")
        let notarizeResult = await shell("/usr/bin/xcrun", args: [
            "notarytool", "submit",
            dmgPath,
            "--apple-id", credentials.appleID,
            "--password", credentials.appPassword,
            "--team-id", credentials.teamID,
            "--wait",
        ], outputMode: .liveStdoutOnly)
        let notarizeExit = notarizeResult.exitCode
        if notarizeExit != 0, !notarizeResult.suppressedOutput.isEmpty {
            appendLog(notarizeResult.suppressedOutput)
        }
        guard notarizeExit == 0 else {
            if !isCancelled {
                appendLog("\n❌ Notarization failed (exit \(notarizeExit)).\n")
            }
            return
        }
        appendLog("✅ Notarization accepted.\n\n")

        appendLog("🟦 ──── Step \(3 + stepOffset): Stapling the ticket ────\n\n")
        let stapleResult = await shell("/usr/bin/xcrun", args: [
            "stapler", "staple",
            dmgPath,
        ], outputMode: .liveStdoutOnly)
        let stapleExit = stapleResult.exitCode
        if stapleExit != 0, !stapleResult.suppressedOutput.isEmpty {
            appendLog(stapleResult.suppressedOutput)
        }
        guard stapleExit == 0 else {
            if !isCancelled {
                appendLog("\n❌ Stapling failed (exit \(stapleExit)).\n")
            }
            return
        }
        appendLog("✅ Stapled.\n\n")
        appendLog("🎉 Done! The DMG is notarized and ready for distribution.\n")
    }

    @discardableResult
    private func shell(
        _ executable: String,
        args: [String],
        outputMode: ShellOutputMode = .live
    ) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args

                // GUI apps don't inherit the user's shell PATH, so tools like `node`
                // (required by create-dmg) are not found. Build a PATH that covers
                // common Homebrew and system binary locations.
                var env = ProcessInfo.processInfo.environment
                let extraPaths = [
                    "/opt/homebrew/bin", // Homebrew (Apple Silicon)
                    "/opt/homebrew/sbin",
                    "/usr/local/bin", // Homebrew (Intel) / nvm / npm globals
                    "/usr/local/sbin",
                    "/usr/bin",
                    "/usr/sbin",
                    "/bin",
                    "/sbin",
                ]
                let currentPath = env["PATH"] ?? ""
                let allPaths: [String] = {
                    var seen = Set<String>()
                    return (extraPaths + currentPath.split(separator: ":").map(String.init))
                        .filter { seen.insert($0).inserted }
                }()
                env["PATH"] = allPaths.joined(separator: ":")
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe

                let shouldLogStdoutLive: Bool
                let shouldLogStderrLive: Bool
                let shouldReplaySuppressedOutputOnFailure: Bool

                switch outputMode {
                case .live:
                    shouldLogStdoutLive = true
                    shouldLogStderrLive = true
                    shouldReplaySuppressedOutputOnFailure = false
                case .liveStdoutOnly:
                    shouldLogStdoutLive = true
                    shouldLogStderrLive = false
                    shouldReplaySuppressedOutputOnFailure = true
                case .quiet:
                    shouldLogStdoutLive = false
                    shouldLogStderrLive = false
                    shouldReplaySuppressedOutputOnFailure = false
                case .quietAllowFailureOutput:
                    shouldLogStdoutLive = false
                    shouldLogStderrLive = false
                    shouldReplaySuppressedOutputOnFailure = true
                }

                let usesCombinedSuppressedPipe = !shouldLogStdoutLive && !shouldLogStderrLive
                process.standardError = usesCombinedSuppressedPipe ? outPipe : errPipe

                let lock = NSLock()
                var suppressedOutput = ""

                func streamProcessOutput(from fileHandle: FileHandle) {
                    let data = fileHandle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor [weak self] in self?.log += text }
                }

                if shouldLogStdoutLive {
                    outPipe.fileHandleForReading.readabilityHandler = { fh in
                        streamProcessOutput(from: fh)
                    }
                }

                if shouldLogStderrLive {
                    errPipe.fileHandleForReading.readabilityHandler = { fh in
                        streamProcessOutput(from: fh)
                    }
                }

                Task { @MainActor [weak self] in self?.currentProcess = process }

                do {
                    try process.run()
                    let outputGroup = DispatchGroup()

                    if usesCombinedSuppressedPipe {
                        outputGroup.enter()
                        DispatchQueue.global(qos: .utility).async {
                            defer { outputGroup.leave() }
                            while true {
                                let data = outPipe.fileHandleForReading.availableData
                                guard !data.isEmpty else { break }
                                if let text = String(data: data, encoding: .utf8) {
                                    lock.lock()
                                    suppressedOutput += text
                                    lock.unlock()
                                }
                            }
                        }
                    } else if !shouldLogStdoutLive {
                        outputGroup.enter()
                        DispatchQueue.global(qos: .utility).async {
                            defer { outputGroup.leave() }
                            while true {
                                let data = outPipe.fileHandleForReading.availableData
                                guard !data.isEmpty else { break }
                                if let text = String(data: data, encoding: .utf8) {
                                    lock.lock()
                                    suppressedOutput += text
                                    lock.unlock()
                                }
                            }
                        }
                    }

                    if !usesCombinedSuppressedPipe && !shouldLogStderrLive {
                        outputGroup.enter()
                        DispatchQueue.global(qos: .utility).async {
                            defer { outputGroup.leave() }
                            while true {
                                let data = errPipe.fileHandleForReading.availableData
                                guard !data.isEmpty else { break }
                                if let text = String(data: data, encoding: .utf8) {
                                    lock.lock()
                                    suppressedOutput += text
                                    lock.unlock()
                                }
                            }
                        }
                    }

                    process.waitUntilExit()
                    outputGroup.wait()
                } catch {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    Task { @MainActor [weak self] in
                        self?.log += "❌ Launch error: \(error.localizedDescription)\n"
                    }
                    continuation.resume(returning: ShellResult(exitCode: -1, suppressedOutput: ""))
                    return
                }

                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                lock.lock()
                let bufferedSuppressedOutput = suppressedOutput
                lock.unlock()
                continuation.resume(returning: ShellResult(
                    exitCode: process.terminationStatus,
                    suppressedOutput: shouldReplaySuppressedOutputOnFailure ? bufferedSuppressedOutput : ""
                ))
            }
        }
    }

    private func findExistingExpectedDMG(in outputFolder: URL, appURL: URL) -> URL? {
        for expectedURL in expectedDMGURLs(in: outputFolder, appURL: appURL) {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: expectedURL.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                return expectedURL
            }
        }
        return nil
    }

    private func expectedDMGURLs(in outputFolder: URL, appURL: URL) -> [URL] {
        expectedDMGNames(for: appURL).map {
            URL(fileURLWithPath: (outputFolder.path as NSString).appendingPathComponent($0))
        }
    }

    private func expectedDMGNames(for appURL: URL) -> [String] {
        var baseNames = [appURL.deletingPathExtension().lastPathComponent]
        var version: String?

        if let bundle = Bundle(url: appURL) {
            let bundleNames = [
                bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            ]

            for bundleName in bundleNames {
                let trimmedName = bundleName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmedName.isEmpty {
                    baseNames.append(trimmedName)
                }
            }

            let trimmedVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmedVersion, !trimmedVersion.isEmpty {
                version = trimmedVersion
            }
        }

        var seenBaseNames = Set<String>()
        let expectedBaseNames = baseNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seenBaseNames.insert($0).inserted }

        var seenFilenames = Set<String>()
        var filenames = [String]()
        for baseName in expectedBaseNames {
            if let version, !version.isEmpty {
                let versionedName = "\(baseName) \(version).dmg"
                if seenFilenames.insert(versionedName).inserted {
                    filenames.append(versionedName)
                }
            }

            let unversionedName = "\(baseName).dmg"
            if seenFilenames.insert(unversionedName).inserted {
                filenames.append(unversionedName)
            }
        }

        return filenames
    }

    private func clearConflictState() {
        existingDMGConflictURL = nil
        conflictAppURL = nil
        conflictOutputFolderURL = nil
    }

    private func appendLog(_ text: String) {
        log += text
    }
}
