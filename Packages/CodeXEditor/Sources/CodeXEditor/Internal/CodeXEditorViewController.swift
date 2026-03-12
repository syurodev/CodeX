import AppKit
import CodeEditLanguages

/// Manages the full editor layout: scroll view, text view, and gutter.
/// This is the single source of truth for the editor's state within AppKit.
public final class CodeXEditorViewController: NSViewController {

    // MARK: - Callbacks (set by SwiftUI Coordinator)

    public var onTextChange: ((String) -> Void)?
    public var onStateChange: ((EditorState) -> Void)?

    // MARK: - Configuration

    public private(set) var configuration: EditorConfiguration = EditorConfiguration()

    // MARK: - Language

    private var _language: CodeLanguage = .default

    // MARK: - Views (internal so GutterView/CodeXTextView can access)

    private(set) var textView: CodeXTextView!
    private var scrollView: NSScrollView!
    private var gutterView: GutterView!
    private var minimapView: MinimapView!
    private var containerView: NSView!

    // MARK: - Syntax highlighting

    private let syntaxHighlighter = SyntaxHighlighter()

    // MARK: - Bracket matching

    private let bracketHighlighter = BracketMatchHighlighter()

    // MARK: - TextKit 2 stack

    private var contentStorage: NSTextContentStorage!
    private var layoutManager: NSTextLayoutManager!

    // MARK: - State

    private var _currentState: EditorState = EditorState()

    // MARK: - View Lifecycle

    public override func loadView() {
        containerView = NSView()
        containerView.wantsLayer = true
        view = containerView
        buildEditorStack()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        observeScroll()
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        layoutSubviews()
    }

    // MARK: - Build

    private func buildEditorStack() {
        contentStorage = NSTextContentStorage()
        layoutManager = NSTextLayoutManager()
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = true
        contentStorage.addTextLayoutManager(layoutManager)
        layoutManager.textContainer = container

        textView = CodeXTextView(frame: .zero, textContainer: container)
        textView.editorDelegate = self
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.contentView.postsBoundsChangedNotifications = true

        gutterView = GutterView()
        gutterView.textView = textView
        gutterView.scrollView = scrollView
        gutterView.autoresizingMask = [.height]
        gutterView.preferredWidthDidChange = { [weak self] _ in self?.layoutSubviews() }

        minimapView = MinimapView()
        minimapView.textView = textView
        minimapView.editorScrollView = scrollView
        minimapView.autoresizingMask = [.minXMargin, .height]

        containerView.addSubview(gutterView)
        containerView.addSubview(scrollView)
        containerView.addSubview(minimapView)

        applyConfiguration(configuration, force: true)
        syntaxHighlighter.attach(
            to: textView,
            language: _language,
            theme: configuration.theme,
            font: configuration.font
        )
    }

    // MARK: - Layout

