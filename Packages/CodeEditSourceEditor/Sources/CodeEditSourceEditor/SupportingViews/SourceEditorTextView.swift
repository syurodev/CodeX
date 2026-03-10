//
//  SourceEditorTextView.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 7/23/25.
//

import AppKit
import CodeEditTextView

final class SourceEditorTextView: TextView {
    var additionalCursorRects: [(NSRect, NSCursor)] = []
    var minimumNonWrappingWidth: CGFloat = 0

    private func constrainedSize(_ size: NSSize) -> NSSize {
        guard !wrapLines else { return size }
        var size = size
        size.width = max(size.width, minimumNonWrappingWidth, enclosingScrollView?.contentSize.width ?? 0)
        return size
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(constrainedSize(newSize))
    }

    override var frame: NSRect {
        get {
            super.frame
        }
        set {
            var frame = newValue
            frame.size = constrainedSize(frame.size)
            super.frame = frame
        }
    }

    override func resetCursorRects() {
        discardCursorRects()
        super.resetCursorRects()
        additionalCursorRects.forEach { (rect, cursor) in
            addCursorRect(rect, cursor: cursor)
        }
    }
}
