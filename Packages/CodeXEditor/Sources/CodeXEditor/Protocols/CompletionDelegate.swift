import Foundation

/// A single completion item returned by a delegate.
public protocol CompletionEntry: AnyObject {
    var label: String { get }
    var detail: String? { get }
    var documentation: String? { get }
    /// Text to insert when this entry is accepted. Defaults to `label` if nil.
    var insertText: String? { get }
}

/// Implement this to provide code completion suggestions.
/// Unlike CodeEditSourceEditor's CodeSuggestionDelegate, this protocol does NOT
/// expose internal editor types (TextViewController) — only data primitives.
@MainActor
public protocol CompletionDelegate: AnyObject {
    /// Characters that should trigger completion automatically.
    var triggerCharacters: Set<String> { get }

    /// Called when the editor requests completions at the given cursor position.
    /// - Parameters:
    ///   - cursor: Current cursor position (1-based line/column).
    ///   - text: Full document text at the time of the request.
    /// - Returns: Array of completion entries, or nil to show nothing.
    func completionSuggestionsRequested(
        at cursor: CursorPosition,
        in text: String
    ) async -> [any CompletionEntry]?

    /// Called when the user accepts a completion entry.
    func completionApplied(_ entry: any CompletionEntry, replacingRange range: NSRange)
}
