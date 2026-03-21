import AppKit
import SwiftUI

// MARK: - Composer Ref

/// Imperative handle for SwiftUI to call methods on the underlying NSTextView.
final class AgentRichComposerRef {
    fileprivate weak var textView: AgentRichTextView?

    func insertMention(url: URL) { textView?.insertMention(url: url) }
    func replaceAll(with text: String) { textView?.replaceAll(with: text) }
    func clearAll() { textView?.replaceAll(with: "") }
    func buildPrompt(workingDirectory: URL?) -> String {
        textView?.buildPrompt(workingDirectory: workingDirectory) ?? ""
    }
}

// MARK: - Mention Attachment (image-based, works with TextKit 1 & 2)

final class AgentMentionAttachment: NSTextAttachment {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init(data: nil, ofType: nil)
        let img = Self.renderBadge(filename: url.lastPathComponent)
        self.image = img
        // Vertically center badge with text baseline (-3 nudges it up slightly)
        self.bounds = CGRect(x: 0, y: -3, width: img.size.width, height: img.size.height)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Width of the × dismiss button on the right side of the badge.
    static let xButtonWidth: CGFloat = 18

    static func badgeSize(for filename: String) -> CGSize {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let textWidth = (filename as NSString).size(withAttributes: [.font: font]).width
        // leftPad(8) + text + gap(2) + separator(1) + xArea(xButtonWidth) + rightPad(5)
        return CGSize(width: ceil(16 + textWidth + xButtonWidth), height: 18)
    }

    /// Drawn each time the image is rendered so NSColor semantic values
    /// resolve correctly for the current appearance (dark / light).
    private static func renderBadge(filename: String) -> NSImage {
        let size = badgeSize(for: filename)
        let img = NSImage(size: size, flipped: false) { rect in
            let radius = rect.height / 2
            let inset = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius)

            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 0.5
            path.stroke()

            // Filename text
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.controlAccentColor
            ]
            let str = filename as NSString
            let textSize = str.size(withAttributes: attrs)
            str.draw(
                at: NSPoint(x: 8, y: (rect.height - textSize.height) / 2),
                withAttributes: attrs
            )

            // Separator before ×
            let sepX = rect.maxX - xButtonWidth
            NSColor.controlAccentColor.withAlphaComponent(0.25).setStroke()
            let sep = NSBezierPath()
            sep.move(to: NSPoint(x: sepX, y: rect.minY + 3))
            sep.line(to: NSPoint(x: sepX, y: rect.maxY - 3))
            sep.lineWidth = 0.5
            sep.stroke()

            // × character
            let xFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
            let xAttrs: [NSAttributedString.Key: Any] = [
                .font: xFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let xStr = "×" as NSString
            let xSize = xStr.size(withAttributes: xAttrs)
            xStr.draw(
                at: NSPoint(x: sepX + (xButtonWidth - xSize.width) / 2, y: (rect.height - xSize.height) / 2),
                withAttributes: xAttrs
            )
            return true
        }
        img.cacheMode = .never  // Re-draw on every render pass for appearance adaptation
        return img
    }
}

// MARK: - Rich Text View

final class AgentRichTextView: NSTextView {
    var onTextChange: ((String) -> Void)?
    var onAtQuery: ((String) -> Void)?
    var onAtDismiss: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onPickerKeyDown: ((NSEvent) -> Bool)?
    var onHeightChange: ((CGFloat) -> Void)?
    var placeholder: String = ""

    private var atMentionStart: Int?

    override var acceptsFirstResponder: Bool { true }

