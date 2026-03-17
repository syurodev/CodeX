import Foundation
import AppKit
import STTextViewAppKit

/// Simple regex-based syntax highlighter for JavaScript/TypeScript
class SyntaxHighlighter {
    private let colors: XcodeSyntaxColors
    
    init(colors: XcodeSyntaxColors) {
        self.colors = colors
    }
    
    /// Apply syntax highlighting to text (only visible range for performance)
    func highlight(text: String, in textView: STTextView, range: NSRange? = nil) {
        let nsString = text as NSString
        let highlightRange = range ?? NSRange(location: 0, length: nsString.length)
        
        // Keywords
        let keywords = ["const", "let", "var", "function", "return", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "class", "extends", "import", "export", "from", "default", "async", "await", "try", "catch", "finally", "throw", "new", "this", "super", "static", "public", "private", "protected", "interface", "type", "enum", "namespace", "module", "declare", "readonly", "as", "typeof", "instanceof", "in", "of", "void", "null", "undefined", "true", "false"]

        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                    if let range = match?.range {
                        textView.addAttributes([.foregroundColor: colors.keyword], range: range)
                    }
                }
            }
        }

        // Strings (double quotes)
        if let regex = try? NSRegularExpression(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"") {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range {
                    textView.addAttributes([.foregroundColor: colors.string], range: range)
                }
            }
        }

        // Strings (single quotes)
        if let regex = try? NSRegularExpression(pattern: "'(?:[^'\\\\]|\\\\.)*'") {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range {
                    textView.addAttributes([.foregroundColor: colors.string], range: range)
                }
            }
        }

        // Template literals
        if let regex = try? NSRegularExpression(pattern: "`(?:[^`\\\\]|\\\\.)*`") {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range {
                    textView.addAttributes([.foregroundColor: colors.string], range: range)
                }
            }
        }

        // Numbers
        if let regex = try? NSRegularExpression(pattern: "\\b\\d+\\.?\\d*\\b") {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range {
                    textView.addAttributes([.foregroundColor: colors.number], range: range)
                }
            }
        }

        // Single-line comments
        if let regex = try? NSRegularExpression(pattern: "//.*$", options: .anchorsMatchLines) {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range {
                    textView.addAttributes([.foregroundColor: colors.comment], range: range)
                }
            }
        }

        // Multi-line comments
        if let regex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/") {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range {
                    textView.addAttributes([.foregroundColor: colors.comment], range: range)
                }
            }
        }

        // Functions (word followed by parenthesis)
        if let regex = try? NSRegularExpression(pattern: "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(") {
            regex.enumerateMatches(in: text, range: highlightRange) { match, _, _ in
                if let range = match?.range(at: 1) {
                    textView.addAttributes([.foregroundColor: colors.function], range: range)
                }
            }
        }
    }
}