    private func layoutSubviews() {
        let totalWidth  = view.bounds.width
        let totalHeight = view.bounds.height
        let cfg = configuration

        let gutterWidth: CGFloat = cfg.showLineNumbers
            ? gutterView.preferredWidth(for: lineCountInTextView())
            : 0
        let minimapWidth: CGFloat = cfg.showMinimap ? MinimapView.preferredWidth : 0
        let editorWidth = max(0, totalWidth - gutterWidth - minimapWidth)

        gutterView.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: totalHeight)
        scrollView.frame = NSRect(x: gutterWidth, y: 0, width: editorWidth, height: totalHeight)
        minimapView.frame = NSRect(x: gutterWidth + editorWidth, y: 0, width: minimapWidth, height: totalHeight)
        textView.textContainerInset = NSSize(width: 8, height: cfg.contentInsets.top)
        minimapView.syncFromEditor()
    }

    // MARK: - Public API

    public func applyConfiguration(_ newConfig: EditorConfiguration, force: Bool = false) {
        guard force || newConfig != configuration else { return }
        let old = configuration
        configuration = newConfig

        textView.configuration = newConfig
        gutterView.configuration = newConfig
        minimapView.configuration = newConfig

        containerView.layer?.backgroundColor = newConfig.useThemeBackground
            ? newConfig.theme.background.cgColor
            : nil

        gutterView.isHidden = !newConfig.showLineNumbers
        minimapView.isHidden = !newConfig.showMinimap

        if newConfig.wrapLines != old.wrapLines {
            textView.textContainer?.widthTracksTextView = true
            textView.isHorizontallyResizable = !newConfig.wrapLines
        }

        // Always re-apply highlighting: CodeXTextView.applyConfiguration wipes syntax
        // colours via setAttributes, but the NSTextStorageDelegate guard skips re-highlight
        // for attribute-only edits, so we must drive it here every time config changes.
        syntaxHighlighter.update(theme: newConfig.theme, font: newConfig.font, language: _language)

        layoutSubviews()
        gutterView.needsDisplay = true
        minimapView.syncFromEditor()
    }

    public func setLanguage(_ language: CodeLanguage) {
        guard language.id != _language.id else { return }
        _language = language
        syntaxHighlighter.attach(
            to: textView,
            language: language,
            theme: configuration.theme,
            font: configuration.font
        )
    }

    public func setText(_ text: String) {
        guard let storage = textView.textStorage else { return }
        guard storage.string != text else { return }
        bracketHighlighter.clearHighlights(in: textView)

        let cfg = configuration
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = cfg.lineHeight
        paragraphStyle.maximumLineHeight = cfg.lineHeight
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = cfg.tabStopWidth

        let baselineOffset = cfg.baselineOffset

        let attrs: [NSAttributedString.Key: Any] = [
            .font: cfg.font,
            .foregroundColor: cfg.theme.text,
            .paragraphStyle: paragraphStyle,
            .kern: cfg.kern,
            .baselineOffset: baselineOffset
        ]

        storage.beginEditing()
        storage.setAttributedString(NSAttributedString(string: text, attributes: attrs))
        storage.endEditing()

        updateLineCount()
        gutterView.needsDisplay = true
        minimapView.syncFromEditor()
    }

    public func applyState(_ state: EditorState) {
        if state.scrollPosition != _currentState.scrollPosition {
            scrollView.contentView.scroll(to: state.scrollPosition)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            minimapView.syncFromEditor()
        }
        if state.cursorPositions != _currentState.cursorPositions,
           let pos = state.cursorPositions.first,
           let offset = pos.offset(in: textView.string) {
            let range = NSRange(location: offset, length: 0)
            textView.setSelectedRanges([NSValue(range: range)], affinity: .downstream, stillSelecting: false)
            textView.scrollRangeToVisible(range)
        }
        _currentState = state
    }

    // MARK: - Scroll observation

    private func observeScroll() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func scrollViewDidScroll() {
        gutterView.handleScrollDidChange()
        minimapView.syncFromEditor()
        var newState = _currentState
        newState.scrollPosition = scrollView.contentView.bounds.origin
        guard newState != _currentState else { return }
        _currentState = newState
        onStateChange?(_currentState)
    }

    // MARK: - Helpers

    private func lineCountInTextView() -> Int {
        let text = textView.string as NSString
        var count = 1
        var pos = 0
        while pos < text.length {
            let range = text.range(of: "\n", options: [], range: NSRange(location: pos, length: text.length - pos))
            guard range.location != NSNotFound else { break }
            count += 1
            pos = range.location + range.length
        }
        return count
    }

    private func updateLineCount() {
        let count = lineCountInTextView()
        guard gutterView.lineCount != count else { return }
        gutterView.lineCount = count
        layoutSubviews()
    }

    private func cursorPositionFromSelection() -> CursorPosition {
        let location = textView.selectedRange().location
        let text = textView.string as NSString
        var line = 1, col = 1
        for i in 0..<min(location, text.length) {
            if text.character(at: i) == UInt16(("\n" as Character).asciiValue!) {
                line += 1; col = 1
            } else {
                col += 1
            }
        }
        return CursorPosition(line: line, column: col)
    }
}

// MARK: - CodeXTextViewDelegate

extension CodeXEditorViewController: CodeXTextViewDelegate {

    func textViewDidChangeText(_ textView: CodeXTextView) {
        onTextChange?(textView.string)
        updateLineCount()
        gutterView.needsDisplay = true
        minimapView.syncFromEditor()
    }

    func textViewDidChangeSelection(_ textView: CodeXTextView) {
        var newState = _currentState
        newState.cursorPositions = [cursorPositionFromSelection()]
        _currentState = newState
        onStateChange?(_currentState)
        gutterView.selectionDidChange()
        bracketHighlighter.update(in: textView)
    }
}
