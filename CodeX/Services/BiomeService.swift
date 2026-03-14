import Foundation

/// BiomeService xử lý việc chạy Biome để lint và format code JS/TS.
class BiomeService {
    static let shared = BiomeService()

    // MARK: - Default config (written to /tmp, regenerated when settings change)

    /// URL of the temp default config. Located in /tmp so it never pollutes any project.
    private static let defaultConfigURL: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("codex-biome-default.json")

    /// Generate a Biome JSON config from `DefaultFormatConfig`.
    static func buildDefaultConfigJSON(from config: DefaultFormatConfig) -> String {
        let quoteStyle    = config.single_quote ? "single" : "double"
        let semicolons    = config.semicolons   ? "always" : "asNeeded"
        let trailingComma = config.trailing_comma.biomeValue
        let indentWidth   = config.tab_width
        let lineWidth     = config.print_width

        return """
        {
          "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
          "organizeImports": { "enabled": true },
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

    /// Writes (or overwrites) the temp default config from `formatConfig` and returns its path.
    private func defaultConfigPath(for formatConfig: DefaultFormatConfig) -> String {
        let url = Self.defaultConfigURL
        let json = Self.buildDefaultConfigJSON(from: formatConfig)
        try? json.write(to: url, atomically: true, encoding: .utf8)
        return url.path
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

    /// Chạy linter cho một file cụ thể.
    /// `projectRoot` được dùng để kiểm tra xem project có config không.
    func lint(fileURL: URL, projectRoot: URL? = nil, formatConfig: DefaultFormatConfig = DefaultFormatConfig()) async -> String? {
        guard let execPath = biomePath() else {
            print("❌ Biome binary not found")
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)

        let root = projectRoot ?? fileURL.deletingLastPathComponent()
        var args = ["lint", fileURL.path]
        if !hasBiomeConfig(in: root) {
            args = ["lint", "--config-path", defaultConfigPath(for: formatConfig), fileURL.path]
        }
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // suppress stderr noise

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Biome lint failed: \(error)")
            return nil
        }
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
