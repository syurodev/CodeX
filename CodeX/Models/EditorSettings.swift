import AppKit

/// Configurable editor settings with Xcode-like defaults.
/// These values will be editable via a settings screen in the future.
struct EditorSettings: Codable, Equatable {
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

    /// Highlight the line that contains the insertion point
    var show_current_line_highlight: Bool = true

    /// Show vertical guides at each indentation level
    var show_indent_guides: Bool = true

    /// Show the marker lane in the gutter (breakpoints, errors, warnings)
    var show_gutter_markers: Bool = true

    // MARK: - Codable (forward-compatible: missing keys fall back to defaults)

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        font_name                  = try c.decodeIfPresent(String.self,  forKey: .font_name)                  ?? "SFMono-Regular"
        font_size                  = try c.decodeIfPresent(CGFloat.self, forKey: .font_size)                  ?? 13
        line_height_multiple       = try c.decodeIfPresent(Double.self,  forKey: .line_height_multiple)       ?? 1.45
        letter_spacing             = try c.decodeIfPresent(Double.self,  forKey: .letter_spacing)             ?? 1.0
        tab_width                  = try c.decodeIfPresent(Int.self,     forKey: .tab_width)                  ?? 4
        wrap_lines                 = try c.decodeIfPresent(Bool.self,    forKey: .wrap_lines)                 ?? false
        use_system_cursor          = try c.decodeIfPresent(Bool.self,    forKey: .use_system_cursor)          ?? true
        show_line_numbers          = try c.decodeIfPresent(Bool.self,    forKey: .show_line_numbers)          ?? true
        show_minimap               = try c.decodeIfPresent(Bool.self,    forKey: .show_minimap)               ?? false
        use_theme_background       = try c.decodeIfPresent(Bool.self,    forKey: .use_theme_background)       ?? true
        show_current_line_highlight = try c.decodeIfPresent(Bool.self,   forKey: .show_current_line_highlight) ?? true
        show_indent_guides         = try c.decodeIfPresent(Bool.self,    forKey: .show_indent_guides)         ?? true
        show_gutter_markers        = try c.decodeIfPresent(Bool.self,    forKey: .show_gutter_markers)        ?? true
    }

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
