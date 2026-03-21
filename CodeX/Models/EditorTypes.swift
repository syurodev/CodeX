import Foundation
import CoreGraphics
import AppKit

public struct CodeLanguage: Equatable, Hashable {
    public let id: String

    public static let `default` = CodeLanguage(id: "plaintext")
    public static let javascript = CodeLanguage(id: "javascript")
    public static let typescript = CodeLanguage(id: "typescript")

    public init(id: String) {
        self.id = id
    }
}

public struct EditorState: Equatable {
    public var cursorPositions: [CursorPosition]
    public var scrollPosition: CGPoint

    public var primaryCursor: CursorPosition {
        cursorPositions.first ?? CursorPosition()
    }

    public init(
        cursorPositions: [CursorPosition] = [CursorPosition()],
        scrollPosition: CGPoint = .zero
    ) {
        self.cursorPositions = cursorPositions
        self.scrollPosition = scrollPosition
    }
}

public struct CursorPosition: Equatable, Hashable {
    public var line: Int
    public var column: Int

    public init(line: Int = 0, column: Int = 0) {
        self.line = line
        self.column = column
    }
}

public enum DiagnosticSeverity: Equatable {
    case error
    case warning
    case info
    case hint
}

public enum DiagnosticSource: Equatable, Hashable {
    case typescript(code: Int?)
    case eslint(rule: String?)
    case biomeLint(rule: String)
    case biomeFormat
    case lsp(source: String, code: String?)
    case unknown
}

public struct Diagnostic: Equatable {
    public var range: NSRange
    public var severity: DiagnosticSeverity
    public var message: String
    public var source: DiagnosticSource

    public init(range: NSRange, severity: DiagnosticSeverity, message: String, source: DiagnosticSource = .unknown) {
        self.range = range
        self.severity = severity
        self.message = message
        self.source = source
    }
}

public struct DefinitionLink {
    public var url: URL?
    public var line: Int
    public var column: Int
    public var targetUri: String
    public var targetRange: NSRange

    public init(url: URL? = nil, line: Int = 0, column: Int = 0, targetUri: String = "", targetRange: NSRange = NSRange()) {
        self.url = url
        self.line = line
        self.column = column
        self.targetUri = targetUri
        self.targetRange = targetRange
    }
}

public protocol DefinitionDelegate: AnyObject {
    func queryDefinition(forRange range: NSRange, cursor: CursorPosition, in text: String, url: URL?) async -> [DefinitionLink]?
}

public protocol InlineCompletionDelegate: AnyObject {
    func inlineCompletionRequested(prefix: String, suffix: String) async -> String?
}

public protocol CompletionDelegate: AnyObject {
    var triggerCharacters: Set<String> { get }
    func completionSuggestionsRequested(at cursor: CursorPosition, in text: String) async -> [any CompletionEntry]?
    func completionApplied(_ entry: any CompletionEntry, replacingRange range: NSRange)
}

public protocol CompletionEntry {
    var text: String { get }
}

public class LSPSuggestionEntry: CompletionEntry {
    public var text: String
    public var label: String
    /// LSP CompletionItemKind (1–25)
    public var kind: Int?

    public init(text: String, label: String = "", kind: Int? = nil) {
        self.text = text
        self.label = label.isEmpty ? text : label
        self.kind = kind
    }
}

public struct EditorTheme: Equatable {
    public var background: NSColor
    public var text: NSColor
    public var selection: NSColor
    public var cursor: NSColor
    public var gutterBackground: NSColor
    public var gutterForeground: NSColor
    public var lineHighlight: NSColor

    // Syntax colors
    public var keyword: NSColor
    public var type: NSColor
    public var string: NSColor
    public var number: NSColor
    public var comment: NSColor
    public var function: NSColor
    public var variable: NSColor

