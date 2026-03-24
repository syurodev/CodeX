import Foundation

// MARK: - RunState (unchanged)

enum RunState: Equatable {
    case idle
    case starting
    case running(pid: Int32, port: Int?)
    case error(String)

    var isRunning: Bool {
        switch self {
        case .starting, .running: return true
        case .idle, .error:       return false
        }
    }

    var port: Int? {
        if case .running(_, let p) = self { return p }
        return nil
    }

    var statusLabel: String {
        switch self {
        case .idle:              return ""
        case .starting:          return "Starting…"
        case .running(_, let p): return p.map { ":\($0)" } ?? "Running"
        case .error(let msg):    return msg
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ProjectRunViewModel {

    // MARK: Detected project info
    var detectedKind: DetectedProjectKind = .unknown
    var scriptGroups: [RunScriptGroup] = []

    // MARK: Per-script run state (key = script.id)
    private(set) var scriptStates: [String: RunState] = [:]

    // MARK: Aggregated output (for terminal panel)
    var outputLines: [String] = []
    var lastOutputLine: String = ""

    // MARK: Per-script output (key = script.id)
    var perScriptOutputLines: [String: [String]] = [:]

    // MARK: Computed
    var scripts: [RunScript] { scriptGroups.flatMap(\.scripts) }
    var hasScripts: Bool { !scriptGroups.isEmpty }
    var hasAnyRunning: Bool { scriptStates.values.contains { $0.isRunning } }

    // MARK: Callbacks
    var onRunEnded: (() -> Void)?
    var onScriptEnded: ((String) -> Void)?

    // MARK: Private process handles (key = script.id)
    private var processes: [String: Process] = [:]
    private var outHandles: [String: FileHandle] = [:]
    private var errHandles: [String: FileHandle] = [:]
    private var projectRoot: URL?

    // MARK: - Detect

    func detect(in root: URL) {
        stopAll()
        projectRoot = root
        outputLines.removeAll()
        lastOutputLine = ""

        let kind = ProjectScriptService.detect(in: root)
        detectedKind = kind
        scriptGroups = ProjectScriptService.detectGroups(in: root)
    }

    // MARK: - Run

    func isRunning(_ script: RunScript) -> Bool {
        scriptStates[script.id]?.isRunning ?? false
    }

    func runState(for script: RunScript) -> RunState {
        scriptStates[script.id] ?? .idle
    }

    func run(script: RunScript) {
        let key = script.id
        guard !(scriptStates[key]?.isRunning ?? false) else { return }

        scriptStates[key] = .starting
        outputLines.removeAll()
        lastOutputLine = ""
        perScriptOutputLines[key] = []

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        proc.executableURL       = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments           = ["-l", "-c", script.command]
        proc.currentDirectoryURL = script.workingDirectory
        proc.standardOutput      = outPipe
        proc.standardError       = errPipe

        var env = ProcessInfo.processInfo.environment
        env["TERM"]     = "dumb"
        env["NO_COLOR"] = "1"

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths: [String] = [
            "\(home)/.bun/bin",
            "\(home)/.deno/bin",
            "\(home)/.cargo/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/go/bin",
            "\(home)/.volta/bin",
            "\(home)/.nvm/versions/node/current/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = extraPaths.joined(separator: ":") + ":" + currentPath
        proc.environment = env

        processes[key]  = proc
        outHandles[key] = outPipe.fileHandleForReading
        errHandles[key] = errPipe.fileHandleForReading

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.ingest(text, key: key) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.ingest(text, key: key) }
        }

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cleanupHandles(key: key)
                guard self.scriptStates[key]?.isRunning == true else { return }
                let code = p.terminationStatus
                self.scriptStates[key] = code == 0 ? .idle : .error("Exited \(code)")
                self.onScriptEnded?(key)
                if !self.hasAnyRunning { self.onRunEnded?() }
            }
        }

        do {
            try proc.run()
            scriptStates[key] = .running(pid: proc.processIdentifier, port: nil)
        } catch {
            scriptStates[key] = .error(error.localizedDescription)
            cleanupHandles(key: key)
        }
    }

    // MARK: - Stop

    func stop(script: RunScript) {
        let key = script.id
        processes[key]?.terminate()
        cleanupHandles(key: key)
        scriptStates[key] = .idle
        if !hasAnyRunning { onRunEnded?() }
    }

    func stopAll() {
        for key in processes.keys {
            processes[key]?.terminate()
            cleanupHandles(key: key)
        }
        scriptStates = [:]
        onRunEnded?()
    }

    // MARK: - Clear

    func clearOutput() {
        outputLines.removeAll()
        lastOutputLine = ""
        perScriptOutputLines.removeAll()
    }

    func clearOutput(for scriptId: String) {
        perScriptOutputLines[scriptId] = []
    }

    // MARK: - Output ingestion

    private func ingest(_ raw: String, key: String) {
        let stripped = stripAnsi(raw)
        let incoming = stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .controlCharacters) }
            .filter { !$0.isEmpty }

        outputLines.append(contentsOf: incoming)
        if outputLines.count > 1_000 { outputLines.removeFirst(outputLines.count - 1_000) }
        if let last = incoming.last { lastOutputLine = last }

        perScriptOutputLines[key, default: []].append(contentsOf: incoming)
        let perCount = perScriptOutputLines[key]?.count ?? 0
        if perCount > 1_000 {
            perScriptOutputLines[key]?.removeFirst(perCount - 1_000)
        }

        if case .running(let pid, nil) = scriptStates[key], let port = detectPort(in: stripped) {
            scriptStates[key] = .running(pid: pid, port: port)
        }
        if case .starting = scriptStates[key] {
            let pid = processes[key]?.processIdentifier ?? 0
            scriptStates[key] = .running(pid: pid, port: detectPort(in: stripped))
        }
    }

    // MARK: - Port detection

    private func detectPort(in text: String) -> Int? {
        let patterns = [
            #"(?:port|PORT)[:\s]+(\d{4,5})"#,
            #"https?://[^\s:]+:(\d{4,5})"#,
            #"localhost:(\d{4,5})"#,
            #"127\.0\.0\.1:(\d{4,5})"#,
            #"0\.0\.0\.0:(\d{4,5})"#,
            #":::(\d{4,5})"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: nsRange),
               match.numberOfRanges > 1,
               let portRange = Range(match.range(at: 1), in: text),
               let port = Int(text[portRange]),
               (1024...65535).contains(port) {
                return port
            }
        }
        return nil
    }

    // MARK: - ANSI stripping

    private func stripAnsi(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\x1B\[[0-9;]*[mGKHFJA-Z]"#) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    // MARK: - Cleanup

    private func cleanupHandles(key: String) {
        outHandles[key]?.readabilityHandler = nil
        errHandles[key]?.readabilityHandler = nil
        outHandles.removeValue(forKey: key)
        errHandles.removeValue(forKey: key)
        processes.removeValue(forKey: key)
    }
}
