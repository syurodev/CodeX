import SwiftUI
import CodeEditSourceEditor

/// LSPSuggestionEntry thực thi CodeSuggestionEntry để hiển thị trong editor.
struct LSPSuggestionEntry: CodeSuggestionEntry {
    var label: String
    var detail: String?
    var documentation: String?
    var pathComponents: [String]?
    var targetPosition: CursorPosition?
    var sourcePreview: String?
    
    var image: Image {
        Image(systemName: "symbol") // Tạm thời dùng icon mặc định
    }
    
    var imageColor: Color {
        .accentColor
    }
    
    var deprecated: Bool = false
    
    init(label: String, detail: String? = nil, documentation: String? = nil) {
        self.label = label
        self.detail = detail
        self.documentation = documentation
    }
}
