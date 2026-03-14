import Foundation

private enum PrettierLanguage: String {
    case javascript
    case typescript
    case unknown

    static func fromFileExtension(_ ext: String) -> PrettierLanguage {
        switch ext.lowercased() {
        case "js", "jsx": return .javascript
        case "ts", "tsx": return .typescript
        default: return .unknown
        }
    }
}

struct FormatResult {
    let url: URL
    let changed: Bool
    let stdout: String
    let stderr: String
}

final class CodeFormatService {
    /// Path to `prettier` executable. If nil, will try to resolve via /usr/bin/env prettier.
    var prettierPath: String?

    /// Config file names that Prettier recognises (checked walking up from project root).
    private static let prettierConfigNames: [String] = [
        ".prettierrc", ".prettierrc.json", ".prettierrc.js", ".prettierrc.cjs",
        ".prettierrc.mjs", ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.toml",
        "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs",
    ]

    init(prettierPath: String? = nil) {
        self.prettierPath = prettierPath
    }

    func isSupported(url: URL) -> Bool {
        PrettierLanguage.fromFileExtension(url.pathExtension) != .unknown
    }

    // MARK: - Config Detection

    /// Returns `true` when `root` (or any ancestor) contains a Prettier config.
    func hasPrettierConfig(in root: URL) -> Bool {
        var dir = root
        let fm = FileManager.default
        while dir.pathComponents.count > 1 {
            if Self.prettierConfigNames.contains(where: { fm.fileExists(atPath: dir.appendingPathComponent($0).path) }) {
                return true
            }
            let pkgJSON = dir.appendingPathComponent("package.json")
            if let data = try? Data(contentsOf: pkgJSON),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["prettier"] != nil {
                return true
            }
            dir = dir.deletingLastPathComponent()
        }
        return false
    }

    // MARK: - Flags

    /// Build Prettier CLI flags from `DefaultFormatConfig`.
    static func prettierFlags(for config: DefaultFormatConfig) -> [String] {
        [
            "--tab-width",      "\(config.tab_width)",
            "--print-width",    "\(config.print_width)",
            "--trailing-comma", config.trailing_comma.prettierValue,
            config.single_quote ? "--single-quote" : "--no-single-quote",
            config.semicolons   ? "--semi"          : "--no-semi",
            "--bracket-spacing",
            "--arrow-parens", "always",
        ]
    }

    // MARK: - Format

    /// Format a single file in-place using Prettier.
    @discardableResult
    func formatFile(at url: URL, workingDirectory: URL?, formatConfig: DefaultFormatConfig = DefaultFormatConfig()) throws -> FormatResult {
        guard PrettierLanguage.fromFileExtension(url.pathExtension) != .unknown else {
            return FormatResult(url: url, changed: false, stdout: "", stderr: "Unsupported file type")
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        let wd = workingDirectory ?? url.deletingLastPathComponent()
        process.currentDirectoryURL = wd

        let configFlags = hasPrettierConfig(in: wd) ? [] : Self.prettierFlags(for: formatConfig)

        if let custom = prettierPath, !custom.isEmpty {
            process.executableURL = URL(fileURLWithPath: custom)
            process.arguments = configFlags + ["--write", url.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["prettier"] + configFlags + ["--write", url.path]
        }

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return FormatResult(url: url, changed: process.terminationStatus == 0, stdout: stdout, stderr: stderr)
    }

    /// Format an entire project directory recursively for supported files.
    func formatProject(at root: URL, formatConfig: DefaultFormatConfig = DefaultFormatConfig()) -> [FormatResult] {
        var results: [FormatResult] = []
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        while let item = enumerator?.nextObject() as? URL {
            if (try? item.resourceValues(forKeys: Set(keys)).isDirectory) == true { continue }
            if isSupported(url: item) {
                do {
                    let res = try formatFile(at: item, workingDirectory: root, formatConfig: formatConfig)
                    results.append(res)
                } catch {
                    let res = FormatResult(url: item, changed: false, stdout: "", stderr: String(describing: error))
                    results.append(res)
                }
            }
        }
        return results
    }
}
