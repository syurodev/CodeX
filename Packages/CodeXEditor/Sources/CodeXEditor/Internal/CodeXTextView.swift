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
        didSet {
            indentCacheVersion += 1   // font / tabWidth may have changed
            applyConfiguration()
        }
    }

    weak var editorDelegate: CodeXTextViewDelegate?

    // MARK: - TextFormation

    private var textFilters: [Filter] = []

    // MARK: - Indent guide cache

    /// Bumped whenever text or config changes so drawBackground rebuilds lazily.
    private var indentCacheVersion:    Int      = 0
    private var cachedIndentVersion:   Int      = -1
    private var cachedIndentMap:       [Int: Int] = [:]
    private var cachedNextIndentMap:   [Int: Int] = [:]
    /// Line-start offsets of whitespace-only lines (for O(1) lookup in drawBackground).
    private var cachedIsWhitespaceSet: Set<Int>  = []
    /// Sorted character offsets where each line starts — used for O(log n) line-number
    /// lookup (GutterView) and for skipping off-screen fragments in drawBackground.
    private var cachedLineStartOffsets: [Int] = []

    // MARK: - Diagnostics
    private var _bgSeq = 0

    /// Cached result of `(" " as NSString).size(withAttributes:)` — recomputed only on font change.
    private var cachedCharWidthFont:  NSFont? = nil
    private var cachedCharWidthValue: CGFloat = 0
    private var indentGuideCharWidth: CGFloat {
        let font = configuration.font
        if font !== cachedCharWidthFont {
            cachedCharWidthFont  = font
            cachedCharWidthValue = (" " as NSString).size(withAttributes: [.font: font]).width
        }
        return cachedCharWidthValue
    }

    // MARK: - Cmd+Hover state

    private var isCmdHeld = false
    private var hoverRange: NSRange? = nil
    private var hoverAttributeBackups: [(range: NSRange, attrs: [NSAttributedString.Key: Any])] = []
    private var hoverTrackingArea: NSTrackingArea?

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
        _bgSeq += 1
        let _seq = _bgSeq
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
            let charWidth   = indentGuideCharWidth          // cached — no recompute per frame
            let charAdvance = charWidth + cfg.kern
            let tabPx       = charAdvance * CGFloat(cfg.tabWidth)
            let guideColor  = cfg.theme.indentGuide
            let content     = string as NSString

            // Rebuild indent maps only when text or config changed (O(1) on scroll).
            ensureIndentCache()
            let indentMap    = cachedIndentMap
            let nextIndentMap = cachedNextIndentMap
            let wsSet        = cachedIsWhitespaceSet

            // --- Batch paths: one for straight segments, one for curves/branches ---
            let straightPath = NSBezierPath()
            straightPath.lineWidth = 1.5
            straightPath.setLineDash([3, 3], count: 2, phase: 0)

            let branchPath = NSBezierPath()
            branchPath.lineWidth = 1.5
            branchPath.setLineDash([3, 3], count: 2, phase: 0)

            let xInset: CGFloat = charAdvance * 0.7
            let radius: CGFloat = 6.0
            let kappa:  CGFloat = 0.552284749831

            // Skip to the first fragment near the top of the dirty rect instead of
            // iterating from the document start — eliminates O(scroll_position) per frame.
            let visStartY    = max(0.0, rect.minY - configuration.lineHeight * 2)
            let visStartChar = characterIndexForInsertion(at: CGPoint(x: 0, y: visStartY))
            let enumStart: NSTextLocation = tcs.location(
                tcs.documentRange.location, offsetBy: visStartChar
            ) ?? tcs.documentRange.location

            var _bgSkip = 0, _bgDrawn = 0

            tlm.enumerateTextLayoutFragments(
                from: enumStart,
                options: [.ensuresLayout, .ensuresExtraLineFragment]
            ) { fragment in
                let fragMinY = fragment.layoutFragmentFrame.minY + origin.y
                let fragMaxY = fragment.layoutFragmentFrame.maxY + origin.y

                guard fragMinY < rect.maxY + 50 else { return false }
                guard fragMaxY > rect.minY - 50 else { _bgSkip += 1; return true }

                guard let textRange = fragment.textElement?.elementRange else { return true }
                let start = tcs.offset(from: tcs.documentRange.location, to: textRange.location)
                let end   = tcs.offset(from: tcs.documentRange.location, to: textRange.endLocation)
                guard start != NSNotFound, end != NSNotFound, start < content.length else { return true }

                let leadingSpaces    = indentMap[start]     ?? 0
                let nextIndentSpaces = nextIndentMap[start] ?? 0
                let isWhitespaceOnly = wsSet.contains(start)   // O(1) set lookup

                let levels     = leadingSpaces    / cfg.tabWidth
                let nextLevels = nextIndentSpaces / cfg.tabWidth
                guard levels > 0 else { return true }

                let lineFragment = fragment.textLineFragments.first
                let glyphStartX  = lineFragment?.glyphOrigin.x ?? 0
                let baseX        = origin.x + glyphStartX
                let heightToUse  = lineFragment?.typographicBounds.height ?? fragment.layoutFragmentFrame.height
                let midY         = fragMinY + heightToUse / 2.0

                let loopEnd = max(levels, nextLevels)
                for level in 0..<loopEnd {
                    let x          = baseX + CGFloat(level) * tabPx + xInset
                    let continuesDown = nextLevels > level

                    if isWhitespaceOnly {
                        if continuesDown {
                            straightPath.move(to: NSPoint(x: x, y: fragMinY))
                            straightPath.line(to: NSPoint(x: x, y: fragMaxY))
                        }
                        continue
                    }

                    if level < levels - 1 {
                        // Case A: passthrough vertical
                        if continuesDown {
                            straightPath.move(to: NSPoint(x: x, y: fragMinY))
                            straightPath.line(to: NSPoint(x: x, y: fragMaxY))
                        }
                    } else if level == levels - 1 {
                        // Case B: branch (├─ or └─)
                        let endX = x + tabPx - 2.0 - xInset
                        if continuesDown {
                            straightPath.move(to: NSPoint(x: x, y: fragMinY))
                            straightPath.line(to: NSPoint(x: x, y: fragMaxY))
                            branchPath.move(to: NSPoint(x: x, y: midY - radius))
                            branchPath.curve(to: NSPoint(x: x + radius, y: midY),
                                             controlPoint1: NSPoint(x: x, y: midY - radius + radius * kappa),
                                             controlPoint2: NSPoint(x: x + radius - radius * kappa, y: midY))
                            branchPath.line(to: NSPoint(x: endX, y: midY))
                        } else {
                            straightPath.move(to: NSPoint(x: x, y: fragMinY))
                            straightPath.line(to: NSPoint(x: x, y: midY - radius))
                            branchPath.move(to: NSPoint(x: x, y: midY - radius))
                            branchPath.curve(to: NSPoint(x: x + radius, y: midY),
                                             controlPoint1: NSPoint(x: x, y: midY - radius + radius * kappa),
                                             controlPoint2: NSPoint(x: x + radius - radius * kappa, y: midY))
                            branchPath.line(to: NSPoint(x: endX, y: midY))
                        }
                    } else {
                        // Case C: child starter (from midY of opening line)
                        straightPath.move(to: NSPoint(x: x, y: midY))
                        straightPath.line(to: NSPoint(x: x, y: fragMaxY))
                    }
                }
                _bgDrawn += 1
                return true
            }

            if _seq % 30 == 0 {
                print("[BG    #\(_seq)] rectMinY=\(Int(rect.minY))  visStartChar=\(visStartChar)  skipped=\(_bgSkip)  drawn=\(_bgDrawn)")
            }

            // Flush both paths in 2 draw calls
            guideColor.setStroke()
            straightPath.stroke()
            branchPath.stroke()
        }
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

    /// Rebuilds indent maps once per text-or-config change; O(1) on subsequent calls
    /// until the next change. Called at the top of the indent-guide drawing path.
    private func ensureIndentCache() {
        guard cachedIndentVersion != indentCacheVersion else { return }
        cachedIndentVersion = indentCacheVersion

        let content  = string as NSString
        let tabWidth = configuration.tabWidth

        var indentMap:     [Int: Int] = [:]
        var nextIndentMap: [Int: Int] = [:]
        var lineOffsets:   [Int]      = []
        var whitespaceSet: Set<Int>   = []

        var scanIdx = 0
        while scanIdx < content.length {
            let lr     = content.lineRange(for: NSRange(location: scanIdx, length: 0))
            let text   = content.substring(with: lr)
            let spaces = calculateLeadingSpaces(text, tabWidth: tabWidth)
            let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            indentMap[lr.location] = isEmpty ? -1 : spaces
            lineOffsets.append(lr.location)
            if isEmpty { whitespaceSet.insert(lr.location) }
            scanIdx = lr.location + lr.length
            if scanIdx >= content.length { break }
        }

        var lastNonEmpty = 0
        for i in stride(from: lineOffsets.count - 1, through: 0, by: -1) {
            let off = lineOffsets[i]
            let v   = indentMap[off] ?? 0
            if v >= 0 { lastNonEmpty = v }
            nextIndentMap[off] = lastNonEmpty
        }

        var prevNonEmptySpaces = 0
        for off in lineOffsets {
            let v = indentMap[off] ?? 0
            if v < 0 {
                let next = nextIndentMap[off] ?? 0
                indentMap[off] = max(prevNonEmptySpaces, next)
            } else {
                prevNonEmptySpaces = v
            }
        }

        cachedIndentMap        = indentMap
        cachedNextIndentMap    = nextIndentMap
        cachedIsWhitespaceSet  = whitespaceSet
        cachedLineStartOffsets = lineOffsets
    }

    /// Called by CodeXEditorViewController.setText() for programmatic text replacement
    /// (e.g. format-on-save). NSTextStorage.setAttributedString() bypasses the normal
    /// user-input path so didChangeText() is never fired; we invalidate the cache here.
    func invalidateIndentCache() {
        indentCacheVersion += 1
    }

    /// Returns the character offset and 1-based line number for the line that starts
    /// just before `scrollY` (in the text view's document coordinate system).
    ///
    /// Safe to call from GutterView during drawing. Does NOT use
    /// `characterIndexForInsertion` — that API can return incorrect results when
    /// called from a sibling view before TextKit 2 has computed layout for the
    /// new scroll position. Instead we use pure arithmetic on the cached line-start
    /// offsets (rebuilt once per text/config change, O(1) afterwards).
    ///
    /// We back up 10 lines above the approximate visible top so the existing cull
    /// guard in GutterView handles any rounding inaccuracy cheaply.
    func visibleStartInfo(forScrollY scrollY: CGFloat) -> (charOffset: Int, lineNumber: Int) {
        ensureIndentCache()
        let offsets = cachedLineStartOffsets
        guard !offsets.isEmpty else { return (0, 1) }
        let originY = textContainerOrigin.y
        let lineHt  = configuration.lineHeight
        let approxIdx = max(0, Int((scrollY - originY) / lineHt) - 10)
        let idx = min(approxIdx, offsets.count - 1)
        return (offsets[idx], idx + 1)
    }

    /// Returns the 1-based line number containing `charOffset`.
    /// Triggers cache rebuild if needed — O(n) first time after a change, O(log n) thereafter.
    func lineNumber(at charOffset: Int) -> Int {
        ensureIndentCache()
        let offsets = cachedLineStartOffsets
        guard offsets.count > 1 else { return 1 }
        // Binary search: find the largest index i where offsets[i] <= charOffset.
        var lo = 0, hi = offsets.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if offsets[mid] <= charOffset { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1   // 0-based array index → 1-based line number
    }

    // MARK: - Cmd+Click (Go to Definition)

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.mouseDown(with: event)
            return
        }
        clearHoverHighlight()
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)
        setSelectedRange(NSRange(location: charIndex, length: 0))
        editorDelegate?.textViewDidCommandClick(self, characterIndex: charIndex)
    }

    // MARK: - Cmd+Hover (cursor + underline preview)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = hoverTrackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        let cmdNow = event.modifierFlags.contains(.command)
        guard cmdNow != isCmdHeld else { return }
        isCmdHeld = cmdNow
        window?.invalidateCursorRects(for: self)
        if cmdNow {
            updateCmdHover(at: convert(event.locationInWindow, from: nil))
        } else {
            clearHoverHighlight()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard isCmdHeld else { return }
        updateCmdHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        clearHoverHighlight()
    }

    /// Pointing-hand cursor over the entire text area while Cmd is held,
    /// matching Xcode/VS Code convention.
    override func resetCursorRects() {
        if isCmdHeld {
            discardCursorRects()
            addCursorRect(visibleRect, cursor: .pointingHand)
        } else {
            super.resetCursorRects()
        }
    }

    /// NSTextView resets the cursor via cursorUpdate(with:) every time the mouse
    /// moves through a cursor rect. Override this so the pointing-hand persists
    /// while Cmd is held — resetCursorRects alone is not enough.
    override func cursorUpdate(with event: NSEvent) {
        if isCmdHeld {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    // MARK: Hover helpers

    private func updateCmdHover(at point: NSPoint) {
        let idx = characterIndexForInsertion(at: point)
        guard let range = identifierRange(at: idx) else { clearHoverHighlight(); return }
        if let current = hoverRange, current == range { return }
        applyHoverHighlight(at: range)
    }

    private func applyHoverHighlight(at range: NSRange) {
        guard let storage = textStorage else { return }
        clearHoverHighlight()
        // Back up existing attribute runs so we can restore exactly.
        var backups: [(range: NSRange, attrs: [NSAttributedString.Key: Any])] = []
        storage.enumerateAttributes(in: range, options: []) { attrs, sub, _ in
            backups.append((range: sub, attrs: attrs))
        }
        hoverAttributeBackups = backups
        hoverRange = range
        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        storage.addAttribute(.underlineStyle,  value: NSUnderlineStyle.single.rawValue, range: range)
        storage.addAttribute(.underlineColor,  value: NSColor.linkColor, range: range)
        storage.endEditing()
    }

    private func clearHoverHighlight() {
        defer { hoverRange = nil; hoverAttributeBackups = [] }
        guard let range = hoverRange,
              let storage = textStorage,
              !hoverAttributeBackups.isEmpty else { return }
        let len = storage.length
        guard range.location + range.length <= len else { return }
        storage.beginEditing()
        for b in hoverAttributeBackups where b.range.location + b.range.length <= len {
            storage.setAttributes(b.attrs, range: b.range)
        }
        storage.endEditing()
    }

    /// Returns the NSRange of the identifier (JS/TS token) that contains `index`,
    /// or `nil` if the character at `index` is not part of an identifier.
    private func identifierRange(at index: Int) -> NSRange? {
        let text = string as NSString
        guard index < text.length else { return nil }
        func isId(_ c: unichar) -> Bool {
            (c >= 65 && c <= 90)  ||  // A-Z
            (c >= 97 && c <= 122) ||  // a-z
            (c >= 48 && c <= 57)  ||  // 0-9
            c == 95 || c == 36        // _ $
        }
        guard isId(text.character(at: index)) else { return nil }
        var lo = index, hi = index
        while lo > 0 && isId(text.character(at: lo - 1)) { lo -= 1 }
        while hi + 1 < text.length && isId(text.character(at: hi + 1)) { hi += 1 }
        return NSRange(location: lo, length: hi - lo + 1)
    }

    // MARK: - Change notifications

    override func didChangeText() {
        indentCacheVersion += 1   // text changed → rebuild indent maps on next draw
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
    func textViewDidCommandClick(_ textView: CodeXTextView, characterIndex: Int)
}
