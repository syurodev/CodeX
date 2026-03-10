import AppKit
import Foundation
import CodeEditSourceEditor
import CodeEditLanguages
import SwiftUI

@Observable
class EditorViewModel {
    var openDocuments: [EditorDocument] = []
    var currentDocumentID: UUID?
    
    var currentDocument: EditorDocument? {
        openDocuments.first(where: { $0.id == currentDocumentID })
    }

    // Computed property for compatibility with existing code using `viewModel.text`
    var text: String {
        get { currentDocument?.text ?? "" }
        set {
            if let doc = currentDocument {
                doc.text = newValue
                // Sync text với LSP
                syncTextWithLSP(url: doc.url, text: newValue)
                // Trigger linting
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
    
    var editorState: SourceEditorState {
        get { currentDocument?.editorState ?? SourceEditorState() }
        set {
            currentDocument?.editorState = newValue
        }
    }
    var settings = EditorSettings()

    var language: CodeLanguage {
        currentDocument?.language ?? .default
    }

    // Cached configuration để tránh tạo mới mỗi lần render (gây scroll jitter)
    private var _cachedConfig: SourceEditorConfiguration?
    private var _cachedColorScheme: ColorScheme?
    private var _cachedTopContentInset: CGFloat?
    private var _cachedBottomContentInset: CGFloat?

    func editorConfiguration(
        for colorScheme: ColorScheme,
        topContentInset: CGFloat = 8,
        bottomContentInset: CGFloat = 0
    ) -> SourceEditorConfiguration {
        let resolvedTopContentInset = max(8, topContentInset)
        let resolvedBottomContentInset = max(0, bottomContentInset)

        if let cached = _cachedConfig,
           _cachedColorScheme == colorScheme,
           _cachedTopContentInset == resolvedTopContentInset,
           _cachedBottomContentInset == resolvedBottomContentInset {
            return cached
        }
        let config = SourceEditorConfiguration(
            appearance: .init(
                theme: colorScheme == .dark ? CodeXTheme.default : CodeXTheme.light,
                useThemeBackground: settings.use_theme_background,
                font: settings.resolved_font,
                lineHeightMultiple: settings.line_height_multiple,
                letterSpacing: settings.letter_spacing,
                wrapLines: settings.wrap_lines,
                useSystemCursor: settings.use_system_cursor,
                tabWidth: settings.tab_width
            ),
            layout: .init(
                contentInsets: NSEdgeInsets(
                    top: resolvedTopContentInset,
                    left: 0,
                    bottom: resolvedBottomContentInset,
                    right: 0
                )
            ),
            peripherals: .init(
                showMinimap: settings.show_minimap
            )
        )
        _cachedConfig = config
        _cachedColorScheme = colorScheme
        _cachedTopContentInset = resolvedTopContentInset
        _cachedBottomContentInset = resolvedBottomContentInset
        return config
    }

    func invalidateConfigurationCache() {
        _cachedConfig = nil
        _cachedTopContentInset = nil
        _cachedBottomContentInset = nil
    }

    var cursorPosition: (line: Int, column: Int) {
        guard let cursor = editorState.cursorPositions?.first else {
            return (1, 1)
        }
        return (cursor.start.line, cursor.start.column)
    }

    func openDocument(from url: URL, projectRoot: URL? = nil, using fileService: FileSystemService) {
        if let existingDoc = openDocuments.first(where: { $0.url == url }) {
            selectDocument(id: existingDoc.id)
            // Gửi didOpen nếu LSP chưa biết file này
            sendDidOpen(for: url)
            return
        }

        do {
            let content = try fileService.readFileContents(at: url)
            let language = fileService.detectLanguage(for: url)
            let newDoc = EditorDocument(url: url, text: content, language: language)
            openDocuments.append(newDoc)
            
            self.currentDocumentID = newDoc.id
            
            if lspService == nil {
                startLSP(for: url, projectRoot: projectRoot)
            } else {
                // LSP đã chạy → gửi didOpen cho file mới
                sendDidOpen(for: url)
            }
            
            selectDocument(id: newDoc.id)
        } catch {
            print("Failed to open document: \(error)")
        }
    }

    private func startLSP(for url: URL, projectRoot: URL? = nil) {
        let root = projectRoot ?? url.deletingLastPathComponent()
        
        guard let service = LSPManager.shared.startDenoLSP(projectRoot: root) else {
            return
        }
        
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
                        "suggest": [
                            "imports": ["hosts": ["https://deno.land": true]]
                        ],
                        "javascript": [
                            "suggest": ["autoImports": true, "enabled": true],
                            "preferences": ["importModuleSpecifier": "shortest"]
                        ],
                        "typescript": [
                            "suggest": ["autoImports": true, "enabled": true],
                            "preferences": ["importModuleSpecifier": "shortest"]
                        ]
                    ]
                ]
                let _ = await service.initialize(params: initParams)
            }
            
            // TextDocument/didOpen cho file hiện tại
            sendDidOpen(for: url)
        }
    }
    
    // Tách riêng hàm gửi didOpen
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
            "textDocument": [
                "uri": url.absoluteString,
                "version": 2 // Cần quản lý version tốt hơn
            ],
            "contentChanges": [
                ["text": text]
            ]
        ])
    }

    private func triggerLint(url: URL) {
        Task {
            if let result = await BiomeService.shared.lint(fileURL: url) {
                print("Linter results: \(result)")
                // TODO: Parse result and update editor diagnostics
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
            if openDocuments.isEmpty {
                currentDocumentID = nil
            } else {
                let newIndex = min(index, openDocuments.count - 1)
                selectDocument(id: openDocuments[newIndex].id)
            }
        }
    }

    func closeAllDocuments() {
        openDocuments.removeAll()
        currentDocumentID = nil
    }
}