    public static let light = EditorTheme(
        background: .white,
        text: .black,
        selection: NSColor.selectedTextBackgroundColor,
        cursor: .black,
        gutterBackground: NSColor(white: 0.95, alpha: 1.0),
        gutterForeground: NSColor(white: 0.5, alpha: 1.0),
        lineHighlight: NSColor(white: 0.95, alpha: 1.0),
        keyword: NSColor(red: 0.67, green: 0.21, blue: 0.56, alpha: 1.0),
        type: NSColor(red: 0.11, green: 0.53, blue: 0.60, alpha: 1.0),
        string: NSColor(red: 0.77, green: 0.13, blue: 0.09, alpha: 1.0),
        number: NSColor(red: 0.11, green: 0.00, blue: 0.81, alpha: 1.0),
        comment: NSColor(red: 0.42, green: 0.45, blue: 0.48, alpha: 1.0),
        function: NSColor(red: 0.24, green: 0.33, blue: 0.71, alpha: 1.0),
        variable: .black
    )

    public static let dark = EditorTheme(
        background: NSColor(white: 0.1, alpha: 1.0),
        text: .white,
        selection: NSColor.selectedTextBackgroundColor,
        cursor: .white,
        gutterBackground: NSColor(white: 0.15, alpha: 1.0),
        gutterForeground: NSColor(white: 0.5, alpha: 1.0),
        lineHighlight: NSColor(white: 0.15, alpha: 1.0),
        keyword: NSColor(red: 0.93, green: 0.42, blue: 0.81, alpha: 1.0),
        type: NSColor(red: 0.51, green: 0.83, blue: 0.88, alpha: 1.0),
        string: NSColor(red: 0.99, green: 0.41, blue: 0.37, alpha: 1.0),
        number: NSColor(red: 0.83, green: 0.68, blue: 0.99, alpha: 1.0),
        comment: NSColor(red: 0.45, green: 0.53, blue: 0.60, alpha: 1.0),
        function: NSColor(red: 0.49, green: 0.71, blue: 0.99, alpha: 1.0),
        variable: .white
    )

    public init(background: NSColor, text: NSColor, selection: NSColor, cursor: NSColor, gutterBackground: NSColor, gutterForeground: NSColor, lineHighlight: NSColor, keyword: NSColor, type: NSColor, string: NSColor, number: NSColor, comment: NSColor, function: NSColor, variable: NSColor) {
        self.background = background
        self.text = text
        self.selection = selection
        self.cursor = cursor
        self.gutterBackground = gutterBackground
        self.gutterForeground = gutterForeground
        self.lineHighlight = lineHighlight
        self.keyword = keyword
        self.type = type
        self.string = string
        self.number = number
        self.comment = comment
        self.function = function
        self.variable = variable
    }
}

public struct EditorConfiguration: Equatable {
    public var font: NSFont
    public var theme: EditorTheme
    public var lineHeightMultiple: CGFloat
    public var letterSpacing: CGFloat
    public var tabWidth: Int
    public var wrapLines: Bool
    public var isEditable: Bool
    public var useSystemCursor: Bool
    public var showLineNumbers: Bool
    public var showMinimap: Bool
    public var showCurrentLineHighlight: Bool
    public var showIndentGuides: Bool
    public var showGutterMarkers: Bool
    public var useThemeBackground: Bool
    public var contentInsets: NSEdgeInsets

    public var tabStopWidth: CGFloat {
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        return spaceWidth * CGFloat(tabWidth)
    }

    public init(
        font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular),
        theme: EditorTheme = .dark,
        lineHeightMultiple: CGFloat = 1.2,
        letterSpacing: CGFloat = 0,
        tabWidth: Int = 4,
        wrapLines: Bool = false,
        isEditable: Bool = true,
        useSystemCursor: Bool = false,
        showLineNumbers: Bool = true,
        showMinimap: Bool = false,
        showCurrentLineHighlight: Bool = true,
        showIndentGuides: Bool = false,
        showGutterMarkers: Bool = false,
        useThemeBackground: Bool = true,
        contentInsets: NSEdgeInsets = NSEdgeInsets()
    ) {
        self.font = font
        self.theme = theme
        self.lineHeightMultiple = lineHeightMultiple
        self.letterSpacing = letterSpacing
        self.tabWidth = tabWidth
        self.wrapLines = wrapLines
        self.isEditable = isEditable
        self.useSystemCursor = useSystemCursor
        self.showLineNumbers = showLineNumbers
        self.showMinimap = showMinimap
        self.showCurrentLineHighlight = showCurrentLineHighlight
        self.showIndentGuides = showIndentGuides
        self.showGutterMarkers = showGutterMarkers
        self.useThemeBackground = useThemeBackground
        self.contentInsets = contentInsets
    }
}

