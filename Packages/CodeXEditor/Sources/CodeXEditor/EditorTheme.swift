import AppKit

/// Syntax token style (color + font traits).
public struct TokenStyle: Equatable {
    public var color: NSColor
    public var bold: Bool
    public var italic: Bool

    public init(color: NSColor, bold: Bool = false, italic: Bool = false) {
        self.color = color
        self.bold = bold
        self.italic = italic
    }

    /// Returns NSAttributedString attributes for this style using the given base font.
    public func attributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        var descriptor = baseFont.fontDescriptor
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold   { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        if !traits.isEmpty {
            descriptor = descriptor.withSymbolicTraits(traits)
        }
        let font = NSFont(descriptor: descriptor, size: baseFont.pointSize) ?? baseFont
        return [.foregroundColor: color, .font: font]
    }
}

/// Full editor color theme — independent of any rendering library.
/// Token names correspond to tree-sitter capture names used by Neon in Phase 2.
public struct EditorTheme: Equatable {

    // MARK: - Editor chrome
    public var background: NSColor
    public var text: NSColor
    public var insertionPoint: NSColor
    public var lineHighlight: NSColor
    public var selection: NSColor
    public var invisibles: NSColor
    public var gutterBackground: NSColor
    public var gutterForeground: NSColor
    public var indentGuide: NSColor

    // MARK: - Syntax tokens
    public var keyword: TokenStyle
    public var string: TokenStyle
    public var number: TokenStyle
    public var comment: TokenStyle
    public var type: TokenStyle
    public var function_: TokenStyle
    public var variable: TokenStyle
    public var constant: TokenStyle
    public var attribute: TokenStyle
    public var operator_: TokenStyle

    public init(
        background: NSColor,
        text: NSColor,
        insertionPoint: NSColor,
        lineHighlight: NSColor,
        selection: NSColor,
        invisibles: NSColor,
        gutterBackground: NSColor,
        gutterForeground: NSColor,
        indentGuide: NSColor,
        keyword: TokenStyle,
        string: TokenStyle,
        number: TokenStyle,
        comment: TokenStyle,
        type: TokenStyle,
        function_: TokenStyle,
        variable: TokenStyle,
        constant: TokenStyle,
        attribute: TokenStyle,
        operator_: TokenStyle
    ) {
        self.background = background
        self.text = text
        self.insertionPoint = insertionPoint
        self.lineHighlight = lineHighlight
        self.selection = selection
        self.invisibles = invisibles
        self.gutterBackground = gutterBackground
        self.gutterForeground = gutterForeground
        self.indentGuide = indentGuide
        self.keyword = keyword
        self.string = string
        self.number = number
        self.comment = comment
        self.type = type
        self.function_ = function_
        self.variable = variable
        self.constant = constant
        self.attribute = attribute
        self.operator_ = operator_
    }

    /// NSAttributedString attributes for a given tree-sitter capture name.
    /// Phase 2 (Neon) will call this to apply syntax highlighting.
    public func attributes(for captureName: String, baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        tokenStyle(for: captureName).attributes(baseFont: baseFont)
    }

    private func tokenStyle(for captureName: String) -> TokenStyle {
        switch captureName {
        case _ where captureName.hasPrefix("keyword"):
            return keyword
        case _ where captureName.hasPrefix("string"):
            return string
        case _ where captureName.hasPrefix("number"):
            return number
        case _ where captureName.hasPrefix("comment"):
            return comment
        case "type", "type.builtin", "constructor", "class", "interface":
            return type
        case _ where captureName.hasPrefix("type"):
            return type
        case "function", "function.call", "function.method", "method", "method.call":
            return function_
        case _ where captureName.hasPrefix("function"):
            return function_
        case "variable", "variable.parameter", "variable.member", "property":
            return variable
        case "constant", "constant.builtin", "boolean", "null", "undefined":
            return constant
        case _ where captureName.hasPrefix("constant"):
            return constant
        case "attribute", "decorator", "annotation":
            return attribute
        case _ where captureName.hasPrefix("attribute"):
            return attribute
        case "operator", "punctuation.delimiter", "punctuation.bracket":
            return operator_
        default:
            return TokenStyle(color: text)
        }
    }
}

// MARK: - Built-in Themes

public extension EditorTheme {

