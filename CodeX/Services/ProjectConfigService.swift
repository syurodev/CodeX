import Foundation

// MARK: - Source

/// Identifies which project config file is currently active.
enum ProjectConfigSource {
    /// `.prettierrc` or `.prettierrc.json` — fully readable/writable JSON.
    case prettierJSON(url: URL)
    /// `package.json` with a `"prettier"` key.
    case prettierPackageJSON(url: URL)
    /// `.prettierrc.js`, YAML, TOML etc. — detectable but not writable.
    case prettierReadOnly(url: URL)
    /// `biome.json` / `biome.jsonc` — readable/writable JSON.
    case biomeJSON(url: URL)

    var isWritable: Bool {
        switch self {
        case .prettierJSON, .prettierPackageJSON, .biomeJSON: return true
        case .prettierReadOnly: return false
        }
    }

    var fileName: String {
        switch self {
        case .prettierJSON(let u), .prettierReadOnly(let u), .biomeJSON(let u): return u.lastPathComponent
        case .prettierPackageJSON: return "package.json"
        }
    }
}

struct ProjectConfigResult {
    let config: DefaultFormatConfig
    let source: ProjectConfigSource
}

// MARK: - Service

final class ProjectConfigService {
    static let shared = ProjectConfigService()
    private init() {}

    private static let prettierJSONNames    = [".prettierrc", ".prettierrc.json"]
    private static let prettierOtherNames   = [
        ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.mjs",
        ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.toml",
        "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs",
    ]
    private static let biomeNames           = ["biome.json", "biome.jsonc"]

    // MARK: - Read

    /// Tìm config file **chỉ trong project root** (không walk-up thư mục cha).
    /// Ưu tiên: Prettier JSON → package.json → Prettier read-only → Biome JSON.
    func readConfig(in root: URL) -> ProjectConfigResult? {
        let fm = FileManager.default

        // Prettier JSON (writable)
        for name in Self.prettierJSONNames {
            let url = root.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path), let cfg = parsePrettierJSON(at: url) {
                print("📐 [FormatConfig] Using Prettier config: \(url.path)")
                return ProjectConfigResult(config: cfg, source: .prettierJSON(url: url))
            }
        }
        // package.json "prettier" key
        let pkgURL = root.appendingPathComponent("package.json")
        if let cfg = parsePrettierPackageJSON(at: pkgURL) {
            print("📐 [FormatConfig] Using Prettier config from package.json: \(pkgURL.path)")
            return ProjectConfigResult(config: cfg, source: .prettierPackageJSON(url: pkgURL))
        }
        // Prettier non-JSON (read-only indicator)
        for name in Self.prettierOtherNames {
            let url = root.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) {
                print("📐 [FormatConfig] Detected read-only Prettier config: \(url.path) (cannot parse, controls disabled)")
                return ProjectConfigResult(config: DefaultFormatConfig(), source: .prettierReadOnly(url: url))
            }
        }
        // Biome JSON
        for name in Self.biomeNames {
            let url = root.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path), let cfg = parseBiomeJSON(at: url) {
                print("📐 [FormatConfig] Using Biome config: \(url.path)")
                return ProjectConfigResult(config: cfg, source: .biomeJSON(url: url))
            }
        }
        print("📐 [FormatConfig] No project config found in \(root.path) — using app defaults")
        return nil
    }

    // MARK: - Write

    func writeConfig(_ config: DefaultFormatConfig, to result: ProjectConfigResult) throws {
        switch result.source {
        case .prettierJSON(let url):        try writePrettierJSON(config, to: url)
        case .prettierPackageJSON(let url): try writePrettierPackageJSON(config, to: url)
        case .biomeJSON(let url):           try writeBiomeJSON(config, to: url)
        case .prettierReadOnly:             break
        }
    }
}

// MARK: - Prettier parse / write

private extension ProjectConfigService {

    func parsePrettierJSON(at url: URL) -> DefaultFormatConfig? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return prettierObject(json)
    }

    func parsePrettierPackageJSON(at url: URL) -> DefaultFormatConfig? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = root["prettier"] as? [String: Any] else { return nil }
        return prettierObject(obj)
    }

    func prettierObject(_ obj: [String: Any]) -> DefaultFormatConfig {
        var c = DefaultFormatConfig()
        if let v = obj["tabWidth"]      as? Int    { c.tab_width     = v }
        if let v = obj["printWidth"]    as? Int    { c.print_width   = v }
        if let v = obj["singleQuote"]   as? Bool   { c.single_quote  = v }
        if let v = obj["semi"]          as? Bool   { c.semicolons    = v }
        if let v = obj["trailingComma"] as? String { c.trailing_comma = TrailingCommaStyle(rawValue: v) ?? .es5 }
        return c
    }

    func writePrettierJSON(_ config: DefaultFormatConfig, to url: URL) throws {
        var obj: [String: Any] = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]) ?? [:]
        obj["tabWidth"]      = config.tab_width
        obj["printWidth"]    = config.print_width
        obj["singleQuote"]   = config.single_quote
        obj["semi"]          = config.semicolons
        obj["trailingComma"] = config.trailing_comma.prettierValue
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    func writePrettierPackageJSON(_ config: DefaultFormatConfig, to url: URL) throws {
        guard var root = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else { return }
        var obj = root["prettier"] as? [String: Any] ?? [:]
        obj["tabWidth"]      = config.tab_width
        obj["printWidth"]    = config.print_width
        obj["singleQuote"]   = config.single_quote
        obj["semi"]          = config.semicolons
        obj["trailingComma"] = config.trailing_comma.prettierValue
        root["prettier"] = obj
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Biome parse / write

private extension ProjectConfigService {

    func parseBiomeJSON(at url: URL) -> DefaultFormatConfig? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var c = DefaultFormatConfig()
        if let fmt = root["formatter"] as? [String: Any] {
            if let v = fmt["indentWidth"] as? Int { c.tab_width   = v }
            if let v = fmt["lineWidth"]   as? Int { c.print_width = v }
        }
        if let js   = root["javascript"]   as? [String: Any],
           let jsFmt = js["formatter"]    as? [String: Any] {
            if let v = jsFmt["quoteStyle"]     as? String { c.single_quote  = v == "single" }
            if let v = jsFmt["semicolons"]     as? String { c.semicolons    = v == "always" }
            if let v = jsFmt["trailingCommas"] as? String { c.trailing_comma = TrailingCommaStyle(rawValue: v) ?? .es5 }
        }
        return c
    }

    func writeBiomeJSON(_ config: DefaultFormatConfig, to url: URL) throws {
        guard var root = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else { return }
        var fmt = root["formatter"] as? [String: Any] ?? [:]
        fmt["indentWidth"] = config.tab_width
        fmt["lineWidth"]   = config.print_width
        root["formatter"]  = fmt

        var js    = root["javascript"] as? [String: Any] ?? [:]
        var jsFmt = js["formatter"]    as? [String: Any] ?? [:]
        jsFmt["quoteStyle"]     = config.single_quote ? "single" : "double"
        jsFmt["semicolons"]     = config.semicolons   ? "always" : "asNeeded"
        jsFmt["trailingCommas"] = config.trailing_comma.biomeValue
        js["formatter"]         = jsFmt
        root["javascript"]      = js

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}

