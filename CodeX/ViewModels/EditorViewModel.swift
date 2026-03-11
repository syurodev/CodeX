import AppKit
import Foundation
import CodeEditLanguages
import CodeXEditor
import SwiftUI

@MainActor
@Observable
class EditorViewModel {
    let settingsStore: SettingsStore
    var openDocuments: [EditorDocument] = []
    var currentDocumentID: UUID?

    var currentDocument: EditorDocument? {
        openDocuments.first(where: { $0.id == currentDocumentID })
    }

    var text: String {
        get { currentDocument?.text ?? "" }
        set {
            if let doc = currentDocument {
                doc.text = newValue
                syncTextWithLSP(url: doc.url, text: newValue)
                triggerLint(url: doc.url)
            }
        }
    }

    func documentTextChanged(id: UUID, newText: String) {
        if let index = openDocuments.firstIndex(where: { $0.id == id }) {
            syncTextWithLSP(url: openDocuments[index].url, text: newText)
            triggerLint(url: openDocuments[index].url)
        }
    }

    private var lspService: LanguageClientService?

    var editorState: EditorState {
        get { currentDocument?.editorState ?? EditorState() }
        set { currentDocument?.editorState = newValue }
    }

    var settings: EditorSettings {
        settingsStore.settings.editor
    }

    var language: CodeLanguage {
        currentDocument?.language ?? .default
    }

    // Cached config to avoid churn on every render (causes scroll jitter)
    private var _cachedConfig: EditorConfiguration?
    private var _cachedSettings: AppSettings?
    private var _cachedColorScheme: ColorScheme?
    private var _cachedTopContentInset: CGFloat?
    private var _cachedBottomContentInset: CGFloat?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func editorConfiguration(
        for colorScheme: ColorScheme,
        topContentInset: CGFloat = 8,
        bottomContentInset: CGFloat = 0
    ) -> EditorConfiguration {
        let top    = max(8, topContentInset)
        let bottom = max(0, bottomContentInset)
        let appSettings = settingsStore.settings
        let editorSettings = appSettings.editor

        if let cached = _cachedConfig,
           _cachedSettings == appSettings,
           _cachedColorScheme == colorScheme,
           _cachedTopContentInset == top,
           _cachedBottomContentInset == bottom {
            return cached
        }

        let config = EditorConfiguration(
            font:                editorSettings.resolved_font,
            lineHeightMultiple:  editorSettings.line_height_multiple,
            letterSpacing:       editorSettings.letter_spacing,
            tabWidth:            editorSettings.tab_width,
            wrapLines:           editorSettings.wrap_lines,
            isEditable:          true,
            useSystemCursor:     editorSettings.use_system_cursor,
            showLineNumbers:     editorSettings.show_line_numbers,
            showMinimap:         editorSettings.show_minimap,
            useThemeBackground:  editorSettings.use_theme_background,
            theme:               appSettings.editorTheme.resolvedTheme(for: colorScheme),
            contentInsets:       NSEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        )
        _cachedConfig = config
        _cachedSettings = appSettings
        _cachedColorScheme = colorScheme
        _cachedTopContentInset = top
        _cachedBottomContentInset = bottom
        return config
    }

    func invalidateConfigurationCache() {
        _cachedConfig = nil
        _cachedSettings = nil
        _cachedTopContentInset = nil
        _cachedBottomContentInset = nil
    }

    var cursorPosition: (line: Int, column: Int) {
        guard let cursor = editorState.cursorPositions.first else { return (1, 1) }
        return (cursor.line, cursor.column)
    }

    func openDocument(from url: URL, projectRoot: URL? = nil, using fileService: FileSystemService) {
        if let existingDoc = openDocuments.first(where: { $0.url == url }) {
            selectDocument(id: existingDoc.id)
            sendDidOpen(for: url)
            return
        }

        do {
            let content  = try fileService.readFileContents(at: url)
            let language = fileService.detectLanguage(for: url)
            let newDoc   = EditorDocument(url: url, text: content, language: language)
            openDocuments.append(newDoc)
            currentDocumentID = newDoc.id

            if lspService == nil {
                startLSP(for: url, projectRoot: projectRoot)
            } else {
                sendDidOpen(for: url)
            }

            selectDocument(id: newDoc.id)
        } catch {
            print("Failed to open document: \(error)")
        }
    }

