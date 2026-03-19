import AppKit
import Foundation

// MARK: - State

enum CopilotInstallState: Equatable {
    /// Chưa bắt đầu kiểm tra
    case unknown
    /// Đang kiểm tra
    case checking
    /// Không tìm thấy binary, Homebrew cũng không có
    case notInstalled
    /// Homebrew có sẵn — có thể auto-install
    case brewAvailable
    /// Đang cài đặt qua brew, kèm log output
    case installing(log: String)
    /// Binary tìm thấy nhưng chưa authenticate
    case authRequired(path: String)
    /// Sẵn sàng
    case ready(path: String)
    /// Lỗi
    case error(String)
}

// MARK: - Service

@MainActor
@Observable
final class CopilotService {

    // MARK: - Shared

    static let shared = CopilotService()

    // MARK: - State

    var installState: CopilotInstallState = .unknown

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Kiểm tra toàn bộ pipeline: binary → auth
    func check() async {
        installState = .checking

        // 1. Ưu tiên env var override
        let env = ProcessInfo.processInfo.environment
        if let override = env["CODEX_COPILOT_ACP_PATH"], !override.isEmpty {
            let authenticated = await checkAuth(path: override)
            installState = authenticated ? .ready(path: override) : .authRequired(path: override)
            return
        }

        // 2. Tìm binary `copilot`
        if let path = findCopilotBinary() {
            let authenticated = await checkAuth(path: path)
            installState = authenticated ? .ready(path: path) : .authRequired(path: path)
            return
        }

        // 3. Binary không có — kiểm tra brew (kể cả các đường dẫn cố định)
        if findBrewBinary() != nil {
            installState = .brewAvailable
        } else {
            installState = .notInstalled
        }
    }

    /// Cài Copilot CLI qua Homebrew, stream log ra `installState`
    func installViaBrew() async {
        guard case .brewAvailable = installState,
              let brewPath = findBrewBinary() else { return }

        installState = .installing(log: "Running: brew install copilot-cli\n")

        let result = await runStreaming(
            executablePath: brewPath,
            arguments: ["install", "copilot-cli"]
        ) { [weak self] line in
            guard let self else { return }
            if case .installing(let existing) = self.installState {
                self.installState = .installing(log: existing + line + "\n")
            }
        }

        if result.exitCode == 0 {
            // Tìm lại binary sau khi cài xong
            await check()
        } else {
            installState = .error("brew install failed (exit \(result.exitCode)):\n\(result.stderr)")
        }
    }

    /// Mở Terminal để user chạy `copilot` (sẽ auto-redirect tới login)
    func openTerminalForAuth() {
        let copilotPath: String
        if case .authRequired(let path) = installState {
            copilotPath = path
        } else if let found = findCopilotBinary() {
            copilotPath = found
        } else {
            copilotPath = "/opt/homebrew/bin/copilot"
        }

        // Tạo file .command — macOS tự động mở bằng Terminal.app và execute
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copilot_signin.command")
        let script = "#!/bin/bash\nexec \"\(copilotPath)\" login\n"
        do {
            try script.write(to: tmpURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tmpURL.path
            )
            NSWorkspace.shared.open(tmpURL)
        } catch {
            // Fallback: AppleScript với full path
            let appleScript = """
            tell application "Terminal"
                do script "\(copilotPath)"
                activate
            end tell
            """
            NSAppleScript(source: appleScript)?.executeAndReturnError(nil)
        }
    }

    /// Thử lại kiểm tra sau khi user đã authenticate xong
    func recheckAfterAuth() async {
        await check()
    }

    // MARK: - Private Helpers

    /// Tìm `copilot` binary — kiểm tra PATH rồi các đường dẫn cố định
    private func findCopilotBinary() -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/copilot",
            "/usr/local/bin/copilot",
            "/usr/bin/copilot",
        ]
        for path in knownPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // Fallback: dùng PATH của process (hiếm khi có trong sandbox nhưng vẫn check)
        if let path = findOnPATH("copilot") { return path }
        return nil
    }

    /// Tìm `brew` binary — kiểm tra các đường dẫn cố định trước (PATH thường thiếu trong sandbox)
    private func findBrewBinary() -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/brew",   // Apple Silicon
            "/usr/local/bin/brew",      // Intel Mac
        ]
        for path in knownPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let path = findOnPATH("brew") { return path }
        return nil
    }

    /// Tìm executable trên PATH của process hiện tại
    private func findOnPATH(_ command: String) -> String? {
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in pathEnv.split(separator: ":") {
            let full = "\(dir)/\(command)"
            if FileManager.default.isExecutableFile(atPath: full) {
                return full
            }
        }
        return nil
    }

    /// Chạy `which <command>` và trả về path nếu tìm thấy
    private func which(_ command: String) async -> String? {
        let result = await run(
            executablePath: "/usr/bin/env",
            arguments: ["which", command]
        )
        guard result.exitCode == 0 else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    /// Kiểm tra authentication bằng cách ưu tiên env vars, rồi config file
    private func checkAuth(path: String) async -> Bool {
        let env = ProcessInfo.processInfo.environment

        // Kiểm tra token env vars (theo thứ tự ưu tiên của Copilot CLI)
        for key in ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"] {
            if let token = env[key], !token.isEmpty {
                return true
            }
        }

        // Kiểm tra config file tồn tại (~/.copilot/config.json)
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".copilot/config.json")
        if FileManager.default.fileExists(atPath: configURL.path) {
            return true
        }

        return false
    }

    // MARK: - Process Helpers

    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    /// Chạy process đồng bộ (await), trả về kết quả
    private func run(executablePath: String, arguments: [String]) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr))
            }
        }
    }

    /// Chạy process với streaming stdout line-by-line
    private func runStreaming(
        executablePath: String,
        arguments: [String],
        onLine: @escaping @MainActor (String) -> Void
    ) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                var stderrData = Data()
                var buffer = Data()

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { return }
                    buffer.append(chunk)

                    // Tách từng dòng
                    while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                        let lineData = buffer[buffer.startIndex...newline]
                        buffer = buffer[buffer.index(after: newline)...]
                        if let line = String(data: lineData, encoding: .utf8)?
                            .trimmingCharacters(in: .newlines), !line.isEmpty {
                            let lineCopy = line
                            Task { @MainActor in onLine(lineCopy) }
                        }
                    }
                }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    stderrData.append(handle.availableData)
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(exitCode: process.terminationStatus, stdout: "", stderr: stderr))
            }
        }
    }
}
