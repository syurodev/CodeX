import Foundation

/// BiomeService xử lý việc chạy Biome để lint và format code JS/TS.
class BiomeService {
    static let shared = BiomeService()

    // MARK: - Default config (written to /tmp, regenerated when settings change)

    /// Dedicated temp directory for our config — Biome's --config-path expects a directory.
    private static let defaultConfigDir: URL = {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("codex-biome-cfg", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Generate a Biome JSON config from `DefaultFormatConfig`.
    static func buildDefaultConfigJSON(from config: DefaultFormatConfig) -> String {
        let quoteStyle    = config.single_quote ? "single" : "double"
        let semicolons    = config.semicolons   ? "always" : "asNeeded"
        let trailingComma = config.trailing_comma.biomeValue
        let indentWidth   = config.tab_width
        let lineWidth     = config.print_width

        // Note: "organizeImports" was removed in Biome 2.x — omit it for compatibility
        return """
        {
          "linter": {
            "enabled": true,
            "rules": { "recommended": true }
          },
          "formatter": {
            "enabled": true,
            "indentStyle": "space",
            "indentWidth": \(indentWidth),
            "lineWidth": \(lineWidth)
          },
          "javascript": {
            "formatter": {
              "quoteStyle": "\(quoteStyle)",
              "trailingCommas": "\(trailingComma)",
              "semicolons": "\(semicolons)"
            }
          }
        }
        """
    }

    /// Config file names that Biome recognises.
    private static let biomeConfigNames = ["biome.json", "biome.jsonc"]

    private init() {}

    // MARK: - Config Detection

    /// Returns `true` when `projectRoot` (or any ancestor) has a biome config.
    func hasBiomeConfig(in projectRoot: URL) -> Bool {
        var dir = projectRoot
        let fm = FileManager.default
        while dir.pathComponents.count > 1 {
            if Self.biomeConfigNames.contains(where: { fm.fileExists(atPath: dir.appendingPathComponent($0).path) }) {
                return true
            }
            dir = dir.deletingLastPathComponent()
        }
        return false
    }

    /// Writes biome.json into the dedicated temp directory and returns the directory path.
    /// Biome's --config-path requires a directory, not a file path.
    private func defaultConfigPath(for formatConfig: DefaultFormatConfig) -> String {
        let fileURL = Self.defaultConfigDir.appendingPathComponent("biome.json")
        let json = Self.buildDefaultConfigJSON(from: formatConfig)
        try? json.write(to: fileURL, atomically: true, encoding: .utf8)
        return Self.defaultConfigDir.path
    }

    // MARK: - Executable

    /// Optional override path set by the app from ToolsSettings.biome_path.
    var customBiomePath: String = ""

    private func biomePath() -> String? {
        if !customBiomePath.isEmpty && FileManager.default.fileExists(atPath: customBiomePath) {
            return customBiomePath
        }
        if let bundlePath = Bundle.main.path(forResource: "biome", ofType: nil) {
            return bundlePath
        }
        let candidates = ["/opt/homebrew/bin/biome", "/usr/local/bin/biome"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Public API

    // MARK: Biome JSON output models
    private struct BiomeOutput: Decodable {
        let diagnostics: [BiomeDiagEntry]
    }
    private struct BiomeDiagEntry: Decodable {
        let severity: String
        let description: String
        let category: String?
        let location: BiomeLoc?
        struct BiomeLoc: Decodable {
            let span: [Int]?
        }
    }

    /// Chạy Biome để kiểm tra format + lint trên text in-memory.
    /// - Format: so sánh `biome format --stdin-file-path` output với original.
    /// - Lint: chạy `biome lint --stdin-file-path --reporter json` để lấy lint rules.
    func check(
        text: String,
        fileURL: URL,
        projectRoot: URL? = nil,
        formatConfig: DefaultFormatConfig = DefaultFormatConfig()
    ) async -> [Diagnostic] {
        _ = defaultConfigPath(for: formatConfig) // ensure biome.json written to temp dir
        async let formatDiags = checkFormat(text: text, fileURL: fileURL)
        async let lintDiags   = checkLint(text: text, fileURL: fileURL)
        let (fmt, lint) = await (formatDiags, lintDiags)
        let result = fmt + lint
        print("🧹 [Biome] format=\(fmt.count) lint=\(lint.count) total=\(result.count)")
        return result
    }

    // MARK: - Format check

    private func checkFormat(text: String, fileURL: URL) async -> [Diagnostic] {
        guard let execPath = biomePath() else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        let virtualPath = Self.defaultConfigDir.appendingPathComponent(fileURL.lastPathComponent).path
        process.arguments = ["format", "--stdin-file-path", virtualPath]

        let inputPipe = Pipe(); let outputPipe = Pipe()
        process.standardInput = inputPipe; process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            try inputPipe.fileHandleForWriting.write(contentsOf: Data(text.utf8))
            inputPipe.fileHandleForWriting.closeFile()
            // Use a DispatchQueue thread to block-wait so we don't starve the Swift cooperative thread pool.
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }
            guard process.terminationStatus != 0 else { return [] } // 0 = already formatted
            let formatted = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? text
            return formatDiagnostics(original: text, formatted: formatted)
        } catch { return [] }
    }

    /// Finds all lines that differ between original and formatted text, one diagnostic per line.
    private func formatDiagnostics(original: String, formatted: String) -> [Diagnostic] {
        let origLines = original.components(separatedBy: "\n")
        let fmtLines  = formatted.components(separatedBy: "\n")
        var diags: [Diagnostic] = []
        var offset = 0

        for i in 0..<max(origLines.count, fmtLines.count) {
            let origLine = i < origLines.count ? origLines[i] : nil
            let fmtLine  = i < fmtLines.count  ? fmtLines[i]  : nil
            let lineLen  = (origLine as NSString?)?.length ?? 0

            if origLine != fmtLine {
                let range = NSRange(location: offset, length: max(1, lineLen))
                let expected = fmtLine.map { "Expected: \($0.trimmingCharacters(in: .whitespaces))" } ?? "Line should be removed"
                diags.append(Diagnostic(range: range, severity: .warning,
                                        message: "Formatting issue. \(expected)",
                                        source: .biomeFormat))
            }
            offset += lineLen + 1 // +1 for \n
        }
        return diags
    }

    // MARK: - Lint check

    private func checkLint(text: String, fileURL: URL) async -> [Diagnostic] {
        guard let execPath = biomePath() else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        let virtualPath = Self.defaultConfigDir.appendingPathComponent(fileURL.lastPathComponent).path
        process.arguments = ["lint", "--stdin-file-path", virtualPath, "--reporter", "json"]

        let inputPipe = Pipe(); let outputPipe = Pipe()
        process.standardInput = inputPipe; process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            try inputPipe.fileHandleForWriting.write(contentsOf: Data(text.utf8))
            inputPipe.fileHandleForWriting.closeFile()
            // Use a DispatchQueue thread to block-wait so we don't starve the Swift cooperative thread pool.
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return parseLintJSON(data, sourceText: text)
        } catch { return [] }
    }

    private func parseLintJSON(_ data: Data, sourceText: String) -> [Diagnostic] {
        guard !data.isEmpty,
              let output = try? JSONDecoder().decode(BiomeOutput.self, from: data) else { return [] }

        let utf8  = sourceText.utf8
        let utf16 = sourceText.utf16

        return output.diagnostics.compactMap { entry in
            guard let span = entry.location?.span, span.count >= 2 else { return nil }
            let startByte = span[0]
            let endByte   = max(span[1], startByte + 1)
            guard startByte < utf8.count else { return nil }

            let clampedEnd = min(endByte, utf8.count)
            guard let startIdx = utf8.index(utf8.startIndex, offsetBy: startByte, limitedBy: utf8.endIndex),
                  let endIdx   = utf8.index(utf8.startIndex, offsetBy: clampedEnd, limitedBy: utf8.endIndex),
                  let startU16 = startIdx.samePosition(in: utf16),
                  let endU16   = endIdx.samePosition(in: utf16) else { return nil }

            let loc  = utf16.distance(from: utf16.startIndex, to: startU16)
            let len  = utf16.distance(from: startU16, to: endU16)
            let range = NSRange(location: loc, length: max(1, len))

            let severity: DiagnosticSeverity
            switch entry.severity.lowercased() {
            case "fatal", "error": severity = .error
            case "warning":        severity = .warning
            case "information":    severity = .info
            default:               severity = .hint
            }

            // "lint/suspicious/noDoubleEquals" → rule = "noDoubleEquals"
            let source: DiagnosticSource
            if let category = entry.category, !category.isEmpty {
                let rule = category.split(separator: "/").last.map(String.init) ?? category
                source = .biomeLint(rule: rule)
            } else {
                source = .biomeLint(rule: "lint")
            }

            return Diagnostic(range: range, severity: severity, message: entry.description, source: source)
        }
    }

    // MARK: - Workspace check

    // JSON models cho workspace check (multi-file output)
    private struct BiomeCheckOutput: Decodable {
        let diagnostics: [BiomeCheckDiagEntry]
    }
    private struct BiomeCheckDiagEntry: Decodable {
        let severity: String
        let description: String
        let category: String?
        let location: BiomeCheckLoc?
        struct BiomeCheckLoc: Decodable {
            let path: BiomeCheckPath?
            let span: [Int]?
            struct BiomeCheckPath: Decodable {
                let file: String?
            }
        }
    }

    /// Chạy `biome lint --reporter json <root>` trên toàn bộ workspace.
    /// Dùng `lint` thay vì `check` để đảm bảo cùng JSON format với per-file check.
    /// Trả về map `fileURL → [Diagnostic]` cho tất cả file có lỗi.
    func checkWorkspace(root: URL, formatConfig: DefaultFormatConfig = DefaultFormatConfig()) async -> [URL: [Diagnostic]] {
        guard let execPath = biomePath() else { return [:] }
        _ = defaultConfigPath(for: formatConfig)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = ["lint", "--reporter", "json", root.path]
        process.currentDirectoryURL = root

        let outputPipe = Pipe()
        let errorPipe  = Pipe()
        process.standardOutput = outputPipe
        process.standardError  = errorPipe

        do {
            try process.run()
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }
            // Biome viết JSON ra stdout; stderr chứa progress/human text
            let data    = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let exitCode = process.terminationStatus
            print("🧹 [BiomeWorkspace] exit=\(exitCode) stdout=\(data.count)B stderr=\(errData.count)B")

            if data.isEmpty && !errData.isEmpty {
                // Fallback: thử stderr
                return parseWorkspaceJSON(errData, root: root)
            }
            return parseWorkspaceJSON(data, root: root)
        } catch { return [:] }
    }