// MARK: - CodeSuggestionDelegate
extension EditorViewModel: CodeSuggestionDelegate {
    func completionTriggerCharacters() -> Set<String> {
        return [".", "(", "\"", "'", "/", "@", "<"]
    }

    func completionSuggestionsRequested(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) async -> (windowPosition: CursorPosition, items: [CodeSuggestionEntry])? {
        guard let lsp = lspService, let url = currentDocument?.url else { return nil }
        
        // Gửi request textDocument/completion tới LSP
        let params: [String: Any] = [
            "textDocument": ["uri": url.absoluteString],
            "position": [
                "line": cursorPosition.start.line - 1,
                "character": cursorPosition.start.column - 1
            ]
        ]
        
        let data = await lsp.sendRequest(method: "textDocument/completion", params: params)
        // TODO: Parse result and return LSPSuggestionEntry list
        return (cursorPosition, [LSPSuggestionEntry(label: "exampleCompletion", detail: "LSP")])
    }
    
    func completionOnCursorMove(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) -> [CodeSuggestionEntry]? {
        return nil
    }
    
    func completionWindowApplyCompletion(
        item: CodeSuggestionEntry,
        textView: TextViewController,
        cursorPosition: CursorPosition?
    ) {
        // Áp dụng text edit từ completion
        if let entry = item as? LSPSuggestionEntry {
            print("Applying completion: \(entry.label)")
        }
    }
}

