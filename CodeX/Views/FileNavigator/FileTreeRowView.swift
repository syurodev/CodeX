import SwiftUI

struct FileTreeRowView: View {
    let node: FileNode
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(node.name)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.vertical, 1)
    }

    private var icon: String {
        if node.isDirectory {
            return "folder.fill"
        }
        return FileIcon.iconName(for: node.name)
    }

    private var iconColor: Color {
        if node.isDirectory {
            return .blue
        }
        return FileIcon.iconColor(for: node.name)
    }
}