    private func startLSP(for url: URL, projectRoot: URL? = nil) {
        let root = projectRoot ?? url.deletingLastPathComponent()
        guard let service = LSPManager.shared.startDenoLSP(projectRoot: root) else { return }
        self.lspService = service

        Task {
            if !service.isInitialized {
                let initParams: [String: Any] = [
                    "processId": ProcessInfo.processInfo.processIdentifier,
                    "rootUri": root.absoluteString,
                    "capabilities": [
                        "textDocument": [
                            "completion": ["completionItem": ["snippetSupport": true]],
                            "definition": ["dynamicRegistration": true],
                            "hover": ["contentFormat": ["markdown", "plaintext"]]
                        ],
                        "workspace": [
                            "configuration": true,
                            "didChangeConfiguration": ["dynamicRegistration": true]
                        ]
                    ],
                    "initializationOptions": [
                        "enable": true,
                        "lint": true,
                        "unstable": true,
                        "suggest": ["imports": ["hosts": ["https://deno.land": true]]],
                        "javascript": ["suggest": ["autoImports": true, "enabled": true], "preferences": ["importModuleSpecifier": "shortest"]],
                        "typescript": ["suggest": ["autoImports": true, "enabled": true], "preferences": ["importModuleSpecifier": "shortest"]]
                    ]
                ]
                let _ = await service.initialize(params: initParams)
            }
            sendDidOpen(for: url)
        }
    }

    private func sendDidOpen(for url: URL) {
        print("📝 Sending textDocument/didOpen for: \(url.lastPathComponent)")
        lspService?.sendNotification(method: "textDocument/didOpen", params: [
            "textDocument": [
                "uri": url.absoluteString,
                "languageId": "typescript",
                "version": 1,
                "text": text
            ]
        ])
    }

    private func syncTextWithLSP(url: URL, text: String) {
        lspService?.sendNotification(method: "textDocument/didChange", params: [
            "textDocument": ["uri": url.absoluteString, "version": 2],
            "contentChanges": [["text": text]]
        ])
    }

    private func triggerLint(url: URL) {
        Task {
            if let result = await BiomeService.shared.lint(fileURL: url) {
                print("Linter results: \(result)")
            }
        }
    }

    func selectDocument(id: UUID) {
        currentDocumentID = id
    }

    func closeDocument(id: UUID) {
        guard let index = openDocuments.firstIndex(where: { $0.id == id }) else { return }
        let wasCurrent = currentDocumentID == id
        openDocuments.remove(at: index)
        if wasCurrent {
            currentDocumentID = openDocuments.isEmpty ? nil : openDocuments[min(index, openDocuments.count - 1)].id
        }
    }

    func closeAllDocuments() {
        openDocuments.removeAll()
        currentDocumentID = nil
    }
}

// MARK: - CompletionDelegate

extension EditorViewModel: CompletionDelegate {
    var triggerCharacters: Set<String> {
        [".", "(", "\"", "'", "/", "@", "<"]
    }

    func completionSuggestionsRequested(
        at cursor: CursorPosition,
        in text: String
    ) async -> [any CompletionEntry]? {
        guard let lsp = lspService, let url = currentDocument?.url else { return nil }

        let params: [String: Any] = [
            "textDocument": ["uri": url.absoluteString],
            "position": ["line": cursor.line - 1, "character": cursor.column - 1]
        ]

        let _ = await lsp.sendRequest(method: "textDocument/completion", params: params)
        return [LSPSuggestionEntry(label: "exampleCompletion", detail: "LSP")]
    }

    func completionApplied(_ entry: any CompletionEntry, replacingRange range: NSRange) {
        if let entry = entry as? LSPSuggestionEntry {
            print("Applying completion: \(entry.label)")
        }
    }
}

// MARK: - DefinitionDelegate

extension EditorViewModel: DefinitionDelegate {
    func queryDefinition(
        forRange range: NSRange,
        cursor: CursorPosition,
        in text: String,
        url: URL?
    ) async -> [DefinitionLink]? {
        guard let lsp = lspService, let url = url ?? currentDocument?.url else { return nil }

        let params: [String: Any] = [
            "textDocument": ["uri": url.absoluteString],
            "position": ["line": cursor.line - 1, "character": cursor.column - 1]
        ]

        let response = await lsp.sendRequest(method: "textDocument/definition", params: params)

        var locations: [[String: Any]] = []
        if let dict = response as? [String: Any] {
            locations = [dict]
        } else if let array = response as? [[String: Any]] {
            locations = array
        } else if let array = response as? NSArray {
            for item in array { if let d = item as? [String: Any] { locations.append(d) } }
        }

        // Follow-through: if definition points to an import line in the same file, resolve the module
        if locations.count == 1,
           let loc = locations.first,
           let targetUri = (loc["uri"] as? String) ?? (loc["targetUri"] as? String),
           let targetURL = URL(string: targetUri),
           targetURL.standardizedFileURL.path == url.standardizedFileURL.path {

            let targetRange = (loc["targetSelectionRange"] as? [String: Any]) ?? (loc["range"] as? [String: Any])
            if let start = targetRange?["start"] as? [String: Any],
               let targetLine = start["line"] as? Int {
                let lines = text.components(separatedBy: "\n")
                if targetLine < lines.count {
                    let lineText = lines[targetLine].trimmingCharacters(in: .whitespaces)
                    let isImport = lineText.hasPrefix("import ") || lineText.hasPrefix("import{") || lineText.contains("require(")
                    if isImport,
                       let modulePath = extractModulePath(from: lines[targetLine]),
                       let resolved = resolveModulePath(modulePath, relativeTo: url) {
                        return [DefinitionLink(url: resolved.standardizedFileURL, line: 1, column: 1, label: resolved.lastPathComponent)]
                    }
                }
            }
        }

        return parseLocations(locations, currentURL: url)
    }

