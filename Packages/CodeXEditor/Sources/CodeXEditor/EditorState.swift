import Foundation

/// A cursor position expressed as 1-based line and column numbers.
public struct CursorPosition: Equatable, Hashable, Codable, Sendable {
    public var line: Int
    public var column: Int

    public init(line: Int = 1, column: Int = 1) {
        self.line = line
        self.column = column
    }

    /// Convert to a 0-based NSRange offset within `string`.
    public func offset(in string: String) -> Int? {
        var currentLine = 1
        var currentCol = 1
        for (i, char) in string.enumerated() {
            if currentLine == line && currentCol == column { return i }
            if char == "\n" {
                currentLine += 1
                currentCol = 1
            } else {
                currentCol += 1
            }
        }
        return nil
    }
}

/// Serializable editor state — cursor positions and scroll offset.
/// Replaces `SourceEditorState` from CodeEditSourceEditor.
public struct EditorState: Equatable, Codable, Sendable {
    public var cursorPositions: [CursorPosition]
    public var scrollPosition: CGPoint

    public init(
        cursorPositions: [CursorPosition] = [CursorPosition()],
        scrollPosition: CGPoint = .zero
    ) {
        self.cursorPositions = cursorPositions
        self.scrollPosition = scrollPosition
    }

    public var primaryCursor: CursorPosition {
        cursorPositions.first ?? CursorPosition()
    }
}
