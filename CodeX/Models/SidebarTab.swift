import Foundation

enum SidebarTab: String, CaseIterable {
    case explorer
    case git
    case bookmark
    case search
    case linting
    case testing
    case spray
    case tag
    case list
    
    var iconName: String {
        switch self {
        case .explorer: return "folder"
        case .git: return "square.grid.3x3.topleft.filled"
        case .bookmark: return "bookmark"
        case .search: return "magnifyingglass"
        case .linting: return "exclamationmark.triangle"
        case .testing: return "checkmark.diamond"
        case .spray: return "bubbles.and.sparkles"
        case .tag: return "tag"
        case .list: return "list.bullet.rectangle.portrait"
        }
    }
}
