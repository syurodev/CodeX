import AppKit

final class MinimapView: NSView {

    static let preferredWidth: CGFloat = 96

    weak var textView: CodeXTextView?
    weak var editorScrollView: NSScrollView?

    var configuration: EditorConfiguration = EditorConfiguration() {
        didSet {
            layer?.backgroundColor = backgroundColor.cgColor
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    private var backgroundColor: NSColor {
        configuration.useThemeBackground ? configuration.theme.background : .windowBackgroundColor
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = backgroundColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func syncFromEditor() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.withAlphaComponent(0.28).setFill()
        NSRect(x: 0, y: 0, width: 0.5, height: bounds.height).fill()

        guard let textView else { return }

        let lines = textView.string.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = max(lines.count, 1)
        let documentHeight = self.documentHeight(lineCount: lineCount)
        let topPadding: CGFloat = 6
        let drawableHeight = max(1, bounds.height - (topPadding * 2))
        let contentWidth = max(1, bounds.width - 14)
        let maxDrawableRows = max(Int(drawableHeight / 2), 1)
        let step = max(1, Int(ceil(Double(lineCount) / Double(maxDrawableRows))))
        let barHeight = max(1.25, min(3, drawableHeight / CGFloat(maxDrawableRows) * 0.75))

        configuration.theme.text.withAlphaComponent(0.22).setFill()

        for start in stride(from: 0, to: lineCount, by: step) {
            let end = min(start + step, lineCount)
            let chunk = start..<end
            let totalChars = chunk.reduce(0) { partial, index in
                let count = index < lines.count ? lines[index].count : 0
                return partial + min(count, 120)
            }
            let averageChars = CGFloat(totalChars) / CGFloat(max(1, chunk.count))
            let normalizedWidth = averageChars == 0 ? 0.08 : max(0.08, averageChars / 120)
            let documentY = configuration.contentInsets.top + (CGFloat(start) * configuration.lineHeight)
            let y = topPadding + ((documentY / max(documentHeight, 1)) * drawableHeight)
            let rect = NSRect(x: 8, y: y, width: contentWidth * normalizedWidth, height: barHeight)
            NSBezierPath(roundedRect: rect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
        }

        let viewport = viewportRect(documentHeight: documentHeight)
        NSBezierPath(roundedRect: viewport, xRadius: 6, yRadius: 6).fill()
    }

    override func mouseDown(with event: NSEvent) {
        scrollEditor(to: convert(event.locationInWindow, from: nil).y)
    }

    override func mouseDragged(with event: NSEvent) {
        scrollEditor(to: convert(event.locationInWindow, from: nil).y)
    }

    private func scrollEditor(to minimapY: CGFloat) {
        guard let editorScrollView else { return }
        let lineCount = max(textView?.string.split(separator: "\n", omittingEmptySubsequences: false).count ?? 0, 1)
        let documentHeight = documentHeight(lineCount: lineCount)
        let viewport = viewportRect(documentHeight: documentHeight)
        let travel = max(bounds.height - viewport.height, 1)
        let targetOrigin = min(max(minimapY - (viewport.height / 2), 0), travel)
        let maxOffset = max(documentHeight - editorScrollView.contentView.bounds.height, 0)
        let targetY = (targetOrigin / travel) * maxOffset
        editorScrollView.contentView.scroll(to: CGPoint(x: 0, y: targetY))
        editorScrollView.reflectScrolledClipView(editorScrollView.contentView)
    }

    private func documentHeight(lineCount: Int) -> CGFloat {
        let viewportHeight = editorScrollView?.contentView.bounds.height ?? bounds.height
        let estimatedTextHeight = configuration.contentInsets.top
            + configuration.contentInsets.bottom
            + (CGFloat(lineCount) * configuration.lineHeight)
        let actualTextHeight = textView?.bounds.height ?? 0
        return max(estimatedTextHeight, actualTextHeight, viewportHeight, 1)
    }

    private func viewportRect(documentHeight: CGFloat) -> NSRect {
        let viewportHeight = editorScrollView?.contentView.bounds.height ?? bounds.height
        let offsetY = editorScrollView?.contentView.bounds.origin.y ?? 0
        let visibleRatio = min(1, viewportHeight / max(documentHeight, 1))
        let rectHeight = max(24, bounds.height * visibleRatio)
        let maxOffset = max(documentHeight - viewportHeight, 0)
        let travel = max(bounds.height - rectHeight, 0)
        let rectY = maxOffset > 0 ? (offsetY / maxOffset) * travel : 0

        let isLightMode = (backgroundColor.usingColorSpace(.deviceRGB)?.brightnessComponent ?? 0.0) > 0.5
        let overlayColor: NSColor = isLightMode
            ? .black.withAlphaComponent(0.08)
            : .white.withAlphaComponent(0.08)
        overlayColor.setFill()

        return NSRect(x: 4, y: rectY, width: max(0, bounds.width - 8), height: min(bounds.height, rectHeight))
    }
}