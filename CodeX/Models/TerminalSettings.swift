import AppKit
import SwiftUI
import SwiftTerm

struct TerminalSettings: Codable, Equatable {
    var theme: TerminalThemePreference = .system
    var font: TerminalFontPreference = .systemMonospaced
    var font_size: CGFloat = NSFont.systemFontSize
    var cursor_style: TerminalCursorStylePreference = .blinkBlock

    init(
        theme: TerminalThemePreference = .system,
        font: TerminalFontPreference = .systemMonospaced,
        font_size: CGFloat = NSFont.systemFontSize,
        cursor_style: TerminalCursorStylePreference = .blinkBlock
    ) {
        self.theme = theme
        self.font = font
        self.font_size = font_size
        self.cursor_style = cursor_style
    }

    private enum CodingKeys: String, CodingKey {
        case theme
        case font
        case font_size
        case cursor_style
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(TerminalThemePreference.self, forKey: .theme) ?? .system
        font = try container.decodeIfPresent(TerminalFontPreference.self, forKey: .font) ?? .systemMonospaced
        font_size = try container.decodeIfPresent(CGFloat.self, forKey: .font_size) ?? NSFont.systemFontSize
        cursor_style = try container.decodeIfPresent(TerminalCursorStylePreference.self, forKey: .cursor_style) ?? .blinkBlock
    }

    var resolved_font: NSFont {
        font.resolvedFont(size: font_size)
    }

    var resolved_cursor_style: CursorStyle {
        cursor_style.swiftTermCursorStyle
    }
}

enum TerminalFontPreference: String, Codable, CaseIterable, Equatable {
    case systemMonospaced
    case menlo
    case monaco
    case courier

    var displayName: String {
        switch self {
        case .systemMonospaced: "System Mono"
        case .menlo: "Menlo"
        case .monaco: "Monaco"
        case .courier: "Courier"
        }
    }

    func resolvedFont(size: CGFloat) -> NSFont {
        let fallback = NSFont.userFixedPitchFont(ofSize: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)

        switch self {
        case .systemMonospaced:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .menlo:
            return NSFont(name: "Menlo-Regular", size: size) ?? fallback
        case .monaco:
            return NSFont(name: "Monaco", size: size) ?? fallback
        case .courier:
            return NSFont(name: "Courier", size: size) ?? fallback
        }
    }
}

enum TerminalCursorStylePreference: String, Codable, CaseIterable, Equatable {
    case blinkBlock
    case steadyBlock
    case blinkUnderline
    case steadyUnderline
    case blinkBar
    case steadyBar

    var displayName: String {
        switch self {
        case .blinkBlock: "Blinking Block"
        case .steadyBlock: "Steady Block"
        case .blinkUnderline: "Blinking Underline"
        case .steadyUnderline: "Steady Underline"
        case .blinkBar: "Blinking Bar"
        case .steadyBar: "Steady Bar"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .blinkBlock: "Blink Block"
        case .steadyBlock: "Steady Block"
        case .blinkUnderline: "Blink Underline"
        case .steadyUnderline: "Steady Underline"
        case .blinkBar: "Blink Bar"
        case .steadyBar: "Steady Bar"
        }
    }

    var swiftTermCursorStyle: CursorStyle {
        switch self {
        case .blinkBlock: .blinkBlock
        case .steadyBlock: .steadyBlock
        case .blinkUnderline: .blinkUnderline
        case .steadyUnderline: .steadyUnderline
        case .blinkBar: .blinkBar
        case .steadyBar: .steadyBar
        }
    }
}

enum TerminalThemePreference: String, Codable, CaseIterable, Equatable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "Follow System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    func resolvedTheme(for colorScheme: ColorScheme) -> TerminalColors {
        switch self {
        case .system:
            colorScheme == .dark ? TerminalTheme.dark : TerminalTheme.light
        case .light:
            TerminalTheme.light
        case .dark:
            TerminalTheme.dark
        }
    }
}