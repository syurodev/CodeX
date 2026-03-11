import AppKit
import TextFormation
import TextStory

/// NSTextView subclass using TextKit 2 (NSTextLayoutManager).
///
/// TextStoring conformance (length, substring, applyMutation) is provided
/// automatically by TextStory's retroactive extension on NSTextView.
/// We only need to add TextInterface (selectedRange) for TextFormation filters.
final class CodeXTextView: NSTextView {

    var configuration: EditorConfiguration = EditorConfiguration() {
        didSet { applyConfiguration() }
    }

    weak var editorDelegate: CodeXTextViewDelegate?

    // MARK: - TextFormation

    private var textFilters: [Filter] = []

    // MARK: - Init

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        isRichText = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isGrammarCheckingEnabled = false
        isContinuousSpellCheckingEnabled = false
        allowsUndo = true
        usesFontPanel = false
        usesRuler = false
        isEditable = true
        isSelectable = true
    }

    // MARK: - Configuration

    func applyConfiguration() {
        let cfg = configuration
        isEditable = cfg.isEditable

        backgroundColor = cfg.useThemeBackground ? cfg.theme.background : .clear
        insertionPointColor = cfg.useSystemCursor ? .labelColor : cfg.theme.insertionPoint
        selectedTextAttributes = [.backgroundColor: cfg.theme.selection]
        textContainerInset = NSSize(width: 0, height: cfg.contentInsets.top)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = cfg.lineHeight
        paragraphStyle.maximumLineHeight = cfg.lineHeight
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = cfg.tabStopWidth
        paragraphStyle.lineBreakMode = cfg.wrapLines ? .byWordWrapping : .byClipping

        // Keep the selection/background rect at `cfg.lineHeight`, then shift the
        // glyphs upward using the optical compensation derived from the editor
        // configuration. This helps code sit more centrally within the selected
        // row instead of visually sticking to the bottom edge.
        let baselineOffset = cfg.baselineOffset

        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: cfg.font,
            .foregroundColor: cfg.theme.text,
            .paragraphStyle: paragraphStyle,
            .kern: cfg.kern,
            .baselineOffset: baselineOffset
        ]
        typingAttributes = defaultAttrs

        // Apply to existing content for live theme switching
        if let storage = textStorage, storage.length > 0 {
            storage.beginEditing()
            storage.setAttributes(defaultAttrs, range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }

        textFilters = makeFilters()
        needsDisplay = true
    }

    // MARK: - TextFormation Filters

    private func makeFilters() -> [Filter] {
        let pairs: [(String, String)] = [
            ("{", "}"), ("(", ")"), ("[", "]"),
            ("\"", "\""), ("'", "'"), ("`", "`")
        ]
        var filters: [Filter] = []
        // StandardOpenPairFilter already includes DeleteCloseFilter internally
        for (open, close) in pairs {
            filters.append(StandardOpenPairFilter(open: open, close: close))
        }
        filters.append(NewlineProcessingFilter())
        filters.append(TabSpaceReplacementFilter(tabWidth: configuration.tabWidth))
        return filters
    }

    // MARK: - Key interception for TextFormation

    override func shouldChangeText(
        in affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let string = replacementString, !textFilters.isEmpty else {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }
        // Don't interfere with undo/redo
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }

        let mutation = TextMutation(string: string, range: affectedCharRange, limit: length)
        let indentUnit = String(repeating: " ", count: configuration.tabWidth)
        let indenter = TextualIndenter(patterns: TextualIndenter.basicPatterns)
        let providers = WhitespaceProviders(
            leadingWhitespace: indenter.substitionProvider(
                indentationUnit: indentUnit,
                width: configuration.tabWidth
            ),
            trailingWhitespace: { _, _ in "" }
        )

        for filter in textFilters {
            switch filter.processMutation(mutation, in: self, with: providers) {
            case .none:    continue
            case .stop:    return true
            // Filter has already applied the modified text — tell AppKit to skip its own apply
            case .discard: return false
            }
        }

        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    // MARK: - TextInterface (selectedRange)
    // NSTextView already has selectedRange as a method; we expose it as a settable
    // property to satisfy the TextInterface protocol from TextFormation.
    // NOTE: Do NOT call setSelectedRange(_:) here — it maps to the same ObjC selector
    // as this property setter, causing infinite recursion. Use setSelectedRanges instead.
    override var selectedRange: NSRange {
        get { selectedRanges.first?.rangeValue ?? NSRange(location: 0, length: 0) }
        set { setSelectedRanges([NSValue(range: newValue)], affinity: .downstream, stillSelecting: false) }
    }

    // MARK: - Change notifications

    override func didChangeText() {
        super.didChangeText()
        editorDelegate?.textViewDidChangeText(self)
    }

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            editorDelegate?.textViewDidChangeSelection(self)
        }
    }
}

// MARK: - TextInterface (TextFormation)
// TextStoring (length, substring, applyMutation) is already provided by TextStory's
// retroactive conformance: extension NSTextView: TextStoring { ... }
// selectedRange must be in the main class body to allow `override`.

extension CodeXTextView: TextInterface {}

// MARK: - Delegate

protocol CodeXTextViewDelegate: AnyObject {
    func textViewDidChangeText(_ textView: CodeXTextView)
    func textViewDidChangeSelection(_ textView: CodeXTextView)
}
