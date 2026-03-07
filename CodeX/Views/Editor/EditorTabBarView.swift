import SwiftUI

struct EditorTabBarView: View {
    @Bindable var viewModel: EditorViewModel
    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 0) {
            // Hàng 1: Tabs
            if !viewModel.openDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 6.0) {
                        HStack(spacing: 2) {
                            ForEach(viewModel.openDocuments) { document in
                                ToolbarTabItemView(
                                    document: document,
                                    isSelected: document.id == viewModel.currentDocumentID,
                                    onSelect: { viewModel.selectDocument(id: document.id) },
                                    onClose: { viewModel.closeDocument(id: document.id) }
                                )
                                .glassEffectID(document.id, in: tabNamespace)
                                .glassEffectTransition(.matchedGeometry)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }

                Divider()
            }

            // Hàng 2: Path bar
            if let currentDoc = viewModel.currentDocument {
                ToolbarPathBarView(document: currentDoc)
            } else {
                Color.clear
                    .frame(height: 28)
            }

            Divider()
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Tab Item

private struct ToolbarTabItemView: View {
    let document: EditorDocument
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(AppViewModel.self) private var appViewModel
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: FileIcon.iconName(for: document.fileName))
                    .foregroundColor(FileIcon.iconColor(for: document.fileName))
                    .font(.system(size: 11))

                Text(document.fileName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                if isSelected || isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 12, height: 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1.0 : 0.6)
                } else {
                    Spacer().frame(width: 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .opacity(isSelected ? 1.0 : (isHovering ? 0.85 : 0.5))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Path Bar

private struct ToolbarPathBarView: View {
    let document: EditorDocument
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Breadcrumbs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                        HStack(spacing: 0) {
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 4)
                            }

                            let isLast = index == pathComponents.count - 1
                            Image(systemName: iconForComponent(component, isLast: isLast))
                                .foregroundColor(colorForComponent(component, isLast: isLast))
                                .font(.system(size: 11))
                                .padding(.trailing, 4)

                            Text(component)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.primary.opacity(0.85))
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 16)

            // Action buttons với Liquid Glass
            GlassEffectContainer(spacing: 12.0) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())

                        Button(action: {}) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.yellow).interactive())

                        Button(action: {}) {
                            Image(systemName: "chevron.right")
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                    }

                    Button(action: {}) {
                        Image(systemName: "arrow.left.arrow.right")
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())

                    Button(action: {}) {
                        Image(systemName: "sidebar.right")
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())

                    Button(action: {}) {
                        Image(systemName: "plus")
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                }
                .foregroundColor(.secondary)
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.trailing, 12)
        }
        .frame(height: 28)
    }

    private var pathComponents: [String] {
        guard let root = appViewModel.project?.rootURL else {
            return [document.url.lastPathComponent]
        }

        let rootPath = root.standardizedFileURL.path
        let filePath = document.url.standardizedFileURL.path

        if filePath.hasPrefix(rootPath) {
            let relativePath = String(filePath.dropFirst(rootPath.count))
            var components = relativePath.split(separator: "/").map(String.init)

            if components.isEmpty { return [root.lastPathComponent] }

            if components.count > 5 {
                let lastFew = Array(components.suffix(3))
                components = ["..."] + lastFew
            }

            return [root.lastPathComponent] + components
        } else {
            return [document.url.deletingLastPathComponent().lastPathComponent, document.url.lastPathComponent]
        }
    }

    private func iconForComponent(_ name: String, isLast: Bool) -> String {
        if name == "..." { return "ellipsis.circle" }
        if !isLast { return "folder.fill" }
        return FileIcon.iconName(for: name)
    }

    private func colorForComponent(_ name: String, isLast: Bool) -> Color {
        if name == "..." { return .secondary }
        if !isLast { return .blue }
        return FileIcon.iconColor(for: name)
    }
}