    private func parseWorkspaceJSON(_ data: Data, root: URL) -> [URL: [Diagnostic]] {
        guard !data.isEmpty,
              let output = try? JSONDecoder().decode(BiomeCheckOutput.self, from: data) else { return [:] }

        // Group entries by file path
        var grouped: [String: [BiomeCheckDiagEntry]] = [:]
        for entry in output.diagnostics {
            guard let filePath = entry.location?.path?.file else { continue }
            grouped[filePath, default: []].append(entry)
        }

        var result: [URL: [Diagnostic]] = [:]

        for (filePath, entries) in grouped {
            let fileURL = filePath.hasPrefix("/")
                ? URL(fileURLWithPath: filePath)
                : root.appendingPathComponent(filePath)

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let utf8  = content.utf8
            let utf16 = content.utf16

            let diags: [Diagnostic] = entries.compactMap { entry in
                guard let span = entry.location?.span, span.count >= 2 else { return nil }
                let startByte = span[0]
                let endByte   = max(span[1], startByte + 1)
                guard startByte < utf8.count else { return nil }

                let clampedEnd = min(endByte, utf8.count)
                guard let startIdx = utf8.index(utf8.startIndex, offsetBy: startByte, limitedBy: utf8.endIndex),
                      let endIdx   = utf8.index(utf8.startIndex, offsetBy: clampedEnd, limitedBy: utf8.endIndex),
                      let startU16 = startIdx.samePosition(in: utf16),
                      let endU16   = endIdx.samePosition(in: utf16) else { return nil }

                let loc  = utf16.distance(from: utf16.startIndex, to: startU16)
                let len  = utf16.distance(from: startU16, to: endU16)
                let range = NSRange(location: loc, length: max(1, len))

                let severity: DiagnosticSeverity
                switch entry.severity.lowercased() {
                case "fatal", "error": severity = .error
                case "warning":        severity = .warning
                case "information":    severity = .info
                default:               severity = .hint
                }

                let source: DiagnosticSource
                if let category = entry.category, !category.isEmpty {
                    let rule = category.split(separator: "/").last.map(String.init) ?? category
                    source = category.hasPrefix("format") ? .biomeFormat : .biomeLint(rule: rule)
                } else {
                    source = .biomeLint(rule: "lint")
                }

                return Diagnostic(range: range, severity: severity, message: entry.description, source: source)
            }

            if !diags.isEmpty {
                result[fileURL] = diags
            }
        }

        return result
    }

    /// Kept for backward-compat (formatter still uses this).
    func lint(fileURL: URL, projectRoot: URL? = nil, formatConfig: DefaultFormatConfig = DefaultFormatConfig()) async -> String? {
        return nil // superseded by check(text:fileURL:...)
    }

    /// Chạy formatter và trả về kết quả code đã được format.
    /// `projectRoot` được dùng để kiểm tra xem project có config không.
    func format(text: String, fileName: String, projectRoot: URL? = nil, formatConfig: DefaultFormatConfig = DefaultFormatConfig()) async -> String? {
        guard let execPath = biomePath() else {
            print("❌ Biome binary not found")
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)

        let root = projectRoot ?? URL(fileURLWithPath: NSHomeDirectory())
        var args = ["format", "--stdin-file-path", fileName]
        if !hasBiomeConfig(in: root) {
            args = ["format", "--config-path", defaultConfigPath(for: formatConfig), "--stdin-file-path", fileName]
        }
        process.arguments = args

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            try inputPipe.fileHandleForWriting.write(contentsOf: text.data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Biome format failed: \(error)")
            return nil
        }
    }
}
