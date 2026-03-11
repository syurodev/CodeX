import AppKit

/// All visual and behavioral settings for CodeXEditorView.
/// Equatable so the view controller can detect what changed and apply minimally.
public struct EditorConfiguration: Equatable {

    // MARK: - Typography
    public var font: NSFont
    public var lineHeightMultiple: Double
    /// Extra spacing between characters as a multiplier (1.0 = none, 1.1 = 10% extra).
    public var letterSpacing: Double
    public var tabWidth: Int

    // MARK: - Behavior
    public var wrapLines: Bool
    public var isEditable: Bool
    public var useSystemCursor: Bool

    // MARK: - Peripherals
    public var showLineNumbers: Bool
    public var showMinimap: Bool

    // MARK: - Appearance
    public var useThemeBackground: Bool
    public var theme: EditorTheme
    public var contentInsets: NSEdgeInsets

    // MARK: - Init

    public init(
        font: NSFont = NSFont(name: "SFMono-Regular", size: 13)
            ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
        lineHeightMultiple: Double = 1.45,
        letterSpacing: Double = 1.0,
        tabWidth: Int = 4,
        wrapLines: Bool = false,
        isEditable: Bool = true,
        useSystemCursor: Bool = true,
        showLineNumbers: Bool = true,
        showMinimap: Bool = false,
        useThemeBackground: Bool = true,
        theme: EditorTheme = .dark,
        contentInsets: NSEdgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 32, right: 0)
    ) {
        self.font = font
        self.lineHeightMultiple = lineHeightMultiple
        self.letterSpacing = letterSpacing
        self.tabWidth = tabWidth
        self.wrapLines = wrapLines
        self.isEditable = isEditable
        self.useSystemCursor = useSystemCursor
        self.showLineNumbers = showLineNumbers
        self.showMinimap = showMinimap
        self.useThemeBackground = useThemeBackground
        self.theme = theme
        self.contentInsets = contentInsets
    }

    // MARK: - Derived

    /// Smaller font for gutter line numbers.
    public var lineNumberFont: NSFont {
        NSFont(descriptor: font.fontDescriptor, size: max(9, font.pointSize - 2)) ?? font
    }

    /// Computed line height in points (used for paragraph style and gutter).
    public var lineHeight: CGFloat {
        let metrics = font.ascender + abs(font.descender) + font.leading
        return ceil(metrics * lineHeightMultiple)
    }

    /// AppKit's effective default line height for this font.
    ///
    /// Using this instead of raw ascender/descender math more closely matches
    /// how TextKit positions glyphs inside each line fragment.
    public var fontLineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: font)
    }

    /// Optical vertical compensation for glyphs inside a fixed line-height row.
    ///
    /// To mimic editors like VSCode, we do two things:
    /// 1. center within the extra row height, and
    /// 2. add a small optical lift based on the font's ascender overshoot above
    ///    cap height, because code glyphs otherwise still look slightly low.
    public var baselineOffset: CGFloat {
        let extraLineSpace = max(0, lineHeight - fontLineHeight)
        let ascenderOvershoot = max(0, font.ascender - font.capHeight)
        let opticalBias = (ascenderOvershoot * 0.40) + (font.pointSize * 0.025)
        return (extraLineSpace / 2) + opticalBias
    }

    /// Extra kern to apply (NSAttributedString.Key.kern is extra space in points).
    public var kern: CGFloat {
        CGFloat(letterSpacing - 1.0) * font.pointSize
    }

    /// Width of one tab stop in points.
    public var tabStopWidth: CGFloat {
        let charWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        return charWidth * CGFloat(tabWidth)
    }

    // MARK: - Equatable (NSFont / NSColor are ObjC classes, need manual comparison)

    public static func == (lhs: EditorConfiguration, rhs: EditorConfiguration) -> Bool {
        lhs.font == rhs.font &&
        lhs.lineHeightMultiple == rhs.lineHeightMultiple &&
        lhs.letterSpacing == rhs.letterSpacing &&
        lhs.tabWidth == rhs.tabWidth &&
        lhs.wrapLines == rhs.wrapLines &&
        lhs.isEditable == rhs.isEditable &&
        lhs.useSystemCursor == rhs.useSystemCursor &&
        lhs.showLineNumbers == rhs.showLineNumbers &&
        lhs.showMinimap == rhs.showMinimap &&
        lhs.useThemeBackground == rhs.useThemeBackground &&
        lhs.theme == rhs.theme &&
        lhs.contentInsets.top == rhs.contentInsets.top &&
        lhs.contentInsets.left == rhs.contentInsets.left &&
        lhs.contentInsets.bottom == rhs.contentInsets.bottom &&
        lhs.contentInsets.right == rhs.contentInsets.right
    }
}
