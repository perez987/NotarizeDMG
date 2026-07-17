import Foundation

@MainActor
final class NotarizationManager: ObservableObject {
    @Published var log      = ""
    @Published var isRunning = false
    @Published var dmgURL: URL?

    private var currentProcess: Process?
    private var isCancelled = false

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
            await runSteps(dmgPath: url.path, credentials: credentials)
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

    private func runSteps(dmgPath: String, credentials: CredentialsManager) async {
        appendLog("🟦 ──── Step 1: Signing the DMG ────\n\n")
        let verifyExit = await shell("/usr/bin/codesign", args: ["--verify", dmgPath])
        if verifyExit == 0 {
            appendLog("ℹ️ \(URL(fileURLWithPath: dmgPath).lastPathComponent): is already signed.\n")
        } else {
            let signExit = await shell("/usr/bin/codesign", args: [
                "--sign", credentials.signingIdentity,
                "--timestamp",
                dmgPath
            ])
            guard signExit == 0 else {
                if !isCancelled {
                    appendLog("\n❌ Signing failed (exit \(signExit)).\n")
                }
                return
            }
            appendLog("✅ Signing completed.\n\n")
        }

        appendLog("\n🟦 ──── Step 2: Submitting for notarization ────\n\n")
        let notarizeExit = await shell("/usr/bin/xcrun", args: [
            "notarytool", "submit",
            dmgPath,
            "--apple-id",  credentials.appleID,
            "--password",  credentials.appPassword,
            "--team-id",   credentials.teamID,
            "--wait"
        ])
        guard notarizeExit == 0 else {
            if !isCancelled {
                appendLog("\n❌ Notarization failed (exit \(notarizeExit)).\n")
            }
            return
        }
        appendLog("✅ Notarization accepted.\n\n")

        appendLog("🟦 ──── Step 3: Stapling the ticket ────\n\n")
        let stapleExit = await shell("/usr/bin/xcrun", args: [
            "stapler", "staple",
            dmgPath
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
                process.arguments     = args

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError  = errPipe

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
