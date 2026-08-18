import Foundation

@MainActor
final class NotarizationManager: ObservableObject {
    @Published var log = ""
    @Published var isRunning = false
    @Published var dmgURL: URL?
    @Published var appURL: URL?
    @Published var outputFolder: URL?

    private var currentProcess: Process?
    private var isCancelled = false

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
        guard let createDMGPath = findCreateDMG() else {
            appendLog("❌ create-dmg not found.\n")
            appendLog("   Install it: npm install --global create-dmg\n")
            appendLog("   Expected at /usr/local/bin/create-dmg (Intel) or /opt/homebrew/bin/create-dmg (Apple Silicon)\n")
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
            appendLog("🟦 ──── Step 1: Building DMG with create-dmg ────\n\n")
            appendLog("Using: \(createDMGPath)\n\n")

            let buildStartDate = Date()
            let buildExit = await shell(createDMGPath, args: [appURL.path, outputFolder.path])

            guard buildExit == 0, !isCancelled else {
                if !isCancelled {
                    appendLog("\n❌ create-dmg failed (exit \(buildExit)).\n")
                }
                isRunning = false
                currentProcess = nil
                return
            }

            guard let resultDMG = findResultingDMG(in: outputFolder, createdAfter: buildStartDate) else {
                appendLog("\n❌ Could not find resulting DMG in: \(outputFolder.path)\n")
                isRunning = false
                currentProcess = nil
                return
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

    // MARK: - Private helpers

    /// Returns the path to the `create-dmg` binary, checking both Intel and Apple Silicon locations.
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
        let verifyExit = await shell("/usr/bin/codesign", args: ["--verify", dmgPath])
        if verifyExit == 0 {
            appendLog("ℹ️ \(URL(fileURLWithPath: dmgPath).lastPathComponent): is already signed.\n")
        } else {
            let signExit = await shell("/usr/bin/codesign", args: [
                "--sign", credentials.signingIdentity,
                "--timestamp",
                dmgPath,
            ])
            guard signExit == 0 else {
                if !isCancelled {
                    appendLog("\n❌ Signing failed (exit \(signExit)).\n")
                }
                return
            }
            appendLog("✅ Signing completed.\n\n")
        }

        appendLog("\n🟦 ──── Step \(2 + stepOffset): Submitting for notarization ────\n\n")
        let notarizeExit = await shell("/usr/bin/xcrun", args: [
            "notarytool", "submit",
            dmgPath,
            "--apple-id", credentials.appleID,
            "--password", credentials.appPassword,
            "--team-id", credentials.teamID,
            "--wait",
        ])
        guard notarizeExit == 0 else {
            if !isCancelled {
                appendLog("\n❌ Notarization failed (exit \(notarizeExit)).\n")
            }
            return
        }
        appendLog("✅ Notarization accepted.\n\n")

        appendLog("🟦 ──── Step \(3 + stepOffset): Stapling the ticket ────\n\n")
        let stapleExit = await shell("/usr/bin/xcrun", args: [
            "stapler", "staple",
            dmgPath,
        ])
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
    private func shell(_ executable: String, args: [String]) async -> Int32 {
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
                process.standardError = errPipe

                outPipe.fileHandleForReading.readabilityHandler = { fh in
                    let data = fh.availableData
                    guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor [weak self] in self?.log += str }
                }
                errPipe.fileHandleForReading.readabilityHandler = { fh in
                    let data = fh.availableData
                    guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor [weak self] in self?.log += str }
                }

                Task { @MainActor [weak self] in self?.currentProcess = process }

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    Task { @MainActor [weak self] in
                        self?.log += "❌ Launch error: \(error.localizedDescription)\n"
                    }
                    continuation.resume(returning: -1)
                    return
                }

                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                continuation.resume(returning: process.terminationStatus)
            }
        }
    }

    private func appendLog(_ text: String) {
        log += text
    }
}
