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

    // MARK: - Background drawing (current line highlight + indent guides)

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        let cfg = configuration
        guard let tlm = textLayoutManager,
              let tcs = textContentStorage else { return }

        let origin = textContainerOrigin

        // Current line highlight — only when there is no active selection so
        // it does not compete with or obscure the selection background.
        if cfg.showCurrentLineHighlight && selectedRange.length == 0 {
            let cursorOffset = selectedRange.location
            if let cursorLoc = tcs.location(tcs.documentRange.location, offsetBy: cursorOffset),
               let fragment = tlm.textLayoutFragment(for: cursorLoc) {
                let fFrame = fragment.layoutFragmentFrame
                let highlightRect = CGRect(
                    x: 0,
                    y: fFrame.minY + origin.y,
                    width: bounds.width,
                    height: fFrame.height
                )
                cfg.theme.lineHighlight.setFill()
                highlightRect.fill()
            }
        }

        // Indentation guides — vertical segments and branching curves
        if cfg.showIndentGuides {
            // Per-character advance including inter-character kern.
            let charWidth   = (" " as NSString).size(withAttributes: [.font: cfg.font]).width
            let charAdvance = charWidth + cfg.kern
            let tabPx       = charAdvance * CGFloat(cfg.tabWidth)
            let guideColor  = cfg.theme.indentGuide
            let content     = string as NSString

            tlm.enumerateTextLayoutFragments(
                from: tcs.documentRange.location,
                options: [.ensuresLayout, .ensuresExtraLineFragment]
            ) { fragment in
                let fragMinY = fragment.layoutFragmentFrame.minY + origin.y
                let fragMaxY = fragment.layoutFragmentFrame.maxY + origin.y
                let fragH    = fragment.layoutFragmentFrame.height

                // Cull fragments outside the dirty rect
                guard fragMinY < rect.maxY + 50 else { return false }
                guard fragMaxY > rect.minY - 50 else { return true }

                guard let textRange = fragment.textElement?.elementRange else { return true }
                let start = tcs.offset(from: tcs.documentRange.location, to: textRange.location)
                let end   = tcs.offset(from: tcs.documentRange.location, to: textRange.endLocation)
                guard start != NSNotFound, end != NSNotFound, start < content.length else { return true }

                let len      = min(end - start, content.length - start)
                guard len > 0 else { return true }
                let lineText = content.substring(with: NSRange(location: start, length: len))

                // 1. Calculate indent level. If empty/whitespace-only, use contextual indent.
                let leadingSpaces: Int
                let isWhitespaceOnly = lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if isWhitespaceOnly {
                    leadingSpaces = findContextualIndent(at: start, in: content, tabWidth: cfg.tabWidth)
                } else {
                    var count = 0
                    for ch in lineText {
                        if ch == " "  { count += 1 }
                        else if ch == "\t" { count += cfg.tabWidth }
                        else { break }
                    }
                    leadingSpaces = count
                }

                let levels = leadingSpaces / cfg.tabWidth
                guard levels > 0 else { return true }

                let glyphStartX = fragment.textLineFragments.first?.glyphOrigin.x ?? 0
                let baseX = origin.x + glyphStartX

                guideColor.setStroke()
                guideColor.setFill()

                let nextIndentSpaces = findNextIndent(after: end, in: content, tabWidth: cfg.tabWidth)
                let nextLevels = nextIndentSpaces / cfg.tabWidth
                
                let loopEnd = max(levels, nextLevels)
                for level in 0..<loopEnd {
                    let x = baseX + CGFloat(level) * tabPx
                    let continuesDown = nextLevels > level
                    
                    if isWhitespaceOnly {
                        if continuesDown {
                            let p = NSBezierPath()
                            p.lineWidth = 1.5
                            p.setLineDash([3, 3], count: 2, phase: 0)
                            p.move(to: NSPoint(x: x, y: fragMinY))
                            p.line(to: NSPoint(x: x, y: fragMaxY))
                            p.stroke()
                        }
                        continue
                    }
                    
                    if level < levels - 1 {
                        // Case A: Passthrough parent guide
                        if continuesDown {
                            let p = NSBezierPath()
                            p.lineWidth = 1.5
                            p.setLineDash([3, 3], count: 2, phase: 0)
                            p.move(to: NSPoint(x: x, y: fragMinY))
                            p.line(to: NSPoint(x: x, y: fragMaxY))
                            p.stroke()
                        }
                    } else if level == levels - 1 {
                        // Case B: The horizontal branch for the current text
                        let path = NSBezierPath()
                        path.lineWidth = 1.5
                        path.setLineDash([3, 3], count: 2, phase: 0)
                        
                        let startY = fragMinY
                        let heightToUse = fragment.textLineFragments.first?.typographicBounds.height ?? fragH
                        let midY = fragMinY + heightToUse / 2.0
                        
                        let radius: CGFloat = 6.0
                        let kappa: CGFloat = 0.552284749831 // Ideal for circles
                        
                        // endX = x + tabPx - 2: text bắt đầu tại x + tabPx (level tiếp theo)
                        let endX = x + tabPx - 2.0
                        
                        if continuesDown {
                            // ├─ shape (with curved branch)
                            path.move(to: NSPoint(x: x, y: startY))
                            path.line(to: NSPoint(x: x, y: fragMaxY))
                            
                            path.move(to: NSPoint(x: x, y: midY - radius))
                            path.curve(to: NSPoint(x: x + radius, y: midY),
                                       controlPoint1: NSPoint(x: x, y: midY - radius + radius * kappa),
                                       controlPoint2: NSPoint(x: x + radius - radius * kappa, y: midY))
                            path.line(to: NSPoint(x: endX, y: midY))
                        } else {
                            // └─ shape (with curved corner)
                            path.move(to: NSPoint(x: x, y: startY))
                            path.line(to: NSPoint(x: x, y: midY - radius))
                            
                            path.curve(to: NSPoint(x: x + radius, y: midY),
                                       controlPoint1: NSPoint(x: x, y: midY - radius + radius * kappa),
                                       controlPoint2: NSPoint(x: x + radius - radius * kappa, y: midY))
                            path.line(to: NSPoint(x: endX, y: midY))
                        }
                        path.stroke()
                    } else {
                        // Case C: level >= levels — starter guide cho children
                        // Phủ toàn bộ dòng parent (fragMinY → fragMaxY) để nối liền với children
                        let path = NSBezierPath()
                        path.lineWidth = 1.5
                        path.setLineDash([3, 3], count: 2, phase: 0)
                        path.move(to: NSPoint(x: x, y: fragMinY))
                        path.line(to: NSPoint(x: x, y: fragMaxY))
                        path.stroke()
                    }
                }

                return true
            }
        }
    }

    /// Finds the indentation level of the NEXT non-empty line.
    private func findNextIndent(after offset: Int, in content: NSString, tabWidth: Int) -> Int {
        var searchIdx = offset
        while searchIdx < content.length {
            let lineRange = content.lineRange(for: NSRange(location: searchIdx, length: 0))
            let text = content.substring(with: lineRange)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return calculateLeadingSpaces(text, tabWidth: tabWidth)
            }
            searchIdx = lineRange.location + lineRange.length
            if searchIdx >= content.length { break }
        }
        return 0
    }

    /// Finds a contextual indent level for a whitespace-only line by looking at
    /// non-empty lines before and after it.
    private func findContextualIndent(at offset: Int, in content: NSString, tabWidth: Int) -> Int {
        var prevIndent = 0
        var nextIndent = 0

        // Scan backward
        var searchIdx = offset
        while searchIdx > 0 {
            let lineRange = content.lineRange(for: NSRange(location: searchIdx - 1, length: 0))
            let text = content.substring(with: lineRange)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                prevIndent = calculateLeadingSpaces(text, tabWidth: tabWidth)
                break
            }
            searchIdx = lineRange.location
        }

        // Scan forward
        searchIdx = offset
        while searchIdx < content.length {
            let lineRange = content.lineRange(for: NSRange(location: searchIdx, length: 0))
            let text = content.substring(with: lineRange)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nextIndent = calculateLeadingSpaces(text, tabWidth: tabWidth)
                break
            }
            searchIdx = lineRange.location + lineRange.length
            if searchIdx == content.length { break }
        }

        return max(prevIndent, nextIndent)
    }

    private func calculateLeadingSpaces(_ text: String, tabWidth: Int) -> Int {
        var count = 0
        for ch in text {
            if ch == " "  { count += 1 }
            else if ch == "\t" { count += tabWidth }
            else { break }
        }
        return count
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
