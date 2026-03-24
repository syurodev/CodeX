//
//  CESourceEditorViewController.swift
//  CodeX
//
//  NSViewController wrapper for CodeEditSourceEditor
//

import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages

/// Wrapper around CodeEditSourceEditor's TextViewController
class CESourceEditorViewController: NSViewController {
    // MARK: - Properties
    
    private var textViewController: TextViewController!
    
    var text: String {
        textViewController.text
    }
    
    var language: CodeLanguage
    var configuration: EditorConfiguration
    var editorState: EditorState
    var diagnostics: [CodeX.Diagnostic] = []
    
    // MARK: - Callbacks
    
    var onTextChange: ((String) -> Void)?
    var onStateChange: ((EditorState) -> Void)?
    
    // MARK: - Delegates

    weak var completionDelegate: (any CodeSuggestionDelegate)? {
        didSet {
            textViewController?.completionDelegate = completionDelegate
        }
    }
    
    weak var definitionDelegate: (any JumpToDefinitionDelegate)? {
        didSet {
            textViewController?.jumpToDefinitionDelegate = definitionDelegate
        }
    }
    
    // MARK: - Init
    
    init(
        text: String,
        language: CodeLanguage,
        configuration: EditorConfiguration,
        editorState: EditorState,
        diagnostics: [CodeX.Diagnostic]
    ) {
        self.language = language
        self.configuration = configuration
        self.editorState = editorState
        self.diagnostics = diagnostics
        
        super.init(nibName: nil, bundle: nil)
        
        // Create CodeEditSourceEditor configuration
        let ceConfig = createSourceEditorConfiguration(from: configuration)

        // Create TextViewController
        let codeLanguage = mapLanguage(language)
        let cursorPositions = editorState.cursorPositions.map { cursor in
            CodeEditSourceEditor.CursorPosition(line: cursor.line, column: cursor.column)
        }
        
        textViewController = TextViewController(
            string: text,
            language: codeLanguage,
            configuration: ceConfig,
            cursorPositions: cursorPositions
        )
        
        // Pass initial diagnostics
        textViewController.diagnostics = diagnostics.map { mapDiagnostic($0) }
        
        // Setup notifications
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()

        // Set delegates
        textViewController.completionDelegate = completionDelegate
        textViewController.jumpToDefinitionDelegate = definitionDelegate

        // Add text view controller as child
        addChild(textViewController)
        view.addSubview(textViewController.view)
        textViewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            textViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            textViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: Notification.Name("com.CodeEdit.TextView.TextDidChangeNotification"),
            object: textViewController.textView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cursorDidUpdate),
            name: TextViewController.cursorPositionUpdatedNotification,
            object: textViewController
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollDidUpdate),
            name: TextViewController.scrollPositionDidUpdateNotification,
            object: textViewController
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFlashSymbol(_:)),
            name: Notification.Name("CodeX.FlashSymbolRange"),
            object: nil
        )
    }

    @objc private func handleFlashSymbol(_ notification: Notification) {
        guard let info = notification.userInfo,
              let line   = info["line"]   as? Int,
              let column = info["column"] as? Int,
              let length = info["length"] as? Int else { return }

        let text  = textViewController.text
        let lines = text.components(separatedBy: "\n")

        var offset = 0
        for i in 0..<min(line, lines.count) {
            offset += (lines[i] as NSString).length + 1 // +1 for \n
        }
        offset += column

        let nsRange = NSRange(location: offset, length: length)
        let fullLength = (text as NSString).length
        guard nsRange.location != NSNotFound,
              nsRange.location + nsRange.length <= fullLength else { return }

        let emphasis = Emphasis(
            range: nsRange,
            style: .standard,
            flash: true,
            inactive: false,
            selectInDocument: true
        )
        textViewController.textView.emphasisManager?.addEmphasis(emphasis, for: "symbolJump")
    }

    @objc private func cursorDidUpdate(_ notification: Notification) {
        let cePositions = textViewController.cursorPositions
        let newPositions = cePositions.map { pos in
            CodeX.CursorPosition(line: pos.start.line, column: pos.start.column)
        }

        if editorState.cursorPositions != newPositions {
            editorState.cursorPositions = newPositions
            onStateChange?(editorState)
        }
    }

    @objc private func scrollDidUpdate(_ notification: Notification) {
        let newScrollPosition = textViewController.scrollView.contentView.bounds.origin
        if editorState.scrollPosition != newScrollPosition {
            editorState.scrollPosition = newScrollPosition
            onStateChange?(editorState)
        }
    }

    @objc private func textDidChange(_ notification: Notification) {
        let newText = textViewController.text
        onTextChange?(newText)
    }
    
    // MARK: - Public Methods
    
    func setText(_ newText: String) {
        guard textViewController.text != newText else { return }
        print("🔴 [CESourceEditor] setText called — overwriting text! new.count=\(newText.count)")
        textViewController.text = newText
    }
    
    func updateConfiguration(_ config: EditorConfiguration) {
        configuration = config
        let ceConfig = createSourceEditorConfiguration(from: config)
        textViewController.configuration = ceConfig
    }
    
    func updateLanguage(_ lang: CodeLanguage) {
        language = lang
        textViewController.language = mapLanguage(lang)
    }
    
    func updateEditorState(_ state: EditorState) {
        editorState = state

        // Update cursors if they differ
        let currentPositions = textViewController.cursorPositions.map {
            CodeX.CursorPosition(line: $0.start.line, column: $0.start.column)
        }
        let currentScroll = textViewController.scrollView.contentView.bounds.origin

        if currentPositions != state.cursorPositions {
            let newCEPositions = state.cursorPositions.map {
                CodeEditSourceEditor.CursorPosition(line: $0.line, column: $0.column)
            }
            // Set cursor without scrollToVisible — scrollSelectionToVisible() is broken for
            // unrendered lines (selection.boundingRect stays .zero → while-loop exits immediately).
            textViewController.setCursorPositions(newCEPositions, scrollToVisible: false)

            // Scroll via scrollToRange which uses layoutManager.rectForOffset and forces layout
            if let target = state.cursorPositions.first {
                let offset = characterOffset(line: target.line, column: target.column)
                textViewController.textView.scrollToRange(NSRange(location: offset, length: 0), center: true)
            }
        } else if currentScroll != state.scrollPosition {
            // Only restore saved scroll position when cursor hasn't changed (e.g. tab switch)
            textViewController.scrollView.contentView.scroll(state.scrollPosition)
        }
    }

    /// Computes the UTF-16 character offset for a 1-indexed line/column pair.
    private func characterOffset(line: Int, column: Int) -> Int {
        let text = textViewController.text as NSString
        let lines = textViewController.text.components(separatedBy: "\n")
        var offset = 0
        for i in 0..<min(line - 1, lines.count) {
            offset += (lines[i] as NSString).length + 1 // +1 for \n
        }
        offset += max(0, column - 1)
        return min(offset, text.length)
    }
    
    func updateDiagnostics(_ newDiagnostics: [CodeX.Diagnostic]) {
        guard diagnostics != newDiagnostics else { return }
        diagnostics = newDiagnostics
        textViewController.diagnostics = newDiagnostics.map { mapDiagnostic($0) }
    }
    
    // MARK: - Helpers
    
    private func createSourceEditorConfiguration(from config: EditorConfiguration) -> SourceEditorConfiguration {
        let theme = mapTheme(config.theme)
        let appearance = SourceEditorConfiguration.Appearance(
            theme: theme,
            useThemeBackground: config.useThemeBackground,
            font: config.font,
            lineHeightMultiple: Double(config.lineHeightMultiple),
            letterSpacing: Double(config.letterSpacing),
            wrapLines: config.wrapLines,
            useSystemCursor: config.useSystemCursor,
            tabWidth: config.tabWidth
        )

        let behavior = SourceEditorConfiguration.Behavior(
            indentOption: .spaces(count: config.tabWidth)
        )

        let layout = SourceEditorConfiguration.Layout(
            contentInsets: config.contentInsets
        )

        return SourceEditorConfiguration(
            appearance: appearance,
            behavior: behavior,
            layout: layout
        )
    }


    private func toRGB(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return color }
        return rgb
    }

    private func mapDiagnostic(_ diag: CodeX.Diagnostic) -> CodeEditSourceEditor.Diagnostic {
        let ceSeverity: CodeEditSourceEditor.DiagnosticSeverity
        switch diag.severity {
        case .error: ceSeverity = .error
        case .warning: ceSeverity = .warning
        case .info: ceSeverity = .info
        case .hint: ceSeverity = .hint
        }
        let ceSource: CodeEditSourceEditor.DiagnosticSource
        switch diag.source {
        case .typescript(let code):    ceSource = .typescript(code: code)
        case .eslint(let rule):        ceSource = .eslint(rule: rule)
        case .biomeLint(let rule):     ceSource = .biomeLint(rule: rule)
        case .biomeFormat:             ceSource = .biomeFormat
        case .lsp(let s, let code):    ceSource = .lsp(source: s, code: code)
        case .unknown:                 ceSource = .unknown
        }
        return CodeEditSourceEditor.Diagnostic(
            range: diag.range,
            severity: ceSeverity,
            message: diag.message,
            source: ceSource
        )
    }

    private func mapTheme(_ theme: EditorTheme) -> CodeEditSourceEditor.EditorTheme {
        typealias Attr = CodeEditSourceEditor.EditorTheme.Attribute
        return CodeEditSourceEditor.EditorTheme(
            text: Attr(color: toRGB(theme.text)),
            insertionPoint: toRGB(theme.cursor),
            invisibles: Attr(color: toRGB(theme.gutterForeground)),
            background: toRGB(theme.background),
            lineHighlight: toRGB(theme.lineHighlight),
            selection: toRGB(theme.selection),
            keywords: Attr(color: toRGB(theme.keyword)),
            commands: Attr(color: toRGB(theme.function)),
            types: Attr(color: toRGB(theme.type)),
            attributes: Attr(color: toRGB(theme.variable)),
            variables: Attr(color: toRGB(theme.variable)),
            values: Attr(color: toRGB(theme.number)),
            numbers: Attr(color: toRGB(theme.number)),
            strings: Attr(color: toRGB(theme.string)),
            characters: Attr(color: toRGB(theme.string)),
            comments: Attr(color: toRGB(theme.comment))
        )
    }

    private func mapLanguage(_ lang: CodeLanguage) -> CodeEditLanguages.CodeLanguage {
        // Map CodeX language to CodeEditLanguages
        switch lang.id {
        case "javascript":
            return .javascript
        case "typescript":
            return .typescript
        default:
            return .default
        }
    }
}