    /// Xcode Default Dark
    static let dark = EditorTheme(
        background:      NSColor(srgbRed: 0.118, green: 0.125, blue: 0.161, alpha: 1),
        text:            NSColor(srgbRed: 0.859, green: 0.871, blue: 0.886, alpha: 1),
        insertionPoint:  .white,
        lineHighlight:   NSColor(srgbRed: 0.145, green: 0.157, blue: 0.200, alpha: 1),
        selection:       NSColor(srgbRed: 0.263, green: 0.302, blue: 0.412, alpha: 1),
        invisibles:      NSColor(srgbRed: 0.424, green: 0.435, blue: 0.459, alpha: 1),
        gutterBackground:NSColor(srgbRed: 0.118, green: 0.125, blue: 0.161, alpha: 1),
        gutterForeground:NSColor(srgbRed: 0.424, green: 0.435, blue: 0.459, alpha: 1),
        indentGuide:     NSColor(srgbRed: 0.859, green: 0.871, blue: 0.886, alpha: 0.12),
        keyword:   TokenStyle(color: NSColor(srgbRed: 0.988, green: 0.373, blue: 0.639, alpha: 1), bold: true),
        string:    TokenStyle(color: NSColor(srgbRed: 0.988, green: 0.408, blue: 0.365, alpha: 1)),
        number:    TokenStyle(color: NSColor(srgbRed: 0.820, green: 0.749, blue: 0.412, alpha: 1)),
        comment:   TokenStyle(color: NSColor(srgbRed: 0.424, green: 0.475, blue: 0.529, alpha: 1), italic: true),
        type:      TokenStyle(color: NSColor(srgbRed: 0.361, green: 0.827, blue: 0.757, alpha: 1)),
        function_: TokenStyle(color: NSColor(srgbRed: 0.255, green: 0.706, blue: 0.741, alpha: 1)),
        variable:  TokenStyle(color: NSColor(srgbRed: 0.255, green: 0.706, blue: 0.741, alpha: 1)),
        constant:  TokenStyle(color: NSColor(srgbRed: 0.820, green: 0.749, blue: 0.412, alpha: 1)),
        attribute: TokenStyle(color: NSColor(srgbRed: 0.776, green: 0.600, blue: 0.439, alpha: 1)),
        operator_: TokenStyle(color: NSColor(srgbRed: 0.859, green: 0.871, blue: 0.886, alpha: 1))
    )

    /// Xcode Default Light
    static let light = EditorTheme(
        background:      NSColor(srgbRed: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1),
        text:            NSColor(srgbRed: 0.0,   green: 0.0,   blue: 0.0,   alpha: 1),
        insertionPoint:  .black,
        lineHighlight:   NSColor(srgbRed: 0.925, green: 0.961, blue: 1.0,   alpha: 1),
        selection:       NSColor(srgbRed: 0.643, green: 0.804, blue: 1.0,   alpha: 1),
        invisibles:      NSColor(srgbRed: 0.843, green: 0.843, blue: 0.843, alpha: 1),
        gutterBackground:NSColor(srgbRed: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1),
        gutterForeground:NSColor(srgbRed: 0.5,   green: 0.5,   blue: 0.5,   alpha: 1),
        indentGuide:     NSColor(srgbRed: 0.0,   green: 0.0,   blue: 0.0,   alpha: 0.09),
        keyword:   TokenStyle(color: NSColor(srgbRed: 0.608, green: 0.153, blue: 0.690, alpha: 1), bold: true),
        string:    TokenStyle(color: NSColor(srgbRed: 0.769, green: 0.102, blue: 0.086, alpha: 1)),
        number:    TokenStyle(color: NSColor(srgbRed: 0.110, green: 0.0,   blue: 0.812, alpha: 1)),
        comment:   TokenStyle(color: NSColor(srgbRed: 0.365, green: 0.420, blue: 0.467, alpha: 1), italic: true),
        type:      TokenStyle(color: NSColor(srgbRed: 0.043, green: 0.294, blue: 0.608, alpha: 1)),
        function_: TokenStyle(color: NSColor(srgbRed: 0.196, green: 0.490, blue: 0.584, alpha: 1)),
        variable:  TokenStyle(color: NSColor(srgbRed: 0.196, green: 0.490, blue: 0.584, alpha: 1)),
        constant:  TokenStyle(color: NSColor(srgbRed: 0.141, green: 0.192, blue: 0.812, alpha: 1)),
        attribute: TokenStyle(color: NSColor(srgbRed: 0.506, green: 0.404, blue: 0.200, alpha: 1)),
        operator_: TokenStyle(color: NSColor(srgbRed: 0.0,   green: 0.0,   blue: 0.0,   alpha: 1))
    )
}
