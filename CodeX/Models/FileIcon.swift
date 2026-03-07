import SwiftUI

struct FileIcon {
    static func iconName(for fileName: String) -> String {
        let lowerName = fileName.lowercased()
        if lowerName.contains("dockerfile") || lowerName.contains("docker-compose") {
            return "shippingbox"
        }
        
        let url = URL(fileURLWithPath: fileName)
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "yml", "yaml": return "list.bullet.clipboard"
        case "swift": return "swift"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.richtext"
        case "xcodeproj", "xcworkspace": return "hammer.fill"
        case "js", "ts": return "curlybraces"
        case "jsx", "tsx", "html", "xml": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "number"
        case "sh", "bash": return "terminal"
        default: return "doc"
        }
    }
    
    static func iconColor(for fileName: String) -> Color {
        let lowerName = fileName.lowercased()
        if lowerName.contains("dockerfile") || lowerName.contains("docker-compose") {
            return .blue
        }
        
        let url = URL(fileURLWithPath: fileName)
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "yml", "yaml": return .purple
        case "swift": return .orange
        case "json", "js", "jsx": return .yellow
        case "ts", "tsx", "css", "scss": return .blue
        case "html", "xml": return .orange
        case "sh", "bash": return .green
        case "md", "markdown": return .purple
        default: return .secondary
        }
    }
}
