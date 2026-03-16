import Foundation

// MARK: - Models

/// A single runnable script discovered in the project.
struct RunScript: Identifiable, Hashable {
    /// Stable unique key (e.g. "dev", "make:build").
    let id: String
    /// Human-readable label shown in the UI.
    let name: String
    /// Full shell command to execute (e.g. "npm run dev", "deno task start").
    let command: String
    /// The config file that declared this script.
    let source: ScriptSource

    enum ScriptSource: Hashable {
        case npm, deno, make
    }
}

/// Top-level project kind returned by `ProjectScriptService.detect(in:)`.
enum DetectedProjectKind {
    /// Node.js project — `manager` is the detected tool ("npm", "bun", "pnpm", "yarn").
    case node(manager: String, [RunScript])
    case deno([RunScript])
    case makefile([RunScript])
    case cmake([RunScript])
    case unknown

    var scripts: [RunScript] {
        switch self {
        case .node(_, let s):              return s
        case .deno(let s),
             .makefile(let s),
             .cmake(let s):               return s
        case .unknown:                     return []
        }
    }

    /// Short label (used as fallback when no icon is available).
    var managerLabel: String {
        switch self {
        case .node(let mgr, _): return mgr
        case .deno:             return "deno"
        case .makefile:         return "make"
        case .cmake:            return "cmake"
        case .unknown:          return ""
        }
    }

    /// Asset catalog image name for the package manager icon.
    /// Maps to `PackageManagers/<name>.imageset` in Assets.xcassets.
    var iconName: String {
        switch self {
        case .node(let mgr, _): return "\(mgr)-icon"   // bun-icon, npm-icon, …
        case .deno:             return "deno-icon"
        case .makefile:         return "make-icon"
        case .cmake:            return "cmake-icon"
        case .unknown:          return ""
        }
    }
}

// MARK: - Service

/// Stateless, pure-function service that detects the project type and
/// enumerates available run scripts in a given directory.
///
/// Detection priority: `deno.json` → `package.json` → `Makefile`
enum ProjectScriptService {

    // Scripts that appear early in the menu (in this order).
    private static let priorityOrder = [
        "dev", "start", "preview",
        "build", "test", "lint", "format",
        "clean", "deploy",
    ]

    // MARK: - Public API

    static func detect(in root: URL) -> DetectedProjectKind {
        let fm = FileManager.default

        // 1. deno.json / deno.jsonc
        for name in ["deno.json", "deno.jsonc"] {
            let url = root.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path),
               let scripts = parseDenoScripts(at: url),
               !scripts.isEmpty {
                return .deno(scripts)
            }
        }

        // 2. package.json
        let pkgURL = root.appendingPathComponent("package.json")
        if fm.fileExists(atPath: pkgURL.path),
           let (manager, scripts) = parseNPMScripts(at: pkgURL),
           !scripts.isEmpty {
            return .node(manager: manager, scripts)
        }

        // 3. CMakeLists.txt (check before Makefile — cmake projects often generate Makefiles)
        let cmakeURL = root.appendingPathComponent("CMakeLists.txt")
        if fm.fileExists(atPath: cmakeURL.path) {
            return .cmake(cmakeScripts(in: root))
        }

        // 4. Makefile
        let makeURL = root.appendingPathComponent("Makefile")
        if fm.fileExists(atPath: makeURL.path) {
            let scripts = parseMakeTargets(at: makeURL)
            if !scripts.isEmpty { return .makefile(scripts) }
        }

        return .unknown
    }

    // MARK: - Deno

    private static func parseDenoScripts(at url: URL) -> [RunScript]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasks = json["tasks"] as? [String: Any]
        else { return nil }

        let scripts = tasks.keys.map { key in
            RunScript(id: key, name: key, command: "deno task \(key)", source: .deno)
        }
        return sorted(scripts)
    }

    // MARK: - npm / package.json

    /// Returns `(manager, scripts)` so the caller can propagate the manager into
    /// `DetectedProjectKind.node` for correct badge display.
    private static func parseNPMScripts(at url: URL) -> (manager: String, scripts: [RunScript])? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: String]
        else { return nil }

        let manager = detectPackageManager(in: url.deletingLastPathComponent())
        let result = scripts.keys.map { key in
            RunScript(id: key, name: key, command: "\(manager) run \(key)", source: .npm)
        }
        return (manager, sorted(result))
    }

    /// Detects bun / pnpm / yarn / npm by looking for lockfiles.
    private static func detectPackageManager(in root: URL) -> String {
        let fm = FileManager.default
        let checks: [(String, String)] = [
            ("bun.lockb",       "bun"),
            ("bun.lock",        "bun"),
            ("pnpm-lock.yaml",  "pnpm"),
            ("yarn.lock",       "yarn"),
        ]
        for (file, mgr) in checks {
            if fm.fileExists(atPath: root.appendingPathComponent(file).path) { return mgr }
        }
        return "npm"
    }

    // MARK: - Makefile

    private static func parseMakeTargets(at url: URL) -> [RunScript] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var targets: [RunScript] = []

        for line in content.components(separatedBy: "\n") {
            // A target line looks like:   target-name: ...
            // Must start with a letter/underscore (skip .PHONY, variables, etc.)
            guard let first = line.first, first.isLetter || first == "_" else { continue }
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            // No spaces or dots in target name, and must be non-empty
            guard !name.isEmpty, !name.contains(" "), !name.contains(".") else { continue }
            targets.append(RunScript(id: "make:\(name)", name: name, command: "make \(name)", source: .make))
        }
        return sorted(targets)
    }

    // MARK: - CMake

    /// Returns cmake scripts. If `CMakePresets.json` exists, expose its build-preset
    /// names; otherwise fall back to the standard configure / build / install / clean flow.
    private static func cmakeScripts(in root: URL) -> [RunScript] {
        // Try CMakePresets.json first
        let presetsURL = root.appendingPathComponent("CMakePresets.json")
        if let data = try? Data(contentsOf: presetsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let presets = json["buildPresets"] as? [[String: Any]] {
            let scripts = presets.compactMap { preset -> RunScript? in
                guard let name = preset["name"] as? String else { return nil }
                return RunScript(
                    id: "cmake-build:\(name)",
                    name: "build:\(name)",
                    command: "cmake --build --preset \(name)",
                    source: .make
                )
            }
            if !scripts.isEmpty { return sorted(scripts) }
        }

        // Default cmake workflow
        return [
            RunScript(id: "cmake:configure", name: "configure",
                      command: "cmake -B build",            source: .make),
            RunScript(id: "cmake:build",     name: "build",
                      command: "cmake --build build",       source: .make),
            RunScript(id: "cmake:install",   name: "install",
                      command: "cmake --install build",     source: .make),
            RunScript(id: "cmake:clean",     name: "clean",
                      command: "cmake --build build --target clean", source: .make),
        ]
    }

    // MARK: - Sorting

    private static func sorted(_ scripts: [RunScript]) -> [RunScript] {
        scripts.sorted { a, b in
            let ai = priorityOrder.firstIndex(of: a.name) ?? Int.max
            let bi = priorityOrder.firstIndex(of: b.name) ?? Int.max
            if ai != bi { return ai < bi }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}
