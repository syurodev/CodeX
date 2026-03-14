import AppKit

/// A marker displayed in the gutter's marker lane (left of line numbers).
public enum GutterMarkerKind: Equatable {
    case breakpoint
    case error
    case warning
    case info

    var color: NSColor {
        switch self {
        case .breakpoint: return NSColor(srgbRed: 0.373, green: 0.620, blue: 1.000, alpha: 1)
        case .error:      return NSColor(srgbRed: 1.000, green: 0.267, blue: 0.267, alpha: 1)
        case .warning:    return NSColor(srgbRed: 1.000, green: 0.760, blue: 0.060, alpha: 1)
        case .info:       return NSColor(srgbRed: 0.267, green: 0.800, blue: 0.600, alpha: 1)
        }
    }
}