// MARK: - JumpToDefinitionDelegate
extension EditorViewModel: JumpToDefinitionDelegate {
    func queryLinks(forRange range: NSRange, textView: TextViewController) async -> [JumpToDefinitionLink]? {
        print("🔍 queryLinks requested for range: \(range)")
        guard let lsp = lspService, let url = currentDocument?.url else { 
            print("⚠️ LSP or URL missing (lsp: \(lspService != nil), url: \(currentDocument?.url != nil))")
            return nil 
        }
        
        // Chuyển đổi NSRange sang CursorPosition để lấy line/column
        guard let resolvedPosition = textView.resolveCursorPosition(CursorPosition(range: range)) else {
            print("⚠️ Failed to resolve cursor position for range")
            return nil
        }

        let params: [String: Any] = [
            "textDocument": ["uri": url.absoluteString],
            "position": [
                "line": resolvedPosition.start.line - 1,
                "character": resolvedPosition.start.column - 1
            ]
        ]
        
        print("📡 Sending textDocument/definition to LSP: \(params)")
        let response = await lsp.sendRequest(method: "textDocument/definition", params: params)
        print("📥 LSP response for definition: \(String(describing: response))")
        
        // Parse response (Location | Location[] | LocationLink[])
        var locations: [[String: Any]] = []
        if let dict = response as? [String: Any] {
            locations = [dict]
        } else if let array = response as? [[String: Any]] {
            locations = array
        } else if let array = response as? NSArray {
            // Handle cases where it's returned as NSArray of NSDictionary
            for item in array {
                if let dict = item as? [String: Any] {
                    locations.append(dict)
                }
            }
        }
        
        print("📍 Found \(locations.count) locations")
        
        // Follow-through logic: nếu definition trỏ về import line cùng file → resolve module path thủ công
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
                    let isImportLine = lineText.hasPrefix("import ") || lineText.hasPrefix("import{") 
                        || lineText.contains("require(")
                    if isImportLine {
                        print("🔄 Definition points to import line, resolving module path...")
                        
                        if let modulePath = extractModulePath(from: lines[targetLine]),
                           let resolvedURL = resolveModulePath(modulePath, relativeTo: url) {
                            // Chuẩn hóa URL: loại bỏ ./  ../ segments
                            let normalizedURL = resolvedURL.standardizedFileURL
                            print("✅ Resolved import to: \(normalizedURL.path)")
                            let link = JumpToDefinitionLink(
                                url: normalizedURL,
                                targetRange: CursorPosition(line: 1, column: 1),
                                typeName: normalizedURL.lastPathComponent,
                                sourcePreview: "Jump to \(normalizedURL.lastPathComponent)",
                                documentation: nil
                            )
                            return [link]
                        }
                    }
                }
            }
        }
        
        return parseLocations(locations, currentURL: url)
    }
    
    /// Extract module path từ import/require statement
    /// Hỗ trợ: `import { X } from './path'`, `import './path'`, `require('path')`
    private func extractModulePath(from lineText: String) -> String? {
        // Pattern 1: import ... from 'path'
        if let fromRange = lineText.range(of: "from") {
            let afterFrom = String(lineText[fromRange.upperBound...])
            if let path = extractQuotedString(from: afterFrom) {
                return path
            }
        }
        
        // Pattern 2: import 'path' (side-effect import)
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("import ") && !trimmed.contains("from") {
            let afterImport = String(trimmed.dropFirst("import ".count))
            if let path = extractQuotedString(from: afterImport) {
                return path
            }
        }
        
        // Pattern 3: require('path')
        if let requireRange = lineText.range(of: "require(") {
            let afterRequire = String(lineText[requireRange.upperBound...])
            if let path = extractQuotedString(from: afterRequire) {
                return path
            }
        }
        
        return nil
    }
    
    /// Extract string trong quotes (single hoặc double)
    private func extractQuotedString(from text: String) -> String? {
        let pattern = #"['"]([^'"]+)['"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
    
    /// Resolve module path thành URL file thực tế
    /// Hỗ trợ: relative paths, bare imports (node_modules), scoped packages
    private func resolveModulePath(_ modulePath: String, relativeTo fileURL: URL) -> URL? {
        let dir = fileURL.deletingLastPathComponent()
        let extensions = [".ts", ".tsx", ".js", ".jsx", ".d.ts"]
        let indexFiles = ["/index.ts", "/index.tsx", "/index.js", "/index.jsx"]
        
        // Relative path (./ hoặc ../)
        if modulePath.hasPrefix(".") {
            let base = dir.appendingPathComponent(modulePath)
            return resolveWithExtensions(base, extensions: extensions, indexFiles: indexFiles)
        }
        
        // Bare import (node_modules) - ví dụ: @nestjs/common, dotenv
        return resolveFromNodeModules(modulePath, startingFrom: dir, extensions: extensions, indexFiles: indexFiles)
    }
    
    /// Thử resolve file path với các extension và index files
    private func resolveWithExtensions(_ base: URL, extensions: [String], indexFiles: [String]) -> URL? {
        if FileManager.default.fileExists(atPath: base.path) {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: base.path, isDirectory: &isDir)
            if !isDir.boolValue { return base }
            // Nếu là directory → thử index files
            for indexFile in indexFiles {
                let candidate = URL(fileURLWithPath: base.path + indexFile)
                if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        
        for ext in extensions {
            let candidate = URL(fileURLWithPath: base.path + ext)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        
        for indexFile in indexFiles {
            let candidate = URL(fileURLWithPath: base.path + indexFile)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        
        return nil
    }
    
    /// Resolve bare import từ node_modules (traverse up directories)
    private func resolveFromNodeModules(_ modulePath: String, startingFrom dir: URL, extensions: [String], indexFiles: [String]) -> URL? {
        var current = dir
        let fm = FileManager.default
        
        while current.path != "/" {
            let nodeModules = current.appendingPathComponent("node_modules")
            let packageDir = nodeModules.appendingPathComponent(modulePath)
            
            if fm.fileExists(atPath: packageDir.path) {
                // Thử đọc package.json để tìm entry point
                let packageJson = packageDir.appendingPathComponent("package.json")
                if let data = fm.contents(atPath: packageJson.path),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Ưu tiên: types → typings → main
                    for field in ["types", "typings", "main"] {
                        if let entry = json[field] as? String {
                            let entryURL = packageDir.appendingPathComponent(entry)
                            if let resolved = resolveWithExtensions(entryURL, extensions: extensions, indexFiles: indexFiles) {
                                return resolved
                            }
                        }
                    }
                }
                
                // Fallback: thử index files trong package dir
                if let resolved = resolveWithExtensions(packageDir, extensions: extensions, indexFiles: indexFiles) {
                    return resolved
                }
            }
            
            current = current.deletingLastPathComponent()
        }
        
        print("⚠️ Could not resolve module: \(modulePath)")
        return nil
    }
    
    /// Parse LSP locations thành JumpToDefinitionLink array
    private func parseLocations(_ locations: [[String: Any]], currentURL: URL) -> [JumpToDefinitionLink] {
        return locations.compactMap { loc -> JumpToDefinitionLink? in
            let uriString = (loc["uri"] as? String) ?? (loc["targetUri"] as? String)
            let rangeDict = (loc["range"] as? [String: Any]) ?? (loc["targetSelectionRange"] as? [String: Any]) ?? (loc["targetRange"] as? [String: Any])
            
            guard let uriString = uriString,
                  let uri = URL(string: uriString),
                  let rangeDict = rangeDict,
                  let start = rangeDict["start"] as? [String: Any],
                  let line = start["line"] as? Int,
                  let character = start["character"] as? Int else {
                print("⚠️ Failed to parse location: \(loc)")
                return nil
            }
            
            let targetRange = CursorPosition(line: line + 1, column: character + 1)
            let isSameFile = uri.standardizedFileURL.path == currentURL.standardizedFileURL.path
            
            let link = JumpToDefinitionLink(
                url: isSameFile ? nil : uri,
                targetRange: targetRange,
                typeName: uri.lastPathComponent,
                sourcePreview: "Jump to definition in \(uri.lastPathComponent)",
                documentation: nil
            )
            print("✅ Created link: \(link.label) at \(uri.lastPathComponent):\(line+1):\(character+1) (isSameFile: \(isSameFile))")
            return link
        }
    }
    
    func openLink(link: JumpToDefinitionLink) {
        print("🔗 openLink called for: \(link.url?.absoluteString ?? "Local") at line: \(link.targetRange.start.line)")
        guard let url = link.url else { return }
        
        // Link này trỏ tới file khác. 
        // Logic mở file này cần được xử lý ở cấp UI (vị trí có quyền access FileSystemService)
        // Ta dùng Notification hoặc Callback
        NotificationCenter.default.post(name: NSNotification.Name("CodeX.OpenAndJump"), object: nil, userInfo: [
            "url": url,
            "line": link.targetRange.start.line,
            "column": link.targetRange.start.column
        ])
    }
}