    // MARK: Click on badge

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let (mention, charIndex, badgeRect) = mentionInfo(at: point) {
            // Rightmost xButtonWidth px = × dismiss button
            if point.x >= badgeRect.maxX - AgentMentionAttachment.xButtonWidth {
                deleteMention(at: charIndex)
            } else {
                // Open file inside CodeX via notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("CodeX.OpenAndJump"),
                    object: nil,
                    userInfo: ["url": mention.url, "line": 0, "column": 0]
                )
            }
            return
        }
        super.mouseDown(with: event)
    }

    private func mentionInfo(at point: NSPoint) -> (AgentMentionAttachment, Int, CGRect)? {
        guard let lm = layoutManager, let tc = textContainer, let ts = textStorage else { return nil }
        let glyphIndex = lm.glyphIndex(for: point, in: tc, fractionOfDistanceThroughGlyph: nil)
        guard glyphIndex < lm.numberOfGlyphs else { return nil }
        let charIndex = lm.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < ts.length else { return nil }
        guard let mention = ts.attribute(.attachment, at: charIndex, effectiveRange: nil) as? AgentMentionAttachment else { return nil }
        let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: charIndex, length: 1), actualCharacterRange: nil)
        var glyphRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        // Adjust for textContainerInset
        glyphRect = glyphRect.offsetBy(dx: textContainerInset.width, dy: textContainerInset.height)
        return (mention, charIndex, glyphRect)
    }

    private func deleteMention(at charIndex: Int) {
        guard let ts = textStorage else { return }
        var deleteRange = NSRange(location: charIndex, length: 1)
        // Also delete the trailing space that was appended after the attachment
        if charIndex + 1 < ts.length,
           (ts.string as NSString).character(at: charIndex + 1) == 32 {
            deleteRange.length = 2
        }
        ts.deleteCharacters(in: deleteRange)
        onTextChange?(string)
        reportHeight()
    }

    // MARK: Input overrides

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        handleTextChange()
    }

    override func deleteBackward(_ sender: Any?) {
        super.deleteBackward(sender)
        handleTextChange()
    }

    override func deleteForward(_ sender: Any?) {
        super.deleteForward(sender)
        handleTextChange()
    }

    override func paste(_ sender: Any?) {
        super.paste(sender)
        handleTextChange()
    }

    override func keyDown(with event: NSEvent) {
        if let handler = onPickerKeyDown, handler(event) { return }
        // Return (keyCode 36) without Shift = submit
        if event.keyCode == 36, !event.modifierFlags.contains(.shift) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: @ Detection

    private func handleTextChange() {
        onTextChange?(string)
        detectAtMention()
        reportHeight()
    }

    private func detectAtMention() {
        let cursor = selectedRange().location
        guard cursor > 0 else { dismissAtIfNeeded(); return }
        let s = string as NSString
        var i = cursor - 1
        var query = ""

        while i >= 0 {
            let ch = s.character(at: i)
            if ch == 0xFFFC { break } // NSTextAttachment character — stop
            let c = Character(Unicode.Scalar(ch)!)
            if c == "@" {
                atMentionStart = i
                onAtQuery?(query)
                return
            }
            if c == " " || c == "\n" { break }
            query = String(c) + query
            i -= 1
        }
        dismissAtIfNeeded()
    }

    private func dismissAtIfNeeded() {
        guard atMentionStart != nil else { return }
        atMentionStart = nil
        onAtDismiss?()
    }

    // MARK: Insert mention

    func insertMention(url: URL) {
        guard let start = atMentionStart else { return }
        let cursor = selectedRange().location
        let range = NSRange(location: start, length: max(0, cursor - start))

        let attachment = AgentMentionAttachment(url: url)
        let attachStr = NSMutableAttributedString(attachment: attachment)
        let space = NSAttributedString(string: " ", attributes: typingAttributes)
        attachStr.append(space)

        textStorage?.replaceCharacters(in: range, with: attachStr)
        setSelectedRange(NSRange(location: start + attachStr.length, length: 0))

        atMentionStart = nil
        onAtDismiss?()
        onTextChange?(string)
        reportHeight()
    }

    // MARK: Replace all

    func replaceAll(with text: String) {
        let range = NSRange(location: 0, length: textStorage?.length ?? 0)
        let attrs = typingAttributes
        textStorage?.replaceCharacters(
            in: range,
            with: NSAttributedString(string: text, attributes: attrs)
        )
        setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        atMentionStart = nil
        onAtDismiss?()
        onTextChange?(string)
        reportHeight()
    }

    // MARK: Build prompt

    func buildPrompt(workingDirectory: URL?) -> String {
        guard let ts = textStorage else { return "" }
        var parts: [String] = []
        var textBuffer = ""

        ts.enumerateAttributes(in: NSRange(location: 0, length: ts.length)) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? AgentMentionAttachment {
                if !textBuffer.isEmpty {
                    let t = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { parts.append(t) }
                    textBuffer = ""
                }
                let url = attachment.url
                let relPath: String
                if let wd = workingDirectory, url.path.hasPrefix(wd.path) {
                    relPath = String(url.path.dropFirst(wd.path.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                } else {
                    relPath = url.lastPathComponent
                }
                parts.append("@\(relPath)")
            } else {
                textBuffer += (ts.string as NSString).substring(with: range)
            }
        }
        let finalText = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty { parts.append(finalText) }
        return parts.joined(separator: " ")
    }

    // MARK: Height reporting

    func reportHeight() {
        guard let tlm = textLayoutManager,
              let cm = tlm.textContentManager else {
            // TextKit 1 fallback
            if let lm = layoutManager, let tc = textContainer {
                lm.ensureLayout(for: tc)
                let h = lm.usedRect(for: tc).height
                onHeightChange?(min(120, max(22, ceil(h) + 8)))
            }
            return
        }
        tlm.ensureLayout(for: cm.documentRange)
        var maxY: CGFloat = 0
        tlm.enumerateTextLayoutFragments(
            from: cm.documentRange.location,
            options: .ensuresLayout
        ) { fragment in
            maxY = max(maxY, fragment.layoutFragmentFrame.maxY)
            return true
        }
        onHeightChange?(min(120, max(22, ceil(maxY) + 8)))
    }

    // MARK: Placeholder

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        (placeholder as NSString).draw(in: bounds.insetBy(dx: 2, dy: 4), withAttributes: attrs)
    }
}

// MARK: - NSViewRepresentable

struct AgentRichComposerView: NSViewRepresentable {
    let ref: AgentRichComposerRef
    let placeholder: String
    let isEnabled: Bool
    @Binding var contentHeight: CGFloat
    let onTextChange: (String) -> Void
    let onAtQuery: (String) -> Void
    let onAtDismiss: () -> Void
    let onSubmit: () -> Void
    var onPickerKeyDown: ((NSEvent) -> Bool)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false

        let textView = AgentRichTextView()
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        textView.textColor = .labelColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 200,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false

        let coordinator = context.coordinator
        textView.onHeightChange = { h in
            DispatchQueue.main.async { coordinator.contentHeight?.wrappedValue = h }
        }
        coordinator.contentHeight = $contentHeight
        textView.delegate = coordinator

        scrollView.documentView = textView
        ref.textView = textView
        applyProps(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AgentRichTextView else { return }
        textView.isEditable = isEnabled
        context.coordinator.contentHeight = $contentHeight
        applyProps(to: textView)
    }

    private func applyProps(to textView: AgentRichTextView) {
        textView.placeholder = placeholder
        textView.onTextChange = onTextChange
        textView.onAtQuery = onAtQuery
        textView.onAtDismiss = onAtDismiss
        textView.onSubmit = onSubmit
        textView.onPickerKeyDown = onPickerKeyDown
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var contentHeight: Binding<CGFloat>?

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? AgentRichTextView else { return }
            tv.reportHeight()
        }
    }
}
