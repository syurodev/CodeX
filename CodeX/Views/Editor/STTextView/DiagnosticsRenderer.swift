import AppKit
import STTextViewAppKit

/// Renders diagnostics (errors, warnings) in the editor
class DiagnosticsRenderer {
    private weak var textView: STTextView?
    
    init(textView: STTextView) {
        self.textView = textView
    }
    
    /// Apply diagnostics decorations to text
    func applyDiagnostics(_ diagnostics: [Diagnostic]) {
        guard let textView = textView, let text = textView.text else { return }
        let nsString = text as NSString
        
        for diagnostic in diagnostics {
            let range = diagnostic.range
            guard range.location >= 0 && range.location + range.length <= nsString.length else { continue }
            
            // Underline color based on severity
            let color: NSColor
            switch diagnostic.severity {
            case .error:
                color = .systemRed
            case .warning:
                color = .systemOrange
            case .info:
                color = .systemBlue
            case .hint:
                color = .systemGray
            }
            
            // Apply wavy underline
            textView.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: color
            ], range: range)
        }
    }
    
    /// Clear all diagnostic decorations
    func clearDiagnostics() {
        guard let textView = textView, let text = textView.text else { return }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        textView.removeAttribute(.underlineStyle, range: fullRange)
        textView.removeAttribute(.underlineColor, range: fullRange)
    }
}

