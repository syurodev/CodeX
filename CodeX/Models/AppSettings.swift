import SwiftUI
import CodeXEditor

/// Root settings scope for the first Xcode-style preferences milestone.
/// Phase 0 intentionally keeps the domain narrow: themes, editing, and terminal.
struct AppSettings: Codable, Equatable {
    var editor: EditorSettings = EditorSettings()
    var editorTheme: EditorThemePreference = .system
    var terminal: TerminalSettings = TerminalSettings()
    var format: FormatSettings = FormatSettings()
    var tools: ToolsSettings = ToolsSettings()
    var aiCompletion: AICompletionSettings = AICompletionSettings()

    // Custom decoder so that keys added after the initial release (e.g. "format",
    // "tools") don't crash with keyNotFound when reading older persisted data.
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        editor        = try c.decodeIfPresent(EditorSettings.self,        forKey: .editor)        ?? EditorSettings()
        editorTheme   = try c.decodeIfPresent(EditorThemePreference.self, forKey: .editorTheme)   ?? .system
        terminal      = try c.decodeIfPresent(TerminalSettings.self,      forKey: .terminal)      ?? TerminalSettings()
        format        = try c.decodeIfPresent(FormatSettings.self,        forKey: .format)        ?? FormatSettings()
        tools         = try c.decodeIfPresent(ToolsSettings.self,         forKey: .tools)         ?? ToolsSettings()
        aiCompletion  = try c.decodeIfPresent(AICompletionSettings.self,  forKey: .aiCompletion)  ?? AICompletionSettings()
    }
}

// MARK: - Trailing Comma

enum TrailingCommaStyle: String, Codable, CaseIterable, Equatable, Identifiable {
    case none = "none"
    case es5  = "es5"
    case all  = "all"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .es5:  "ES5"
        case .all:  "All"
        }
    }

    /// Value passed to Prettier `--trailing-comma` flag.
    var prettierValue: String { rawValue }

    /// Value passed to Biome `trailingCommas` JSON key.
    var biomeValue: String { rawValue }
}

// MARK: - DefaultFormatConfig

/// Basic style options used as fallback when a project has no Prettier / Biome config file.
struct DefaultFormatConfig: Codable, Equatable {
    var tab_width: Int               = 2
    var print_width: Int             = 100
    var single_quote: Bool           = false
    var semicolons: Bool             = true
    var trailing_comma: TrailingCommaStyle = .es5

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tab_width      = try c.decodeIfPresent(Int.self,                forKey: .tab_width)      ?? 2
        print_width    = try c.decodeIfPresent(Int.self,                forKey: .print_width)    ?? 100
        single_quote   = try c.decodeIfPresent(Bool.self,               forKey: .single_quote)   ?? false
        semicolons     = try c.decodeIfPresent(Bool.self,               forKey: .semicolons)     ?? true
        trailing_comma = try c.decodeIfPresent(TrailingCommaStyle.self, forKey: .trailing_comma) ?? .es5
    }
}

// MARK: - FormatSettings

struct FormatSettings: Codable, Equatable {
    /// Enable Prettier integration for JavaScript/TypeScript files
    var enable_prettier_js_ts: Bool = true

    /// Automatically format JS/TS files on save
    var format_on_save_js_ts: Bool = false

    /// Default style applied when the project has no Prettier / Biome config.
    var default_style: DefaultFormatConfig = DefaultFormatConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enable_prettier_js_ts = try c.decodeIfPresent(Bool.self,              forKey: .enable_prettier_js_ts) ?? true
        format_on_save_js_ts  = try c.decodeIfPresent(Bool.self,              forKey: .format_on_save_js_ts)  ?? false
        default_style         = try c.decodeIfPresent(DefaultFormatConfig.self, forKey: .default_style)       ?? DefaultFormatConfig()
    }
}

// MARK: - ToolsSettings

struct ToolsSettings: Codable, Equatable {
    /// Optional absolute path to the `prettier` executable. Empty = resolve via PATH.
    var prettier_path: String = ""

    /// Optional absolute path to the `biome` executable. Empty = use bundled binary or Homebrew fallback.
    var biome_path: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prettier_path = try c.decodeIfPresent(String.self, forKey: .prettier_path) ?? ""
        biome_path    = try c.decodeIfPresent(String.self, forKey: .biome_path)    ?? ""
    }
}

// MARK: - AICompletionSettings

struct AICompletionSettings: Codable, Equatable {
    /// Bật/tắt tính năng AI Completion
    var enabled: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    }
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
