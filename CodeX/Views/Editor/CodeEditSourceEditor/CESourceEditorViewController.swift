//
//  CESourceEditorViewController.swift
//  CodeX
//
//  NSViewController wrapper for CodeEditSourceEditor
//

import AppKit
import CodeEditSourceEditor
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
    
    // MARK: - Callbacks
    
    var onTextChange: ((String) -> Void)?
    var onStateChange: ((EditorState) -> Void)?
    
    // MARK: - Delegates

    weak var completionDelegate: (any CodeSuggestionDelegate)?
    weak var definitionDelegate: (any JumpToDefinitionDelegate)?
    
    // MARK: - Init
    
    init(
        text: String,
        language: CodeLanguage,
        configuration: EditorConfiguration,
        editorState: EditorState
    ) {
        self.language = language
        self.configuration = configuration
        self.editorState = editorState
        
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
        
        // Setup notifications
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()

        print("🔵 [CESourceEditor] loadView - setting delegates")
        print("🔵 [CESourceEditor] completionDelegate: \(completionDelegate != nil)")
        print("🔵 [CESourceEditor] definitionDelegate: \(definitionDelegate != nil)")

        // Set delegates
        textViewController.completionDelegate = completionDelegate
        textViewController.jumpToDefinitionDelegate = definitionDelegate

        print("🔵 [CESourceEditor] textViewController.completionDelegate: \(textViewController.completionDelegate != nil)")
        print("🔵 [CESourceEditor] textViewController.jumpToDefinitionDelegate: \(textViewController.jumpToDefinitionDelegate != nil)")

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
        print("🔵 [CESourceEditor] setupNotifications - registering for text changes")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: Notification.Name("com.CodeEdit.TextView.TextDidChangeNotification"),
            object: textViewController.textView
        )
    }

    @objc private func textDidChange(_ notification: Notification) {
        let newText = textViewController.text
        print("🟢 [CESourceEditor] textDidChange FIRED - length: \(newText.count)")
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
        // TODO: Update cursor positions and scroll
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

        let layout = SourceEditorConfiguration.Layout(
            contentInsets: config.contentInsets
        )

        return SourceEditorConfiguration(appearance: appearance, layout: layout)
    }

    private func toRGB(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return color }
        return rgb
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

