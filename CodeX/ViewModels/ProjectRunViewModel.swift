import Foundation

// MARK: - RunState

/// Lifecycle states for the currently-running script process.
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

    /// The detected listening port, if any.
    var port: Int? {
        if case .running(_, let p) = self { return p }
        return nil
    }

    /// Short status text for display in the toolbar.
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
    var selectedScript: RunScript?

    // MARK: Process state
    var runState: RunState = .idle
    /// Circular buffer of recent stdout/stderr lines (capped at 1 000).
    var outputLines: [String] = []
    /// The most-recent non-empty output line — used in the toolbar subtitle.
    var lastOutputLine: String = ""

    // MARK: Computed
    var scripts: [RunScript] { detectedKind.scripts }
    var hasScripts: Bool { !scripts.isEmpty }

    // MARK: Callbacks
    /// Called when the process exits naturally (not from an explicit `stop()` call).
    var onRunEnded: (() -> Void)?

    // MARK: Private
    private var projectRoot: URL?
    private var process: Process?
    private var outHandle: FileHandle?
    private var errHandle: FileHandle?

    // MARK: - Detect

    /// Call this whenever the user opens a new project folder.
    func detect(in root: URL) {
        stop()
        projectRoot = root
        outputLines.removeAll()
        lastOutputLine = ""

        let kind = ProjectScriptService.detect(in: root)
        detectedKind = kind
        selectedScript = kind.scripts.first
    }

    // MARK: - Run

    /// Start the currently-selected script. No-op if already running.
    func run() {
        guard let script = selectedScript, let root = projectRoot else { return }
        guard !runState.isRunning else { return }

        runState = .starting
        outputLines.removeAll()
        lastOutputLine = ""

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        // Use login shell so PATH includes nvm / brew / bun / etc.
        proc.executableURL      = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments          = ["-l", "-c", script.command]
        proc.currentDirectoryURL = root
        proc.standardOutput     = outPipe
        proc.standardError      = errPipe

        // Inherit environment + disable terminal colour codes
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"

        // GUI apps on macOS only receive a minimal PATH from launchd.
        // Prepend well-known user tool directories so bun / deno / nvm / cargo / brew
        // are found even when the shell profile hasn't been sourced.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths: [String] = [
            "\(home)/.bun/bin",                 // bun
            "\(home)/.deno/bin",                // deno
            "\(home)/.cargo/bin",               // rust / cargo
            "\(home)/.local/bin",               // pip --user, pipx, etc.
            "\(home)/.npm-global/bin",          // npm global (--prefix ~/.npm-global)
            "\(home)/go/bin",                   // go install
            "\(home)/.volta/bin",               // volta
            "\(home)/.nvm/versions/node/current/bin",  // nvm current (symlink)
            "/opt/homebrew/bin",                // homebrew (Apple Silicon)
            "/opt/homebrew/sbin",
            "/usr/local/bin",                   // homebrew (Intel) + misc
            "/usr/local/sbin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = extraPaths.joined(separator: ":") + ":" + currentPath

        proc.environment = env

        process   = proc
        outHandle = outPipe.fileHandleForReading
        errHandle = errPipe.fileHandleForReading

        // stdout
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.ingest(text) }
        }

        // stderr
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.ingest(text) }
        }

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cleanupHandles()
                guard !self.runState.isRunning else {
                    // Process exited while we still considered it running
                    let code = p.terminationStatus
                    self.runState = code == 0 ? .idle : .error("Exited \(code)")
                    self.onRunEnded?()   // notify observers (e.g. panel tab alive indicator)
                    return
                }
            }
        }

        do {
            try proc.run()
            runState = .running(pid: proc.processIdentifier, port: nil)
        } catch {
            runState = .error(error.localizedDescription)
            cleanupHandles()
        }
    }

    // MARK: - Stop

    func stop() {
        guard runState.isRunning else { return }
        process?.terminate()
        cleanupHandles()
        runState = .idle
    }

    // MARK: - Clear

    func clearOutput() {
        outputLines.removeAll()
        lastOutputLine = ""
    }

    // MARK: - Output ingestion

    private func ingest(_ raw: String) {
        // Strip ANSI escape sequences
        let stripped = stripAnsi(raw)

        let incoming = stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .controlCharacters) }
            .filter { !$0.isEmpty }

        outputLines.append(contentsOf: incoming)
        if outputLines.count > 1_000 { outputLines.removeFirst(outputLines.count - 1_000) }
        if let last = incoming.last { lastOutputLine = last }

        // Port detection: update once we have a concrete port
        if case .running(let pid, nil) = runState, let port = detectPort(in: stripped) {
            runState = .running(pid: pid, port: port)
        }

        // Transition starting → running on first output
        if case .starting = runState {
            let pid = process?.processIdentifier ?? 0
            runState = .running(pid: pid, port: detectPort(in: stripped))
        }
    }

    // MARK: - Port detection

    private func detectPort(in text: String) -> Int? {
        let patterns = [
            #"(?:port|PORT)[:\s]+(\d{4,5})"#,          // "port 3000", "PORT: 8080"
            #"https?://[^\s:]+:(\d{4,5})"#,            // "http://localhost:3000"
            #"localhost:(\d{4,5})"#,                    // "localhost:5173"
            #"127\.0\.0\.1:(\d{4,5})"#,                // "127.0.0.1:4000"
            #"0\.0\.0\.0:(\d{4,5})"#,                  // "0.0.0.0:8000"
            #":::(\d{4,5})"#,                           // ":::3000"
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

    private func cleanupHandles() {
        outHandle?.readabilityHandler = nil
        errHandle?.readabilityHandler = nil
        outHandle = nil
        errHandle = nil
        process   = nil
    }

}
