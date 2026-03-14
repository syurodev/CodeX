import Foundation
import Observation
import CodeEditLanguages
import CodeXEditor

@Observable
class EditorDocument: Identifiable {
    let id: UUID
    let url: URL
    var text: String
    var language: CodeLanguage
    var isModified: Bool
    var editorState: EditorState
    
    // LSP Document Symbols
    var symbols: [DocumentSymbol] = []
    var isFetchingSymbols: Bool = false
    
    enum LSPStatus: Equatable {
        case off, starting, ready, error
    }
    var lspStatus: LSPStatus = .off

    var fileName: String { url.lastPathComponent }

    init(url: URL, text: String, language: CodeLanguage) {
        self.id = UUID()
        self.url = url
        self.text = text
        self.language = language
        self.isModified = false
        self.editorState = EditorState()
    }
    
    var currentSymbol: DocumentSymbol? {
        let currentLine = editorState.primaryCursor.line - 1 // LSP is 0-indexed
        let symbol = findSmallestSymbol(containingLine: currentLine, in: symbols)
        return symbol
    }
    
    private func findSmallestSymbol(containingLine line: Int, in symbols: [DocumentSymbol]) -> DocumentSymbol? {
        var smallest: DocumentSymbol? = nil
        
        for symbol in symbols {
            if line >= symbol.range.start.line && line <= symbol.range.end.line {
                // If this symbol contains the line, check its children for a more specific match
                if let children = symbol.children, !children.isEmpty {
                    if let childMatch = findSmallestSymbol(containingLine: line, in: children) {
                        return childMatch
                    }
                }
                
                // If no child was a better match, use this symbol
                if smallest == nil {
                    smallest = symbol
                } else if symbol.range.end.line - symbol.range.start.line < smallest!.range.end.line - smallest!.range.start.line {
                    // Choose the narrower scope if multiple overlap
                    smallest = symbol
                }
            }
        }
        
        return smallest
    }
    
    func fetchSymbolsIfSupported(projectRoot: URL) {
        let ext = url.pathExtension.lowercased()
        guard ["js", "jsx", "ts", "tsx"].contains(ext) else { 
            self.lspStatus = .off
            return 
        }
        
        guard !isFetchingSymbols else { return }
        isFetchingSymbols = true
        self.lspStatus = .starting
        
        Task {
            if let service = LSPManager.shared.startDenoLSP(projectRoot: projectRoot) {
                // Đợi một chút để LSP Server xử lý xong didOpen hoặc thay đổi
                try? await Task.sleep(for: .milliseconds(800))
                
                if let fetchedSymbols = await service.fetchDocumentSymbols(fileURL: url) {
                    await MainActor.run {
                        self.symbols = fetchedSymbols
                        self.isFetchingSymbols = false
                        self.lspStatus = .ready
                    }
                } else {
                    await MainActor.run {
                        self.isFetchingSymbols = false
                        self.lspStatus = .ready
                    }
                }
            } else {
                await MainActor.run {
                    self.isFetchingSymbols = false
                    self.lspStatus = .error
                }
            }
        }
    }
}
