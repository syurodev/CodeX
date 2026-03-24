import Foundation

// MARK: - Models

struct RunScript: Identifiable, Hashable {
    let id: String
    let name: String
    let command: String
    let source: ScriptSource
    let workingDirectory: URL

    enum ScriptSource: Hashable {
        case npm, deno, make, nx
    }
}

/// A named group of scripts, typically one per package in a monorepo.
struct RunScriptGroup: Identifiable {
    /// Relative path from project root, e.g. "." or "apps/web".
    let id: String
    /// Display name — package name or directory name.
    let name: String
    let scripts: [RunScript]
}

/// Top-level project kind returned by `ProjectScriptService.detect(in:)`.
enum DetectedProjectKind {
    case node(manager: String, [RunScript])
    case deno([RunScript])
    case makefile([RunScript])
    case cmake([RunScript])
    case unknown

    var scripts: [RunScript] {
        switch self {
        case .node(_, let s):              return s
        case .deno(let s), .makefile(let s), .cmake(let s): return s
        case .unknown:                     return []
        }
    }

    var managerLabel: String {
        switch self {
        case .node(let mgr, _): return mgr
        case .deno:             return "deno"
        case .makefile:         return "make"
        case .cmake:            return "cmake"
        case .unknown:          return ""
        }
    }

    var iconName: String {
        switch self {
        case .node(let mgr, _): return "\(mgr)-icon"
        case .deno:             return "deno-icon"
        case .makefile:         return "make-icon"
        case .cmake:            return "cmake-icon"
        case .unknown:          return ""
        }
    }
}

// MARK: - Service

enum ProjectScriptService {

    private enum MonorepoKind {
        case turbo([String])
        case pnpmWorkspace([String])
        case npmWorkspaces([String])
        case lerna([String])
        case nx
        case multiProject([URL])
    }

    private static let priorityOrder = [
        "dev", "start", "preview",
        "build", "test", "lint", "format",
        "clean", "deploy",
    ]

    // MARK: - Root detection

    static func detect(in root: URL) -> DetectedProjectKind {
        let fm = FileManager.default

        for name in ["deno.json", "deno.jsonc"] {
            let url = root.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path),
               let scripts = parseDenoScripts(at: url, workingDirectory: root),
               !scripts.isEmpty {
                return .deno(scripts)
            }
        }

        let pkgURL = root.appendingPathComponent("package.json")
        if fm.fileExists(atPath: pkgURL.path),
           let (manager, scripts) = parseNPMScripts(at: pkgURL, workingDirectory: root),
           !scripts.isEmpty {
            return .node(manager: manager, scripts)
        }

        let cmakeURL = root.appendingPathComponent("CMakeLists.txt")
        if fm.fileExists(atPath: cmakeURL.path) {
            return .cmake(cmakeScripts(in: root))
        }

        let makeURL = root.appendingPathComponent("Makefile")
        if fm.fileExists(atPath: makeURL.path) {
            let scripts = parseMakeTargets(at: makeURL, workingDirectory: root)
            if !scripts.isEmpty { return .makefile(scripts) }
        }

