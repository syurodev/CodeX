import AppKit

/// Highlights matching bracket pairs:
/// - Solid accent-colour background + contrasting text applied to NSTextStorage
/// - "Curtain" NSView overlay (editor-background colour) animates in/out to
///   create a smooth fade-in (reveal) and fade-out (cover) without the
///   limitation that NSTextStorage attributes are not directly animatable.
@MainActor
final class BracketMatchHighlighter {

    private typealias Pair = (open: Character, close: Character)

    // MARK: - State

    /// Ranges that currently have NSTextStorage attributes applied.
    private var highlightedRanges: [NSRange] = []
    /// Foreground colours saved before the highlight was applied.
    private var savedForegrounds: [(range: NSRange, color: NSColor)] = []
    /// Curtain views used for the reveal / cover animations.
    private var curtainViews: [NSView] = []
    private var clearTask: DispatchWorkItem?

    // MARK: - Constants

    private let pairs: [Pair] = [
        (open: "{", close: "}"),
        (open: "(", close: ")"),
        (open: "[", close: "]")
    ]

    private let holdDuration:    TimeInterval = 3.0
    private let fadeInDuration:  TimeInterval = 0.08
    private let fadeOutDuration: TimeInterval = 0.20

    // MARK: - Public API

    func update(in textView: NSTextView) {
        cancelAndReset(textView: textView)

        let nsString = textView.string as NSString
        let length   = nsString.length
        let cursor   = textView.selectedRange().location
        guard length > 0 else { return }

        for pos in [cursor, cursor - 1] {
            guard pos >= 0, pos < length else { continue }
            guard let scalar = Unicode.Scalar(nsString.character(at: pos)) else { continue }
            let ch = Character(scalar)

            if let pair = pairs.first(where: { $0.open == ch }),
               let match = findClosing(pair: pair, from: pos + 1, in: nsString) {
                flash([NSRange(location: pos, length: 1), match], in: textView)
                return
            }
            if let pair = pairs.first(where: { $0.close == ch }),
               let match = findOpening(pair: pair, from: pos - 1, in: nsString) {
                flash([NSRange(location: pos, length: 1), match], in: textView)
                return
            }
        }
    }

    func clearHighlights(in textView: NSTextView) {
        cancelAndReset(textView: textView)
    }

    // MARK: - Flash

    private func flash(_ ranges: [NSRange], in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }

        let bgColor = NSColor.controlAccentColor
        let fgColor = contrastingTextColor(for: bgColor)

        // 1 ─ Apply solid highlight to NSTextStorage (instant).
        storage.beginEditing()
        for range in ranges {
            var er = NSRange(location: 0, length: 0)
            let saved = storage.attribute(.foregroundColor,
                                          at: range.location,
                                          effectiveRange: &er) as? NSColor
                        ?? textView.textColor
                        ?? .textColor
            savedForegrounds.append((range: range, color: saved))
            storage.addAttribute(.backgroundColor, value: bgColor, range: range)
            storage.addAttribute(.foregroundColor,  value: fgColor,  range: range)
        }
        storage.endEditing()
        highlightedRanges = ranges

