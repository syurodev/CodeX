import AppKit
import STTextViewAppKit

/// NSViewController that manages STTextView
class STCodeEditorViewController: NSViewController {
    var text: String = ""
    var onTextChange: ((String) -> Void)?
    var onStateChange: ((EditorState) -> Void)?

    // LSP delegates
    weak var completionDelegate: (any CompletionDelegate)?
    weak var definitionDelegate: (any DefinitionDelegate)?

    var configuration: EditorConfiguration = EditorConfiguration(
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        theme: .dark
    ) {
        didSet {
            applyConfiguration()
        }
    }

    private var textView: STTextView!
    private var scrollView: NSScrollView!
    private var isProgrammaticUpdate = false
    private var highlighter: SyntaxHighlighter?
    private var diagnosticsRenderer: DiagnosticsRenderer?
    private var highlightTask: Task<Void, Never>?

    override func loadView() {
        textView = STTextView()
        textView.delegate = self

        scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        self.view = scrollView

        // Initialize diagnostics renderer
        diagnosticsRenderer = DiagnosticsRenderer(textView: textView)

        applyConfiguration()

        isProgrammaticUpdate = true
        textView.text = text
        isProgrammaticUpdate = false
    }

    func updateText(_ newText: String) {
        guard isViewLoaded, textView.text ?? "" != newText else { return }
        isProgrammaticUpdate = true
        textView.text = newText
        text = newText
        isProgrammaticUpdate = false
    }

    /// Restore scroll position
    func updateScrollPosition(_ position: CGPoint) {
        guard isViewLoaded else { return }
        scrollView.contentView.scroll(to: position)
    }

    /// Apply syntax highlighting to current text (debounced)
    private func applySyntaxHighlighting() {
        guard let text = textView.text, !text.isEmpty else { return }

        // Cancel previous task
        highlightTask?.cancel()

        // Debounce: wait 500ms before highlighting (longer delay for better performance)
        highlightTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                highlighter?.highlight(text: text, in: textView)
            }
        }
    }

    /// Update diagnostics decorations
    func updateDiagnostics(_ diagnostics: [Diagnostic]) {
        diagnosticsRenderer?.clearDiagnostics()
        diagnosticsRenderer?.applyDiagnostics(diagnostics)
    }

    /// Convert NSRange to line/column position
    private func cursorPosition(from location: Int, in text: String) -> CursorPosition {
        let nsString = text as NSString
        var line = 0
        var column = 0

        // Count lines up to location
        nsString.enumerateSubstrings(in: NSRange(location: 0, length: min(location, nsString.length)), options: .byLines) { _, _, range, _ in
            line += 1
            column = location - range.location
        }

        return CursorPosition(line: max(0, line), column: max(0, column))
    }

    /// Notify state changes (cursor position, scroll)
    private func notifyStateChange() {
        guard !isProgrammaticUpdate else { return }

        let text = textView.text ?? ""
        let selectedRanges = textView.textLayoutManager.textSelections.flatMap { $0.textRanges }

        // Get cursor positions from selections
        let cursorPositions = selectedRanges.map { textRange -> CursorPosition in
            let location = textView.textLayoutManager.offset(from: textView.textLayoutManager.documentRange.location, to: textRange.location)
            return cursorPosition(from: location, in: text)
        }

        // Get scroll position
        let scrollPosition = scrollView.contentView.bounds.origin

        let state = EditorState(
            cursorPositions: cursorPositions.isEmpty ? [CursorPosition()] : cursorPositions,
            scrollPosition: scrollPosition
        )

        onStateChange?(state)
    }

    private func applyConfiguration() {
        guard isViewLoaded else { return }

        // Font and colors
        textView.font = configuration.font
        textView.textColor = configuration.theme.text
        textView.backgroundColor = configuration.theme.background

        // Editing
        textView.isEditable = configuration.isEditable

        // Line numbers
        textView.showsLineNumbers = configuration.showLineNumbers

        // Current line highlight
        textView.highlightSelectedLine = configuration.showCurrentLineHighlight

        // Paragraph style: tab width, line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = configuration.tabStopWidth
        paragraphStyle.lineHeightMultiple = configuration.lineHeightMultiple
        textView.defaultParagraphStyle = paragraphStyle

        // Apply line height and letter spacing to existing text
        if let text = textView.text, !text.isEmpty {
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            textView.addAttributes([
                .kern: configuration.letterSpacing,
                .paragraphStyle: paragraphStyle
            ], range: fullRange)
        }

        // Initialize syntax highlighter based on theme
        let syntaxColors = configuration.theme.background.isDark ? XcodeSyntaxColors.dark : XcodeSyntaxColors.light
        highlighter = SyntaxHighlighter(colors: syntaxColors)

        // TODO: Syntax highlighting disabled temporarily for performance
        // Will migrate to tree-sitter for better performance
        // applySyntaxHighlighting()
    }
}

extension STCodeEditorViewController: STTextViewDelegate {
    /// Called when text content changes
    func textDidChange(_ notification: Notification) {
        guard !isProgrammaticUpdate else { return }
        let newText = textView.text ?? ""
        if text != newText {
            text = newText
            onTextChange?(newText)

            // TODO: Syntax highlighting disabled temporarily for performance
            // applySyntaxHighlighting()
        }

        // Notify cursor position change after text change
        notifyStateChange()
    }

    /// Called when selection changes (cursor moves)
    func textViewDidChangeSelection(_ notification: Notification) {
        notifyStateChange()
    }
}

// MARK: - NSColor Extension

extension NSColor {
    /// Check if color is dark
    var isDark: Bool {
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return false }
        let brightness = (rgbColor.redComponent * 299 + rgbColor.greenComponent * 587 + rgbColor.blueComponent * 114) / 1000
        return brightness < 0.5
    }
}

