import AppKit
import SwiftTreeSitter
import CodeEditLanguages

/// Provides incremental syntax highlighting by driving SwiftTreeSitter directly.
///
/// Lifecycle:
/// - Call `attach(to:language:theme:font:)` after the text view is ready.
/// - Call `update(theme:font:language:)` when theme or font changes.
/// - Call `attach` again (or `detach`) when the language changes.
/// - The highlighter becomes `NSTextStorageDelegate` and re-highlights on every character edit.
@MainActor
final class SyntaxHighlighter: NSObject {

    private weak var textView: NSTextView?
    private weak var textStorage: NSTextStorage?
    private var parser: Parser?
    private var query: Query?
    private var theme: EditorTheme = .dark
    private var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    // MARK: - Public API

    func attach(to textView: NSTextView, language: CodeLanguage, theme: EditorTheme, font: NSFont) {
        detach()
        self.textView = textView
        self.theme = theme
        self.font = font
        build(language: language, storage: textView.textStorage)
    }

    func detach() {
        textStorage?.delegate = nil
        textStorage = nil
        textView = nil
        parser = nil
        query = nil
    }

    func update(theme: EditorTheme, font: NSFont, language: CodeLanguage) {
        self.theme = theme
        self.font = font
        guard let storage = textStorage else { return }
        if parser != nil {
            // Re-highlight with new colours, no need to rebuild the parser
            applyHighlights(to: storage)
        } else if let tv = textView {
            // Parser lost — rebuild (e.g. theme switch was the first call after attach)
            build(language: language, storage: tv.textStorage)
        }
    }

    // MARK: - Private

    private func build(language: CodeLanguage, storage: NSTextStorage?) {
        guard
            let tsLanguage = language.language,
            let tsQuery = TreeSitterModel.shared.query(for: language.id),
            let storage
        else { return }

        let p = Parser()
        guard (try? p.setLanguage(tsLanguage)) != nil else { return }

        self.parser = p
        self.query = tsQuery
        self.textStorage = storage
        storage.delegate = self

        applyHighlights(to: storage)
    }

    private func applyHighlights(to storage: NSTextStorage) {
        guard let parser, let query else { return }
        let noTree: Tree? = nil
        guard let tree = parser.parse(tree: noTree, string: storage.string) else { return }

        let highlights = query.execute(in: tree).highlights()
        let totalLength = storage.length
        let capturedTheme = theme
        let capturedFont = font

        storage.beginEditing()
        for namedRange in highlights {
            let range = namedRange.range
            guard range.location != NSNotFound,
                  range.length > 0,
                  range.location + range.length <= totalLength else { continue }
            let attrs = capturedTheme.attributes(for: namedRange.name, baseFont: capturedFont)
            storage.addAttributes(attrs, range: range)
        }
        storage.endEditing()
    }
}

// MARK: - NSTextStorageDelegate

extension SyntaxHighlighter: NSTextStorageDelegate {

    // nonisolated required by NSTextStorageDelegate; AppKit always calls on main thread.

    nonisolated public func textStorage(
        _ textStorage: NSTextStorage,
        willProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {}

    nonisolated public func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(NSTextStorageEditActions.editedCharacters) else { return }
        MainActor.assumeIsolated {
            self.applyHighlights(to: textStorage)
        }
    }
}
