import AppKit
import SwiftTerm

/// Maps CodeX editor themes to SwiftTerm color palette.
enum TerminalTheme {

    // MARK: - Dark (Xcode Default Dark)

    static let dark = TerminalColors(
        foreground: NSColor(srgbRed: 0.859, green: 0.871, blue: 0.886, alpha: 1.0),
        background: NSColor(srgbRed: 0.118, green: 0.125, blue: 0.161, alpha: 1.0),
        caret:      NSColor(srgbRed: 0.93,  green: 0.94,  blue: 0.95,  alpha: 1.0),
        ansi: [
            // Normal (0–7)
            ansiColor(0x1e, 0x21, 0x27), // 0  black
            ansiColor(0xe0, 0x6c, 0x75), // 1  red
            ansiColor(0x98, 0xc3, 0x79), // 2  green
            ansiColor(0xe5, 0xc0, 0x7b), // 3  yellow
            ansiColor(0x61, 0xaf, 0xef), // 4  blue
            ansiColor(0xc6, 0x78, 0xdd), // 5  magenta
            ansiColor(0x56, 0xb6, 0xc2), // 6  cyan
            ansiColor(0xab, 0xb2, 0xbf), // 7  white
            // Bright (8–15)
            ansiColor(0x5c, 0x63, 0x70), // 8  bright black
            ansiColor(0xe0, 0x6c, 0x75), // 9  bright red
            ansiColor(0x98, 0xc3, 0x79), // 10 bright green
            ansiColor(0xe5, 0xc0, 0x7b), // 11 bright yellow
            ansiColor(0x61, 0xaf, 0xef), // 12 bright blue
            ansiColor(0xc6, 0x78, 0xdd), // 13 bright magenta
            ansiColor(0x56, 0xb6, 0xc2), // 14 bright cyan
            ansiColor(0xff, 0xff, 0xff), // 15 bright white
        ]
    )

    // MARK: - Light (Xcode Default Light)

    static let light = TerminalColors(
        foreground: NSColor(srgbRed: 0.0,  green: 0.0,  blue: 0.0,  alpha: 1.0),
        background: NSColor(srgbRed: 1.0,  green: 1.0,  blue: 1.0,  alpha: 1.0),
        caret:      NSColor(srgbRed: 0.1,  green: 0.1,  blue: 0.1,  alpha: 1.0),
        ansi: [
            // Normal (0–7)
            ansiColor(0x00, 0x00, 0x00), // 0  black
            ansiColor(0xcc, 0x00, 0x00), // 1  red
            ansiColor(0x4e, 0x9a, 0x06), // 2  green
            ansiColor(0xc4, 0xa0, 0x00), // 3  yellow
            ansiColor(0x34, 0x65, 0xa4), // 4  blue
            ansiColor(0x75, 0x50, 0x7b), // 5  magenta
            ansiColor(0x06, 0x98, 0x9a), // 6  cyan
            ansiColor(0xd3, 0xd7, 0xcf), // 7  white
            // Bright (8–15)
            ansiColor(0x55, 0x57, 0x53), // 8  bright black
            ansiColor(0xef, 0x29, 0x29), // 9  bright red
            ansiColor(0x8a, 0xe2, 0x34), // 10 bright green
            ansiColor(0xfc, 0xe9, 0x4f), // 11 bright yellow
            ansiColor(0x72, 0x9f, 0xcf), // 12 bright blue
            ansiColor(0xad, 0x7f, 0xa8), // 13 bright magenta
            ansiColor(0x34, 0xe2, 0xe2), // 14 bright cyan
            ansiColor(0xee, 0xee, 0xec), // 15 bright white
        ]
    )

    // MARK: - Helpers

    private static func ansiColor(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Color {
        Color(red: UInt16(r) * 257, green: UInt16(g) * 257, blue: UInt16(b) * 257)
    }
}

// MARK: - TerminalColors

struct TerminalColors {
    let foreground: NSColor
    let background: NSColor
    let caret: NSColor
    let ansi: [Color]

    func ansiNSColor(at index: Int) -> NSColor? {
        guard ansi.indices.contains(index) else { return nil }
        let color = ansi[index]
        return NSColor(
            srgbRed: CGFloat(color.red) / 65535.0,
            green: CGFloat(color.green) / 65535.0,
            blue: CGFloat(color.blue) / 65535.0,
            alpha: 1.0
        )
    }

    func apply(to view: LocalProcessTerminalView) {
        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        view.caretColor = caret
        if ansi.count == 16 {
            view.installColors(ansi)
        }
    }
}
