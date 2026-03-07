import Foundation
import Observation
import CodeEditLanguages
import CodeEditSourceEditor

@Observable
class EditorDocument: Identifiable {
    let id: UUID
    let url: URL
    var text: String
    var language: CodeLanguage
    var isModified: Bool
    var editorState: SourceEditorState

    var fileName: String { url.lastPathComponent }

    init(url: URL, text: String, language: CodeLanguage) {
        self.id = UUID()
        self.url = url
        self.text = text
        self.language = language
        self.isModified = false
        self.editorState = SourceEditorState()
    }
}