        // 2 ─ Fade-in: curtain starts opaque (editor bg) → fades to transparent,
        //     revealing the highlight beneath.
        showCurtain(alpha: 1.0, over: ranges, textView: textView) { curtains in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration       = self.fadeInDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                curtains.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: {
                curtains.forEach { $0.removeFromSuperview() }
                self.curtainViews.removeAll { curtains.contains($0) }
            })
        }

        // 3 ─ Schedule fade-out after hold.
        let item = DispatchWorkItem { [weak self, weak textView] in
            guard let self, let textView else { return }
            let ranges = self.highlightedRanges

            // Fade-out: curtain starts transparent → fades to opaque (covering highlight),
            // then restore NSTextStorage and remove everything.
            self.showCurtain(alpha: 0.0, over: ranges, textView: textView) { curtains in
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration       = self.fadeOutDuration
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    curtains.forEach { $0.animator().alphaValue = 1 }
                }, completionHandler: {
                    self.restoreColors(in: textView)  // remove attrs while curtain is opaque
                    curtains.forEach { $0.removeFromSuperview() }
                    self.curtainViews.removeAll { curtains.contains($0) }
                })
            }
        }
        clearTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: item)
    }

    // MARK: - Curtain helper

    /// Creates NSView overlays matching the editor background colour at `ranges`,
    /// then calls `animate` with those views so the caller can drive the animation.
    private func showCurtain(alpha: CGFloat, over ranges: [NSRange],
                              textView: NSTextView,
                              animate: @escaping ([NSView]) -> Void) {
        guard let container = textView.enclosingScrollView?.superview else { return }
        let bg = textView.backgroundColor

        var created: [NSView] = []
        for range in ranges {
            for rect in characterRects(for: range, in: textView, convertedTo: container) {
                let v = NSView(frame: rect)
                v.wantsLayer = true
                v.layer?.backgroundColor = bg.cgColor
                v.layer?.cornerRadius    = 3
                v.alphaValue = alpha
                container.addSubview(v)
                created.append(v)
            }
        }
        curtainViews.append(contentsOf: created)
        animate(created)
    }

    // MARK: - Restore

    private func restoreColors(in textView: NSTextView) {
        guard !highlightedRanges.isEmpty, let storage = textView.textStorage else { return }
        let len = storage.length
        storage.beginEditing()
        for (range, color) in savedForegrounds {
            guard range.location + range.length <= len else { continue }
            storage.removeAttribute(.backgroundColor, range: range)
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
        storage.endEditing()
        highlightedRanges = []
        savedForegrounds  = []
    }

    private func cancelAndReset(textView: NSTextView) {
        clearTask?.cancel()
        clearTask = nil
        curtainViews.forEach { $0.removeFromSuperview() }
        curtainViews = []
        restoreColors(in: textView)
    }

    // MARK: - Geometry (TextKit 2)

    private func characterRects(for range: NSRange,
                                 in textView: NSTextView,
                                 convertedTo target: NSView) -> [CGRect] {
        guard let lm = textView.textLayoutManager,
              let cs = textView.textContentStorage else { return [] }
        guard let start = cs.location(cs.documentRange.location, offsetBy: range.location),
              let end   = cs.location(start, offsetBy: range.length),
              let tr    = NSTextRange(location: start, end: end) else { return [] }

        let origin = textView.textContainerOrigin
        var rects: [CGRect] = []
        lm.enumerateTextSegments(in: tr, type: .highlight, options: []) { _, seg, _, _ in
            guard !seg.isEmpty else { return true }
            rects.append(textView.convert(seg.offsetBy(dx: origin.x, dy: origin.y), to: target))
            return true
        }
        return rects
    }

    // MARK: - Colour contrast

    private func contrastingTextColor(for background: NSColor) -> NSColor {
        guard let srgb = background.usingColorSpace(.sRGB) else { return .white }
        let lum = 0.2126 * srgb.redComponent
                + 0.7152 * srgb.greenComponent
                + 0.0722 * srgb.blueComponent
        return lum > 0.35 ? NSColor(white: 0.08, alpha: 1) : .white
    }

    // MARK: - Bracket scanning

    private func findClosing(pair: Pair, from start: Int, in s: NSString) -> NSRange? {
        var depth = 1, pos = start
        while pos < s.length {
            guard let scalar = Unicode.Scalar(s.character(at: pos)) else { pos += 1; continue }
            switch Character(scalar) {
            case pair.open:  depth += 1
            case pair.close: depth -= 1; if depth == 0 { return NSRange(location: pos, length: 1) }
            default: break
            }
            pos += 1
        }
        return nil
    }

    private func findOpening(pair: Pair, from start: Int, in s: NSString) -> NSRange? {
        var depth = 1, pos = start
        while pos >= 0 {
            guard let scalar = Unicode.Scalar(s.character(at: pos)) else { pos -= 1; continue }
            switch Character(scalar) {
            case pair.close: depth += 1
            case pair.open:  depth -= 1; if depth == 0 { return NSRange(location: pos, length: 1) }
            default: break
            }
            pos -= 1
        }
        return nil
    }
}