    func openLink(_ link: DefinitionLink) {
        guard let url = link.url else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("CodeX.OpenAndJump"),
            object: nil,
            userInfo: ["url": url, "line": link.line, "column": link.column]
        )
    }

    // MARK: Module path helpers

    private func extractModulePath(from lineText: String) -> String? {
        if let fromRange = lineText.range(of: "from") {
            if let path = extractQuotedString(from: String(lineText[fromRange.upperBound...])) { return path }
        }
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("import "), !trimmed.contains("from") {
            if let path = extractQuotedString(from: String(trimmed.dropFirst("import ".count))) { return path }
        }
        if let reqRange = lineText.range(of: "require(") {
            if let path = extractQuotedString(from: String(lineText[reqRange.upperBound...])) { return path }
        }
        return nil
    }

    private func extractQuotedString(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"['"]([^'"]+)['"]"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private func resolveModulePath(_ modulePath: String, relativeTo fileURL: URL) -> URL? {
        let dir = fileURL.deletingLastPathComponent()
        let extensions = [".ts", ".tsx", ".js", ".jsx", ".d.ts"]
        let indexFiles  = ["/index.ts", "/index.tsx", "/index.js", "/index.jsx"]
        if modulePath.hasPrefix(".") {
            return resolveWithExtensions(dir.appendingPathComponent(modulePath), extensions: extensions, indexFiles: indexFiles)
        }
        return resolveFromNodeModules(modulePath, startingFrom: dir, extensions: extensions, indexFiles: indexFiles)
    }

    private func resolveWithExtensions(_ base: URL, extensions: [String], indexFiles: [String]) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: base.path) {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: base.path, isDirectory: &isDir)
            if !isDir.boolValue { return base }
            for idx in indexFiles {
                let c = URL(fileURLWithPath: base.path + idx)
                if fm.fileExists(atPath: c.path) { return c }
            }
        }
        for ext in extensions {
            let c = URL(fileURLWithPath: base.path + ext)
            if fm.fileExists(atPath: c.path) { return c }
        }
        for idx in indexFiles {
            let c = URL(fileURLWithPath: base.path + idx)
            if fm.fileExists(atPath: c.path) { return c }
        }
        return nil
    }

    private func resolveFromNodeModules(_ modulePath: String, startingFrom dir: URL, extensions: [String], indexFiles: [String]) -> URL? {
        var current = dir
        let fm = FileManager.default
        while current.path != "/" {
            let pkgDir = current.appendingPathComponent("node_modules").appendingPathComponent(modulePath)
            if fm.fileExists(atPath: pkgDir.path) {
                let pkgJson = pkgDir.appendingPathComponent("package.json")
                if let data = fm.contents(atPath: pkgJson.path),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    for field in ["types", "typings", "main"] {
                        if let entry = json[field] as? String,
                           let resolved = resolveWithExtensions(pkgDir.appendingPathComponent(entry), extensions: extensions, indexFiles: indexFiles) {
                            return resolved
                        }
                    }
                }
                if let resolved = resolveWithExtensions(pkgDir, extensions: extensions, indexFiles: indexFiles) { return resolved }
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    private func parseLocations(_ locations: [[String: Any]], currentURL: URL) -> [DefinitionLink] {
        return locations.compactMap { loc -> DefinitionLink? in
            let uriString = (loc["uri"] as? String) ?? (loc["targetUri"] as? String)
            let rangeDict = (loc["range"] as? [String: Any]) ?? (loc["targetSelectionRange"] as? [String: Any]) ?? (loc["targetRange"] as? [String: Any])
            guard let uriString,
                  let uri = URL(string: uriString),
                  let rangeDict,
                  let start = rangeDict["start"] as? [String: Any],
                  let line = start["line"] as? Int,
                  let character = start["character"] as? Int else { return nil }

            let isSameFile = uri.standardizedFileURL.path == currentURL.standardizedFileURL.path
            return DefinitionLink(
                url: isSameFile ? nil : uri,
                line: line + 1,
                column: character + 1,
                label: uri.lastPathComponent,
                sourcePreview: "Jump to definition in \(uri.lastPathComponent)"
            )
        }
    }
}
