import AppKit
import CodeEditSourceEditor

/// Editor themes matching Xcode's built-in themes.
/// A settings screen can switch between these later.
enum CodeXTheme {

    // MARK: - Xcode Default (Dark)

    static let `default` = EditorTheme(
        // Plain text
        text: .init(color: NSColor(srgbRed: 0.859, green: 0.871, blue: 0.886, alpha: 1.0)),
        // Cursor
        insertionPoint: .white,
        // Invisible characters
        invisibles: .init(color: NSColor(srgbRed: 0.424, green: 0.435, blue: 0.459, alpha: 1.0)),
        // Editor background
        background: NSColor(srgbRed: 0.118, green: 0.125, blue: 0.161, alpha: 1.0),
        // Current line highlight
        lineHighlight: NSColor(srgbRed: 0.145, green: 0.157, blue: 0.200, alpha: 1.0),
        // Selection
        selection: NSColor(srgbRed: 0.263, green: 0.302, blue: 0.412, alpha: 1.0),
        // Keywords (import, let, var, func, return, if, else, etc.)
        keywords: .init(color: NSColor(srgbRed: 0.988, green: 0.373, blue: 0.639, alpha: 1.0), bold: true),
        // Commands / preprocessor
        commands: .init(color: NSColor(srgbRed: 0.988, green: 0.373, blue: 0.639, alpha: 1.0)),
        // Types (class, struct, enum names)
        types: .init(color: NSColor(srgbRed: 0.361, green: 0.827, blue: 0.757, alpha: 1.0)),
        // Attributes (@main, @State, etc.)
        attributes: .init(color: NSColor(srgbRed: 0.776, green: 0.600, blue: 0.439, alpha: 1.0)),
        // Variables / properties
        variables: .init(color: NSColor(srgbRed: 0.255, green: 0.706, blue: 0.741, alpha: 1.0)),
        // Values / constants
        values: .init(color: NSColor(srgbRed: 0.255, green: 0.706, blue: 0.741, alpha: 1.0)),
        // Numbers
        numbers: .init(color: NSColor(srgbRed: 0.820, green: 0.749, blue: 0.412, alpha: 1.0)),
        // Strings
        strings: .init(color: NSColor(srgbRed: 0.988, green: 0.408, blue: 0.365, alpha: 1.0)),
        // Characters
        characters: .init(color: NSColor(srgbRed: 0.820, green: 0.749, blue: 0.412, alpha: 1.0)),
        // Comments
        comments: .init(color: NSColor(srgbRed: 0.424, green: 0.475, blue: 0.529, alpha: 1.0), italic: true)
    )

    // MARK: - Xcode Default (Light)

    static let light = EditorTheme(
        // Plain text
        text: .init(color: NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)),
        // Cursor
        insertionPoint: .black,
        // Invisible characters
        invisibles: .init(color: NSColor(srgbRed: 0.843, green: 0.843, blue: 0.843, alpha: 1.0)),
        // Editor background
        background: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        // Current line highlight
        lineHighlight: NSColor(srgbRed: 0.925, green: 0.961, blue: 1.0, alpha: 1.0),
        // Selection
        selection: NSColor(srgbRed: 0.643, green: 0.804, blue: 1.0, alpha: 1.0),
        // Keywords
        keywords: .init(color: NSColor(srgbRed: 0.608, green: 0.153, blue: 0.690, alpha: 1.0), bold: true),
        // Commands / preprocessor
        commands: .init(color: NSColor(srgbRed: 0.498, green: 0.231, blue: 0.039, alpha: 1.0)),
        // Types
        types: .init(color: NSColor(srgbRed: 0.043, green: 0.294, blue: 0.608, alpha: 1.0)),
        // Attributes
        attributes: .init(color: NSColor(srgbRed: 0.506, green: 0.404, blue: 0.200, alpha: 1.0)),
        // Variables / properties
        variables: .init(color: NSColor(srgbRed: 0.196, green: 0.490, blue: 0.584, alpha: 1.0)),
        // Values / constants
        values: .init(color: NSColor(srgbRed: 0.141, green: 0.192, blue: 0.812, alpha: 1.0)),
        // Numbers
        numbers: .init(color: NSColor(srgbRed: 0.110, green: 0.000, blue: 0.812, alpha: 1.0)),
        // Strings
        strings: .init(color: NSColor(srgbRed: 0.769, green: 0.102, blue: 0.086, alpha: 1.0)),
        // Characters
        characters: .init(color: NSColor(srgbRed: 0.110, green: 0.000, blue: 0.812, alpha: 1.0)),
        // Comments
        comments: .init(color: NSColor(srgbRed: 0.365, green: 0.420, blue: 0.467, alpha: 1.0), italic: true)
    )
}
