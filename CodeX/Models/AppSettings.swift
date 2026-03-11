import SwiftUI
import CodeXEditor

/// Root settings scope for the first Xcode-style preferences milestone.
/// Phase 0 intentionally keeps the domain narrow: themes, editing, and terminal.
struct AppSettings: Codable, Equatable {
    var editor: EditorSettings = EditorSettings()
    var editorTheme: EditorThemePreference = .system
    var terminal: TerminalSettings = TerminalSettings()
}

enum EditorThemePreference: String, Codable, CaseIterable, Equatable {
    case system
    case xcodeLight
    case xcodeDark

    var displayName: String {
        switch self {
        case .system: "Follow System"
        case .xcodeLight: "Xcode Light"
        case .xcodeDark: "Xcode Dark"
        }
    }

    func resolvedTheme(for colorScheme: ColorScheme) -> EditorTheme {
        switch self {
        case .system:
            colorScheme == .dark ? .dark : .light
        case .xcodeLight:
            .light
        case .xcodeDark:
            .dark
        }
    }
}