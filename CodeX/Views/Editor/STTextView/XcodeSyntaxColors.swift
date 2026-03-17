import AppKit

/// Xcode-style syntax colors for light and dark mode
struct XcodeSyntaxColors {
    let keyword: NSColor
    let string: NSColor
    let number: NSColor
    let comment: NSColor
    let function: NSColor
    let type: NSColor
    let property: NSColor
    let plain: NSColor
    
    /// Xcode dark theme colors
    static let dark = XcodeSyntaxColors(
        keyword: NSColor(red: 0.984, green: 0.408, blue: 0.659, alpha: 1.0),  // #FB68A8 - pink
        string: NSColor(red: 0.988, green: 0.412, blue: 0.380, alpha: 1.0),   // #FC6961 - red
        number: NSColor(red: 0.831, green: 0.686, blue: 0.522, alpha: 1.0),   // #D4AF85 - orange
        comment: NSColor(red: 0.420, green: 0.475, blue: 0.537, alpha: 1.0),  // #6B7989 - gray
        function: NSColor(red: 0.639, green: 0.745, blue: 0.549, alpha: 1.0), // #A3BE8C - green
        type: NSColor(red: 0.522, green: 0.741, blue: 0.831, alpha: 1.0),     // #85BDD4 - cyan
        property: NSColor(red: 0.522, green: 0.741, blue: 0.831, alpha: 1.0), // #85BDD4 - cyan
        plain: NSColor.white
    )
    
    /// Xcode light theme colors
    static let light = XcodeSyntaxColors(
        keyword: NSColor(red: 0.667, green: 0.031, blue: 0.569, alpha: 1.0),  // #AA0891 - magenta
        string: NSColor(red: 0.769, green: 0.102, blue: 0.086, alpha: 1.0),   // #C41A16 - red
        number: NSColor(red: 0.110, green: 0.000, blue: 0.812, alpha: 1.0),   // #1C00CF - blue
        comment: NSColor(red: 0.420, green: 0.475, blue: 0.537, alpha: 1.0),  // #6B7989 - gray
        function: NSColor(red: 0.243, green: 0.400, blue: 0.569, alpha: 1.0), // #3E6691 - blue
        type: NSColor(red: 0.243, green: 0.400, blue: 0.569, alpha: 1.0),     // #3E6691 - blue
        property: NSColor(red: 0.243, green: 0.400, blue: 0.569, alpha: 1.0), // #3E6691 - blue
        plain: NSColor.black
    )
}

