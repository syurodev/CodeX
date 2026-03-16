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

    public init(text: String, label: String = "") {
        self.text = text
        self.label = label.isEmpty ? text : label
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

    public static let light = EditorTheme(
        background: .white,
        text: .black,
        selection: NSColor.selectedTextBackgroundColor,
        cursor: .black,
        gutterBackground: NSColor(white: 0.95, alpha: 1.0),
        gutterForeground: NSColor(white: 0.5, alpha: 1.0),
        lineHighlight: NSColor(white: 0.95, alpha: 1.0)
    )

    public static let dark = EditorTheme(
        background: NSColor(white: 0.1, alpha: 1.0),
        text: .white,
        selection: NSColor.selectedTextBackgroundColor,
        cursor: .white,
        gutterBackground: NSColor(white: 0.15, alpha: 1.0),
        gutterForeground: NSColor(white: 0.5, alpha: 1.0),
        lineHighlight: NSColor(white: 0.15, alpha: 1.0)
    )

    public init(background: NSColor, text: NSColor, selection: NSColor, cursor: NSColor, gutterBackground: NSColor, gutterForeground: NSColor, lineHighlight: NSColor) {
        self.background = background
        self.text = text
        self.selection = selection
        self.cursor = cursor
        self.gutterBackground = gutterBackground
        self.gutterForeground = gutterForeground
        self.lineHighlight = lineHighlight
    }
}

public struct EditorConfiguration {
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

