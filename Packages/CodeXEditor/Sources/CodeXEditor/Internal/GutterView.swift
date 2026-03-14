import AppKit

/// Draws line numbers with IDE-like interactions:
/// - Click to select the full line
/// - Drag to select a range of lines
/// - Hover highlight
/// - Current line highlight
final class GutterView: NSView {

    // MARK: - Dependencies

    weak var textView: CodeXTextView?
    weak var scrollView: NSScrollView?

    var configuration: EditorConfiguration = EditorConfiguration() {
        didSet { needsDisplay = true }
    }

    // MARK: - Markers

    var markers: [Int: GutterMarkerKind] = [:] {
        didSet { needsDisplay = true }
    }

    /// Called when the user clicks the marker lane to toggle a marker.
    /// `marker` is `nil` when the marker was removed.
    var onMarkerToggled: ((Int, GutterMarkerKind?) -> Void)?

    // MARK: - State

    var lineCount: Int = 1 {
        didSet {
            let newWidth = preferredWidth(for: lineCount)
            if abs(newWidth - frame.width) > 1 {
                preferredWidthDidChange?(newWidth)
            }
            needsDisplay = true
        }
    }

    var preferredWidthDidChange: ((CGFloat) -> Void)?

    // MARK: - Coordinate system

    // Must match NSTextView so fragment y-positions (downward) map correctly.
    override var isFlipped: Bool { true }

    // MARK: - Mouse tracking

    private var trackingArea: NSTrackingArea?
    private var hoveredLine: Int?
    private var isHoveringMarkerLane: Bool = false
    private var lineNumberHighlightProgress: [Int: CGFloat] = [:]
    private var lineNumberTargetProgress: [Int: CGFloat] = [:]
    private var lineNumberAnimationTimer: Timer?

