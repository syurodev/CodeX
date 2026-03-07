import AppKit

/// Configurable editor settings with Xcode-like defaults.
/// These values will be editable via a settings screen in the future.
struct EditorSettings {
    /// Font name for the code editor (e.g. "SFMono-Regular")
    var font_name: String = "SFMono-Regular"

    /// Font size in points
    var font_size: CGFloat = 13

    /// Line height multiplier (Xcode default ≈ 1.45)
    var line_height_multiple: Double = 1.45

    /// Letter spacing as a percent (1.0 = normal)
    var letter_spacing: Double = 1.0

    /// Visual tab width in number of spaces
    var tab_width: Int = 4

    /// Whether lines wrap to the width of the editor
    var wrap_lines: Bool = false

    /// Whether to use the system cursor on macOS 14+
    var use_system_cursor: Bool = true

    /// Whether to show line numbers in the gutter
    var show_line_numbers: Bool = true

    // Whether to show the minimap
    var show_minimap: Bool = false

    /// Whether to use the theme's background color
    var use_theme_background: Bool = true

    // MARK: - Derived Properties

    /// Resolved NSFont from settings (cached để tránh tạo NSFont lặp lại mỗi render)
    var resolved_font: NSFont {
        NSFont(name: font_name, size: font_size)
            ?? NSFont.monospacedSystemFont(ofSize: font_size, weight: .regular)
    }

    /// Font for line numbers in the gutter
    var line_number_font: NSFont {
        NSFont(name: font_name, size: font_size - 2)
            ?? NSFont.monospacedSystemFont(ofSize: font_size - 2, weight: .regular)
    }
}
