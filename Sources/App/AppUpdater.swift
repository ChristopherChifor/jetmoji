import Foundation

enum AppUpdater {
    static let installedAppPath = "/Applications/Jetmoji.app"
    static let scriptURL = "\(JetmojiVersion.site)/install.sh"

    struct Outcome: Sendable {
        var succeeded: Bool
        var message: String
    }

    static func installLatest() -> Outcome {
        let logURL = FileManager.default.temporaryDirectory.appendingPathComponent("jetmoji-update.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "curl -fsSL \"$1\" | bash", "jetmoji-update", scriptURL]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.qualityOfService = .userInitiated
        process.standardInput = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        let pathParts = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        environment["PATH"] = (["/usr/bin", "/bin", "/usr/sbin", "/sbin"] + pathParts)
            .joined(separator: ":")
        environment["JETMOJI_SKIP_RELAUNCH"] = "1"
        process.environment = environment

        do {
            let log = try FileHandle(forWritingTo: logURL)
            process.standardOutput = log
            process.standardError = log
            try process.run()
            process.waitUntilExit()
            try log.close()
        } catch {
            return Outcome(succeeded: false, message: error.localizedDescription)
        }

        let logText = (try? String(contentsOf: logURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            return Outcome(succeeded: true, message: logText)
        }

        let tail = logText.split(whereSeparator: \.isNewline).suffix(6).joined(separator: "\n")
        if tail.isEmpty {
            return Outcome(succeeded: false, message: "Update failed.")
        }
        return Outcome(succeeded: false, message: tail)
    }
}