        return .unknown
    }

    // MARK: - Monorepo group detection

    /// Returns scripts grouped by package. Single-package projects return one group.
    /// Monorepos / multi-project folders return one group per package.
    static func detectGroups(in root: URL) -> [RunScriptGroup] {
        let fm = FileManager.default
        let rootKind = detect(in: root)

        // Non-node projects: no monorepo support
        guard case .node(_, _) = rootKind else {
            let scripts = rootKind.scripts
            if scripts.isEmpty { return [] }
            return [RunScriptGroup(id: ".", name: root.lastPathComponent, scripts: scripts)]
        }

        let rootManager = detectPackageManager(in: root)
        let rootScripts  = rootKind.scripts

        switch detectMonorepoKind(in: root, fm: fm) {

        case .nx:
            var groups = detectNxGroups(root: root)
            if !rootScripts.isEmpty {
                let rootName = packageName(at: root) ?? root.lastPathComponent
                groups.insert(RunScriptGroup(id: ".", name: rootName, scripts: rootScripts), at: 0)
            }
            return groups

        case .turbo(let patterns),
             .pnpmWorkspace(let patterns),
             .npmWorkspaces(let patterns),
             .lerna(let patterns):
            return buildMonorepoGroups(root: root, patterns: patterns,
                                       manager: rootManager, rootScripts: rootScripts)

        case .multiProject(let subDirs):
            return buildMultiProjectGroups(subDirs: subDirs, manager: rootManager)

        case nil:
            if rootScripts.isEmpty { return [] }
            let name = packageName(at: root) ?? root.lastPathComponent
            return [RunScriptGroup(id: ".", name: name, scripts: rootScripts)]
        }
    }

    // MARK: - MonorepoKind detection

    private static func detectMonorepoKind(in root: URL, fm: FileManager) -> MonorepoKind? {
        // Nx — highest priority (replaces npm-script model entirely)
        if fm.fileExists(atPath: root.appendingPathComponent("nx.json").path) {
            return .nx
        }
        // pnpm-workspace.yaml — parse actual patterns
        let pnpmYAML = root.appendingPathComponent("pnpm-workspace.yaml")
        if fm.fileExists(atPath: pnpmYAML.path) {
            let p = parsePnpmWorkspaceYAML(at: pnpmYAML)
            return .pnpmWorkspace(p.isEmpty ? ["apps/*", "packages/*"] : p)
        }
        // lerna.json
        let lernaURL = root.appendingPathComponent("lerna.json")
        if fm.fileExists(atPath: lernaURL.path) {
            return .lerna(parseLernaPackages(at: lernaURL))
        }
        // package.json workspaces (npm / yarn / bun)
        if let p = readPackageJSONWorkspaces(in: root), !p.isEmpty {
            return .npmWorkspaces(p)
        }
        // turbo.json alone — conventional fallback dirs
        if fm.fileExists(atPath: root.appendingPathComponent("turbo.json").path) {
            return .turbo(["apps/*", "packages/*", "services/*", "libs/*"])
        }
        // Multi-project folder
        if let subDirs = detectMultiProjectDirs(root: root) {
            return .multiProject(subDirs)
        }
        return nil
    }

    // MARK: - Group builders

    private static func buildMonorepoGroups(
        root: URL,
        patterns: [String],
        manager: String,
        rootScripts: [RunScript]
    ) -> [RunScriptGroup] {
        var groups: [RunScriptGroup] = []
        if !rootScripts.isEmpty {
            let rootName = packageName(at: root) ?? root.lastPathComponent
            groups.append(RunScriptGroup(id: ".", name: rootName, scripts: rootScripts))
        }
        for (relPath, pkgDir) in resolveGlobPatterns(patterns, root: root) {
            let pkgJSON = pkgDir.appendingPathComponent("package.json")
            guard let (_, scripts) = parseNPMScripts(at: pkgJSON, workingDirectory: pkgDir, manager: manager),
                  !scripts.isEmpty else { continue }
            let name = packageName(at: pkgDir) ?? pkgDir.lastPathComponent
            let unique = scripts.map { s in
                RunScript(id: "\(relPath)/\(s.id)", name: s.name, command: s.command,
                          source: s.source, workingDirectory: s.workingDirectory)
            }
            groups.append(RunScriptGroup(id: relPath, name: name, scripts: unique))
        }
        return groups
    }

    private static func buildMultiProjectGroups(subDirs: [URL], manager: String) -> [RunScriptGroup] {
        var groups: [RunScriptGroup] = []
        for dir in subDirs {
            let pkgJSON = dir.appendingPathComponent("package.json")
            guard let (_, scripts) = parseNPMScripts(at: pkgJSON, workingDirectory: dir, manager: manager),
                  !scripts.isEmpty else { continue }
            let relPath = dir.lastPathComponent
            let name    = packageName(at: dir) ?? relPath
            let unique  = scripts.map { s in
                RunScript(id: "\(relPath)/\(s.id)", name: s.name, command: s.command,
                          source: s.source, workingDirectory: s.workingDirectory)
            }
            groups.append(RunScriptGroup(id: relPath, name: name, scripts: unique))
        }
        return groups
    }

    // MARK: - Monorepo helpers

    private static func readPackageJSONWorkspaces(in root: URL) -> [String]? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("package.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let arr = json["workspaces"] as? [String] { return arr }
        if let obj = json["workspaces"] as? [String: Any],
           let pkgs = obj["packages"] as? [String] { return pkgs }
        return nil
    }

    private static func packageName(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("package.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String
        else { return nil }
        // Strip npm scope: @scope/name → name
        return name.split(separator: "/").last.map(String.init) ?? name
    }

    // MARK: - Workspace pattern resolution

    // MARK: - Glob pattern resolution

    /// Resolves workspace glob patterns to concrete (relPath, URL) pairs.
    /// Supports: `prefix/*`, `prefix/**`, `./prefix/*`, literal `prefix/name`, negation `!pattern`.
    static func resolveGlobPatterns(
        _ patterns: [String],
        root: URL
    ) -> [(relPath: String, url: URL)] {
        let includes = patterns.filter { !$0.hasPrefix("!") }
        let excludes = patterns.filter  {  $0.hasPrefix("!") }.map { String($0.dropFirst()) }

        var result: [(String, URL)] = []
        for raw in includes {
            // Normalise: strip leading "./"
            let pattern = raw.hasPrefix("./") ? String(raw.dropFirst(2)) : raw
            let segments = pattern.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            expandSegments(segments: segments, current: root, relPrefix: "", into: &result)
        }

        // Apply exclusions
        let filtered = result.filter { (relPath, _) in
            !excludes.contains { matchesGlob(relPath: relPath, pattern: $0) }
        }

        // Deduplicate by absolute path, preserve order
        var seen = Set<String>()
        return filtered.filter { seen.insert($0.1.path).inserted }
    }

    private static func expandSegments(
        segments: [String],
        current: URL,
        relPrefix: String,
        into result: inout [(String, URL)]
    ) {
        let fm = FileManager.default

        guard !segments.isEmpty else {
            // Leaf node — only include if it has a package.json
            if fm.fileExists(atPath: current.appendingPathComponent("package.json").path) {
                result.append((relPrefix.isEmpty ? current.lastPathComponent : relPrefix, current))
            }
            return
        }

        let head = segments[0]
        let tail = Array(segments.dropFirst())

        switch head {
        case "*":
            guard let entries = try? fm.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { return }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                else { continue }
                let nextRel = relPrefix.isEmpty ? entry.lastPathComponent
                                                : "\(relPrefix)/\(entry.lastPathComponent)"
                expandSegments(segments: tail, current: entry, relPrefix: nextRel, into: &result)
            }

        case "**":
            // Match at current level with remaining tail, then recurse one level
            expandSegments(segments: tail, current: current, relPrefix: relPrefix, into: &result)
            guard let entries = try? fm.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { return }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = entry.lastPathComponent
                guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      name != "node_modules", name != ".git", name != "dist"
                else { continue }
                let nextRel = relPrefix.isEmpty ? name : "\(relPrefix)/\(name)"
                // Keep `**` at head to continue deep traversal
                expandSegments(segments: segments, current: entry, relPrefix: nextRel, into: &result)
            }

        default:
            // Literal segment
            let next = current.appendingPathComponent(head)
            guard fm.fileExists(atPath: next.path) else { return }
            let nextRel = relPrefix.isEmpty ? head : "\(relPrefix)/\(head)"
            expandSegments(segments: tail, current: next, relPrefix: nextRel, into: &result)
        }
    }

    /// Simple glob match for exclusion patterns (supports `**/segment` and literal segment).
    private static func matchesGlob(relPath: String, pattern: String) -> Bool {
        let norm = pattern.hasPrefix("**/") ? String(pattern.dropFirst(3)) : pattern
        let components = relPath.split(separator: "/").map(String.init)
        return components.contains(norm) || relPath == norm
    }

    /// Relative path string from base to child URL.
    static func relativePathString(from base: URL, to child: URL) -> String {
        let basePath  = base.standardized.path
        let childPath = child.standardized.path
        guard childPath.hasPrefix(basePath) else { return child.lastPathComponent }
        var rel = String(childPath.dropFirst(basePath.count))
        if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
        return rel.isEmpty ? "." : rel
    }

    // MARK: - Multi-project folder detection

    /// Returns immediate subdirectories with their own `package.json` when the root
    /// has no monorepo config and at least 2 independent sub-projects are found.
    static func detectMultiProjectDirs(root: URL) -> [URL]? {
        let fm = FileManager.default
        let skip: Set<String> = ["node_modules", ".git", "dist", "build", ".cache", ".next", ".turbo"]

        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let subProjects = entries
            .filter { entry in
                let name = entry.lastPathComponent
                guard !skip.contains(name),
                      (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      fm.fileExists(atPath: entry.appendingPathComponent("package.json").path)
                else { return false }
                return true
            }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        return subProjects.count >= 2 ? subProjects : nil
    }

    // MARK: - Nx

    /// BFS over the workspace to find all `project.json` files, then maps each
    /// project's `targets` to `RunScript`s with `nx run <project>:<target>`.
    static func detectNxGroups(root: URL) -> [RunScriptGroup] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.appendingPathComponent("nx.json").path) else { return [] }

        let skipDirs: Set<String> = ["node_modules", ".git", "dist", "build", ".cache", ".nx", ".turbo"]
        var projectJSONPaths: [URL] = []
        var queue: [URL] = [root]

        // BFS — skip known heavy / non-source directories
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard let entries = try? fm.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { continue }
            for entry in entries {
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                if isDir {
                    guard !skipDirs.contains(entry.lastPathComponent) else { continue }
                    queue.append(entry)
                } else if entry.lastPathComponent == "project.json" {
                    projectJSONPaths.append(entry)
                }
            }
        }

        var groups: [RunScriptGroup] = []
        for projectJSONURL in projectJSONPaths.sorted(by: { $0.path < $1.path }) {
            guard let data = try? Data(contentsOf: projectJSONURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let targets = json["targets"] as? [String: Any]
            else { continue }

            let projectDir  = projectJSONURL.deletingLastPathComponent()
            let relPath     = relativePathString(from: root, to: projectDir)
            let projectName = (json["name"] as? String) ?? projectDir.lastPathComponent

            let scripts: [RunScript] = targets.keys.sorted().map { targetName in
                RunScript(
                    id:               "nx/\(relPath)/\(targetName)",
                    name:             targetName,
                    command:          "nx run \(projectName):\(targetName)",
                    source:           .nx,
                    workingDirectory: root   // Nx always runs from workspace root
                )
            }
            if !scripts.isEmpty {
                groups.append(RunScriptGroup(id: relPath, name: projectName, scripts: sorted(scripts)))
            }
        }
        return groups
    }

    // MARK: - Deno

    private static func parseDenoScripts(at url: URL, workingDirectory: URL) -> [RunScript]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasks = json["tasks"] as? [String: Any]
        else { return nil }

        let scripts = tasks.keys.map { key in
            RunScript(id: key, name: key, command: "deno task \(key)", source: .deno, workingDirectory: workingDirectory)
        }
        return sorted(scripts)
    }

    // MARK: - npm / package.json

    private static func parseNPMScripts(at url: URL, workingDirectory: URL, manager: String? = nil) -> (manager: String, scripts: [RunScript])? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: String]
        else { return nil }

        let resolvedManager = manager ?? detectPackageManager(in: url.deletingLastPathComponent())
        let result = scripts.keys.map { key in
            RunScript(id: key, name: key, command: "\(resolvedManager) run \(key)", source: .npm, workingDirectory: workingDirectory)
        }
        return (resolvedManager, sorted(result))
    }

    private static func detectPackageManager(in root: URL) -> String {
        let fm = FileManager.default
        let checks: [(String, String)] = [
            ("bun.lockb",       "bun"),
            ("bun.lock",        "bun"),
            ("pnpm-lock.yaml",  "pnpm"),
            ("yarn.lock",       "yarn"),
        ]
        // Walk up to 5 levels — handles monorepos where lockfile is at root
        var current = root
        for _ in 0..<5 {
            for (file, mgr) in checks {
                if fm.fileExists(atPath: current.appendingPathComponent(file).path) { return mgr }
            }
            let parent = current.deletingLastPathComponent()
            if parent == current { break }
            current = parent
        }
        return "npm"
    }

    private static func parsePnpmWorkspaceYAML(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var patterns: [String] = []
        var inPackagesBlock = false

        for rawLine in text.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#") else { continue }

            if trimmed == "packages:" && !rawLine.hasPrefix(" ") && !rawLine.hasPrefix("\t") {
                inPackagesBlock = true
                continue
            }

            if inPackagesBlock && !trimmed.isEmpty
                && !rawLine.hasPrefix(" ") && !rawLine.hasPrefix("\t")
                && trimmed != "packages:" {
                inPackagesBlock = false
            }

            if inPackagesBlock && trimmed.hasPrefix("-") {
                var value = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if (value.hasPrefix("'") && value.hasSuffix("'"))
                    || (value.hasPrefix("\"") && value.hasSuffix("\"")) {
                    value = String(value.dropFirst().dropLast())
                }
                if !value.isEmpty { patterns.append(value) }
            }
        }
        return patterns
    }

    private static func parseLernaPackages(at url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        if let packages = json["packages"] as? [String] { return packages }
        return ["packages/*"]
    }

    // MARK: - Makefile

    private static func parseMakeTargets(at url: URL, workingDirectory: URL) -> [RunScript] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var targets: [RunScript] = []
        for line in content.components(separatedBy: "\n") {
            guard let first = line.first, first.isLetter || first == "_" else { continue }
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !name.contains(" "), !name.contains(".") else { continue }
            targets.append(RunScript(id: "make:\(name)", name: name, command: "make \(name)", source: .make, workingDirectory: workingDirectory))
        }
        return sorted(targets)
    }

    // MARK: - CMake

    private static func cmakeScripts(in root: URL) -> [RunScript] {
        let presetsURL = root.appendingPathComponent("CMakePresets.json")
        if let data = try? Data(contentsOf: presetsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let presets = json["buildPresets"] as? [[String: Any]] {
            let scripts = presets.compactMap { preset -> RunScript? in
                guard let name = preset["name"] as? String else { return nil }
                return RunScript(id: "cmake-build:\(name)", name: "build:\(name)",
                                 command: "cmake --build --preset \(name)", source: .make,
                                 workingDirectory: root)
            }
            if !scripts.isEmpty { return sorted(scripts) }
        }
        return [
            RunScript(id: "cmake:configure", name: "configure", command: "cmake -B build",                          source: .make, workingDirectory: root),
            RunScript(id: "cmake:build",     name: "build",     command: "cmake --build build",                     source: .make, workingDirectory: root),
            RunScript(id: "cmake:install",   name: "install",   command: "cmake --install build",                   source: .make, workingDirectory: root),
            RunScript(id: "cmake:clean",     name: "clean",     command: "cmake --build build --target clean",      source: .make, workingDirectory: root),
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