    /// Built during draw(); used for hit-testing in mouse event handlers.
    private var lineHitData: [(line: Int, range: NSRange, rect: NSRect)] = []

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }

    deinit {
        lineNumberAnimationTimer?.invalidate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Width

    static let markerLaneWidth: CGFloat = 16

    func preferredWidth(for lineCount: Int) -> CGFloat {
        let digits = max(3, "\(lineCount)".count)
        let digitWidth = ("0" as NSString).size(
            withAttributes: [.font: configuration.lineNumberFont]
        ).width
        let markerLane: CGFloat = configuration.showGutterMarkers ? GutterView.markerLaneWidth : 0
        return markerLane + CGFloat(digits) * digitWidth + 24
    }

    // MARK: - Tracking Area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard
            let textView,
            let tlm  = textView.textLayoutManager,
            let tcs  = textView.textContentStorage
        else { return }

        lineHitData = []

        let theme = configuration.theme
        let font  = configuration.lineNumberFont

        // Background
        theme.gutterBackground.setFill()
        bounds.fill()

        // Right-edge separator
        NSColor.separatorColor.withAlphaComponent(0.3).setFill()
        NSRect(x: bounds.width - 0.5, y: 0, width: 0.5, height: bounds.height).fill()

        let cursorLine = currentLineNumber(in: textView)
        let selectedLineRanges = selectedLineRanges(in: textView)
        let origin     = textView.textContainerOrigin
        var lineNumber = 1

        var visibleLines = Set<Int>()

        tlm.enumerateTextLayoutFragments(
            from: tcs.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { [weak self] fragment in
            guard let self else { return false }

            let fragFrame  = fragment.layoutFragmentFrame
            let inTextView = CGRect(
                x: fragFrame.origin.x + origin.x,
                y: fragFrame.origin.y + origin.y,
                width: fragFrame.width,
                height: fragFrame.height
            )
            let inGutter = self.convert(inTextView, from: textView)
            let gutterRow = NSRect(
                x: 0,
                y: inGutter.origin.y,
                width: self.bounds.width - 0.5,
                height: fragFrame.height
            )

            // Cull fragments well outside the visible area
            guard gutterRow.minY < self.bounds.height + 100 else { return false }
            guard gutterRow.maxY > -20 else {
                lineNumber += 1
                return true
            }

            visibleLines.insert(lineNumber)

            let isCurrentLine = lineNumber == cursorLine
            let isSelectedLine = selectedLineRanges.contains(where: { $0.contains(lineNumber) })
            let isHighlightedLine = isCurrentLine || isSelectedLine
            self.updateHighlightTarget(for: lineNumber, isHighlighted: isHighlightedLine)
            let highlightProgress = self.lineNumberHighlightProgress[lineNumber] ?? 0

            // Current-line highlight
            if isCurrentLine {
                theme.lineHighlight.withAlphaComponent(0.45).setFill()
                gutterRow.fill()
            } else if lineNumber == self.hoveredLine {
                NSColor.labelColor.withAlphaComponent(0.07).setFill()
                gutterRow.fill()
            }

            // Marker (breakpoint / error / warning / info) or ghost on hover
            if self.configuration.showGutterMarkers {
                let size: CGFloat = 8
                let x = (GutterView.markerLaneWidth - size) / 2
                let y = round(gutterRow.midY - size / 2)
                let markerRect = CGRect(x: x, y: y, width: size, height: size)

                if let marker = self.markers[lineNumber] {
                    marker.color.setFill()
                    NSBezierPath(ovalIn: markerRect).fill()
                } else if self.isHoveringMarkerLane && lineNumber == self.hoveredLine {
                    // Ghost marker: shows affordance that this line is clickable
                    GutterMarkerKind.breakpoint.color.withAlphaComponent(0.35).setFill()
                    NSBezierPath(ovalIn: markerRect).fill()
                }
            }

            // Optically center the line number inside the row.
            //
            // The code text is already vertically centered in its fragment via
            // `baselineOffset`, while gutter numbers intentionally use a smaller
            // font. Matching the code baseline exactly makes the number look too
            // low relative to the code. Centering the rendered number within the
            // same fragment produces a closer visual alignment.
            let label   = "\(lineNumber)" as NSString
            let lineNumberColor: NSColor
            if highlightProgress > 0 {
                lineNumberColor = theme.gutterForeground.blended(
                    withFraction: highlightProgress,
                    of: theme.text
                ) ?? theme.text
            } else if lineNumber == self.hoveredLine {
                lineNumberColor = theme.gutterForeground.blended(withFraction: 0.35, of: theme.text) ?? theme.text
            } else {
                lineNumberColor = theme.gutterForeground
            }
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: lineNumberColor]
            let strSize = label.size(withAttributes: attrs)
            let xDraw   = self.bounds.width - strSize.width - 12
            let yDraw = round(gutterRow.midY - strSize.height / 2)
            label.draw(at: CGPoint(x: xDraw, y: yDraw), withAttributes: attrs)

            // Store hit-test data
            if let textRange = fragment.textElement?.elementRange,
               let nsRange   = self.nsRange(from: textRange, storage: tcs) {
                self.lineHitData.append((line: lineNumber, range: nsRange, rect: gutterRow))
            }

            lineNumber += 1
            return true
        }

        pruneHighlightState(keeping: visibleLines)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        guard let entry = lineHitData.first(where: { $0.rect.contains(pt) }) else { return }

        // Click in marker lane → toggle breakpoint on that line
        if configuration.showGutterMarkers && pt.x < GutterView.markerLaneWidth {
            toggleBreakpoint(on: entry.line)
            return
        }

        // Click in line number area → select full line
        guard let textView else { return }
        let fullLine = (textView.string as NSString).lineRange(for: NSRange(location: entry.range.location, length: 0))
        textView.setSelectedRanges([NSValue(range: fullLine)], affinity: .downstream, stillSelecting: false)
        textView.scrollRangeToVisible(fullLine)
        textView.window?.makeFirstResponder(textView)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let textView else { return }
        let pt = convert(event.locationInWindow, from: nil)
        // Dragging in the marker lane doesn't extend selection
        guard pt.x >= GutterView.markerLaneWidth || !configuration.showGutterMarkers else { return }
        guard let entry = lineHitData.first(where: { $0.rect.contains(pt) }),
              let anchor = textView.selectedRanges.first?.rangeValue else { return }
        let dragLine = (textView.string as NSString).lineRange(for: NSRange(location: entry.range.location, length: 0))
        let combined = NSUnionRange(anchor, dragLine)
        textView.setSelectedRanges([NSValue(range: combined)], affinity: .downstream, stillSelecting: false)
    }

    override func mouseEntered(with event: NSEvent) {
        updateHoverState(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoverState(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        var dirty = false
        if hoveredLine != nil         { hoveredLine = nil;           dirty = true }
        if isHoveringMarkerLane       { isHoveringMarkerLane = false; dirty = true }
        if dirty { needsDisplay = true }
    }

    private func updateHoverState(at pt: CGPoint) {
        let hit = lineHitData.first(where: { $0.rect.contains(pt) })?.line

        var dirty = false
        if hit != hoveredLine { hoveredLine = hit; dirty = true }

        if configuration.showGutterMarkers {
            let inLane = pt.x < GutterView.markerLaneWidth
            if inLane != isHoveringMarkerLane { isHoveringMarkerLane = inLane; dirty = true }
            if inLane { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }

        if dirty { needsDisplay = true }
    }

    // MARK: - Marker toggling

    private func toggleBreakpoint(on line: Int) {
        if markers[line] != nil {
            markers.removeValue(forKey: line)
            onMarkerToggled?(line, nil)
        } else {
            markers[line] = .breakpoint
            onMarkerToggled?(line, .breakpoint)
        }
    }

    // MARK: - External notifications

    func handleScrollDidChange() { needsDisplay = true }
    func selectionDidChange()    { needsDisplay = true }

    // MARK: - Helpers

    private func currentLineNumber(in textView: CodeXTextView) -> Int {
        let location = textView.selectedRange().location
        let text = textView.string as NSString
        return lineNumber(at: location, in: text)
    }

    private func updateHighlightTarget(for line: Int, isHighlighted: Bool) {
        let target: CGFloat = isHighlighted ? 1 : 0
        let current = lineNumberHighlightProgress[line] ?? 0

        lineNumberHighlightProgress[line] = current
        lineNumberTargetProgress[line] = target

        guard abs(current - target) > 0.01 else { return }
        startHighlightAnimationIfNeeded()
    }

    private func startHighlightAnimationIfNeeded() {
        guard lineNumberAnimationTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.stepHighlightAnimation()
        }
        RunLoop.main.add(timer, forMode: .common)
        lineNumberAnimationTimer = timer
    }

    private func stepHighlightAnimation() {
        var hasPendingAnimation = false

        for (line, target) in lineNumberTargetProgress {
            let current = lineNumberHighlightProgress[line] ?? 0
            let next = current + ((target - current) * 0.32)

            if abs(next - target) <= 0.02 {
                lineNumberHighlightProgress[line] = target
            } else {
                lineNumberHighlightProgress[line] = next
                hasPendingAnimation = true
            }
        }

        needsDisplay = true

        if !hasPendingAnimation {
            lineNumberAnimationTimer?.invalidate()
            lineNumberAnimationTimer = nil
        }
    }

    private func pruneHighlightState(keeping visibleLines: Set<Int>) {
        lineNumberHighlightProgress = lineNumberHighlightProgress.filter { visibleLines.contains($0.key) }
        lineNumberTargetProgress = lineNumberTargetProgress.filter { visibleLines.contains($0.key) }
    }

    private func selectedLineRanges(in textView: CodeXTextView) -> [ClosedRange<Int>] {
        let text = textView.string as NSString

        return textView.selectedRanges.compactMap { value in
            let range = value.rangeValue
            guard range.location != NSNotFound, range.length > 0 else { return nil }

            let startLocation = min(max(0, range.location), text.length)
            let endLocation = min(text.length, max(startLocation, NSMaxRange(range) - 1))

            let startLine = lineNumber(at: startLocation, in: text)
            let endLine = lineNumber(at: endLocation, in: text)
            return startLine...endLine
        }
    }

    private func lineNumber(at location: Int, in text: NSString) -> Int {
        var line = 1
        for i in 0 ..< min(location, text.length) {
            if text.character(at: i) == 10 { line += 1 }
        }
        return line
    }

    private func nsRange(from textRange: NSTextRange, storage: NSTextContentStorage) -> NSRange? {
        let start = storage.offset(from: storage.documentRange.location, to: textRange.location)
        let end   = storage.offset(from: storage.documentRange.location, to: textRange.endLocation)
        guard start != NSNotFound, end != NSNotFound else { return nil }
        return NSRange(location: start, length: end - start)
    }
}
