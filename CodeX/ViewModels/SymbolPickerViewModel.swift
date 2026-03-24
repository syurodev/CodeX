import Foundation
import SwiftUI

@Observable
@MainActor
final class SymbolPickerViewModel {

    struct SymbolItem: Identifiable {
        let id = UUID()
        let name: String
        let detail: String?
        let kind: Int        // LSP SymbolKind
        let line: Int        // 0-indexed
        let column: Int      // 0-indexed
        let depth: Int

        var iconName: String {
            switch kind {
            case 5: "c.square.fill"
            case 6: "m.square.fill"
            case 9: "c.circle.fill"
            case 10: "e.square.fill"
            case 11: "i.square.fill"
            case 12: "f.cursive.circle.fill"
            case 13: "v.square.fill"
            case 14: "c.square"
            case 22: "e.circle.fill"
            case 23: "s.square.fill"
            default: "circle.fill"
            }
        }

        var iconColor: Color {
            switch kind {
            case 5, 11, 23: .purple
            case 6, 12: .orange
            case 7, 8, 13, 14: .blue
            case 10, 22: .green
            default: .gray
            }
        }

        var kindLabel: String {
            switch kind {
            case 5:  "class"
            case 6:  "method"
            case 9:  "constructor"
            case 10: "enum"
            case 11: "interface"
            case 12: "function"
            case 13: "variable"
            case 14: "constant"
            case 22: "enum member"
            case 23: "struct"
            case 25: "operator"
            case 26: "type"
            default: ""
            }
        }
    }

    var searchText: String = "" {
        didSet { updateResults() }
    }
    var results: [SymbolItem] = []
    var selectedIndex: Int = 0

    private var allSymbols: [SymbolItem] = []

    // MARK: - Load

    func load(from document: EditorDocument) {
        let ext = document.url.pathExtension.lowercased()
        let isJSTS = ["ts", "tsx", "js", "jsx"].contains(ext)

        if !document.symbols.isEmpty {
            let lspSymbols = flatten(document.symbols, depth: 0)
            if isJSTS {
                // Merge LSP + regex to catch methods LSP may miss
                let regexSymbols = parseRegex(text: document.text, fileURL: document.url)
                let lspNames = Set(lspSymbols.map { $0.name })
                let extra = regexSymbols.filter { !lspNames.contains($0.name) }
                var merged = lspSymbols
                merged.append(contentsOf: extra)
                allSymbols = merged.sorted(by: { $0.line < $1.line })
            } else {
                allSymbols = lspSymbols
            }
        } else {
            allSymbols = parseRegex(text: document.text, fileURL: document.url)
        }
        updateResults()
    }

    func reset() {
        searchText = ""
        selectedIndex = 0
    }

    // MARK: - Search

    func updateResults() {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else {
            results = allSymbols
            selectedIndex = 0
            return
        }
        results = allSymbols.filter { $0.name.lowercased().contains(query) }
        selectedIndex = 0
    }

    func selectNext() {
        guard !results.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
    }

    func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    var selectedItem: SymbolItem? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    // MARK: - Flatten LSP tree

    private func flatten(_ symbols: [DocumentSymbol], depth: Int) -> [SymbolItem] {
        var out: [SymbolItem] = []
        for sym in symbols {
            out.append(SymbolItem(
                name: sym.name,
                detail: sym.detail,
                kind: sym.kind,
                line: sym.selectionRange.start.line,
                column: sym.selectionRange.start.character,
                depth: depth
            ))
            if let children = sym.children {
                out += flatten(children, depth: depth + 1)
            }
        }
        return out
    }

    // MARK: - Regex fallback

    private struct LangPattern {
        let pattern: String
        let kind: Int
        let nameGroup: Int
    }

