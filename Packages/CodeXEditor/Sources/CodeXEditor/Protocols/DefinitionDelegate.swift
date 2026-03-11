import Foundation

/// Represents a jump-to-definition target.
public struct DefinitionLink: Sendable {
    /// Target file URL. `nil` means same document.
    public var url: URL?
    /// 1-based target line.
    public var line: Int
    /// 1-based target column.
    public var column: Int
    /// Display label (e.g. file name).
    public var label: String
    /// Short preview of the target line.
    public var sourcePreview: String?

    public init(
        url: URL? = nil,
        line: Int,
        column: Int,
        label: String,
        sourcePreview: String? = nil
    ) {
        self.url = url
        self.line = line
        self.column = column
        self.label = label
        self.sourcePreview = sourcePreview
    }
}

/// Implement this to provide jump-to-definition behavior.
@MainActor
public protocol DefinitionDelegate: AnyObject {
    /// Called when the user triggers jump-to-definition (cmd+click or F12).
    /// - Parameters:
    ///   - range: The NSRange the user clicked on.
    ///   - cursor: Current cursor position.
    ///   - text: Full document text.
    ///   - url: Current document URL (for relative resolution).
    /// - Returns: Array of definition targets, or nil if unavailable.
    func queryDefinition(
        forRange range: NSRange,
        cursor: CursorPosition,
        in text: String,
        url: URL?
    ) async -> [DefinitionLink]?

    /// Called to open a returned DefinitionLink (navigate to another file).
    func openLink(_ link: DefinitionLink)
}