    private nonisolated static func patterns(for ext: String) -> [LangPattern] {
        switch ext {
        case "swift":
            return [
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+|static\s+|class\s+|override\s+)*func\s+(\w+)"#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+|open\s+)*class\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+)*struct\s+(\w+)"#, kind: 23, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+)*enum\s+(\w+)"#, kind: 10, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+)*protocol\s+(\w+)"#, kind: 11, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+|static\s+|lazy\s+)*var\s+(\w+)"#, kind: 13, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|internal\s+|static\s+)*let\s+(\w+)"#, kind: 14, nameGroup: 1),
                LangPattern(pattern: #"^\s*init\s*\("#, kind: 9, nameGroup: 0),
            ]
        case "py":
            return [
                LangPattern(pattern: #"^\s*def\s+(\w+)"#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*class\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*(\w+)\s*="#, kind: 13, nameGroup: 1),
            ]
        case "go":
            return [
                LangPattern(pattern: #"^\s*func\s+(?:\([^)]+\)\s+)?(\w+)"#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*type\s+(\w+)\s+struct"#, kind: 23, nameGroup: 1),
                LangPattern(pattern: #"^\s*type\s+(\w+)\s+interface"#, kind: 11, nameGroup: 1),
                LangPattern(pattern: #"^\s*type\s+(\w+)"#, kind: 26, nameGroup: 1),
                LangPattern(pattern: #"^\s*var\s+(\w+)"#, kind: 13, nameGroup: 1),
                LangPattern(pattern: #"^\s*const\s+(\w+)"#, kind: 14, nameGroup: 1),
            ]
        case "rs":
            return [
                LangPattern(pattern: #"^\s*(?:pub\s+)?(?:async\s+)?fn\s+(\w+)"#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:pub\s+)?struct\s+(\w+)"#, kind: 23, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:pub\s+)?enum\s+(\w+)"#, kind: 10, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:pub\s+)?trait\s+(\w+)"#, kind: 11, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:pub\s+)?impl(?:\s+\w+\s+for)?\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:pub\s+)?(?:let\s+mut|let|const)\s+(\w+)"#, kind: 14, nameGroup: 1),
            ]
        case "rb":
            return [
                LangPattern(pattern: #"^\s*def\s+(\w+)"#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*class\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*module\s+(\w+)"#, kind: 2, nameGroup: 1),
            ]
        case "kt", "kts":
            return [
                LangPattern(pattern: #"^\s*(?:public\s+|private\s+|protected\s+|override\s+|suspend\s+)*fun\s+(\w+)"#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:data\s+|sealed\s+|abstract\s+)?class\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:data\s+)?object\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*interface\s+(\w+)"#, kind: 11, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:val|var)\s+(\w+)"#, kind: 13, nameGroup: 1),
            ]
        case "java":
            return [
                LangPattern(pattern: #"^\s*(?:public|private|protected|static|final|abstract|synchronized|\s)*(?:void|int|String|boolean|[A-Z]\w*)\s+(\w+)\s*\("#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public|private|protected|\s)*(?:abstract\s+|final\s+)?class\s+(\w+)"#, kind: 5, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public|private|protected|\s)*interface\s+(\w+)"#, kind: 11, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:public|private|protected|\s)*enum\s+(\w+)"#, kind: 10, nameGroup: 1),
            ]
        case "ts", "tsx", "js", "jsx":
            return [
                // class methods: async/public/private/static/override combinations
                LangPattern(pattern: #"^\s*(?:(?:public|private|protected|static|override|abstract|async)\s+)*(?:async\s+)?(\w+)\s*(?:<[^>]*>)?\s*\("[^)]*\)\s*(?::\s*\S+\s*)?\{"#, kind: 6, nameGroup: 1),
                // standalone functions
                LangPattern(pattern: #"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+(\w+)"#, kind: 12, nameGroup: 1),
                // classes
                LangPattern(pattern: #"^\s*(?:export\s+)?(?:abstract\s+)?class\s+(\w+)"#, kind: 5, nameGroup: 1),
                // interfaces / type aliases
                LangPattern(pattern: #"^\s*(?:export\s+)?interface\s+(\w+)"#, kind: 11, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:export\s+)?type\s+(\w+)\s*="#, kind: 26, nameGroup: 1),
                // arrow functions and const/let/var
                LangPattern(pattern: #"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*(?::\s*\S+\s*)?=\s*(?:async\s*)?\("#, kind: 12, nameGroup: 1),
                LangPattern(pattern: #"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*="#, kind: 13, nameGroup: 1),
            ]
        default:
            return []
        }
    }

    private nonisolated static func parseRegex(text: String, fileURL: URL) -> [SymbolItem] {
        let ext = fileURL.pathExtension.lowercased()
        let langPatterns = patterns(for: ext)
        guard !langPatterns.isEmpty else { return [] }

        let lines = text.components(separatedBy: "\n")
        var items: [SymbolItem] = []

        for (lineIndex, line) in lines.enumerated() {
            for lp in langPatterns {
                guard let regex = try? NSRegularExpression(pattern: lp.pattern) else { continue }
                let nsLine = line as NSString
                let range = NSRange(location: 0, length: nsLine.length)
                guard let match = regex.firstMatch(in: line, range: range) else { continue }

                let name: String
                if lp.nameGroup > 0 && lp.nameGroup < match.numberOfRanges {
                    let nameRange = match.range(at: lp.nameGroup)
                    name = nameRange.location != NSNotFound ? nsLine.substring(with: nameRange) : "init"
                } else {
                    name = "init"
                }

                items.append(SymbolItem(
                    name: name,
                    detail: nil,
                    kind: lp.kind,
                    line: lineIndex,
                    column: 0,
                    depth: 0
                ))
                break // Only first match per line
            }
        }
        return items
    }

    private func parseRegex(text: String, fileURL: URL) -> [SymbolItem] {
        Self.parseRegex(text: text, fileURL: fileURL)
    }
}
