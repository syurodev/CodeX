import SwiftUI
import CodeEditLanguages

struct StatusBarView: View {
    @Environment(\.colorScheme) private var colorScheme

    static let height: CGFloat = 28

    let document: EditorDocument?
    let cursorPosition: (line: Int, column: Int)

    var body: some View {
        HStack(spacing: 12) {
            if let doc = document {
                StatusBarPathBarView(document: doc)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 12)

                Text(doc.language.tsName.uppercased())
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 12)

                Text("Ln \(cursorPosition.line), Col \(cursorPosition.column)")
                    .foregroundStyle(.secondary)

                if doc.isModified {
                    Divider()
                        .frame(height: 12)

                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                    Text("Modified")
                        .foregroundStyle(.orange)
                }
            } else {
                Text("No file open")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background {
            StatusBarBackgroundView(isEnabled: document != nil)
        }
        .modifier(StatusBarLiquidGlassModifier(isEnabled: document != nil))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(colorScheme == .dark ? 0.08 : 0.16))
                .frame(height: 1)
        }
    }
}

private struct StatusBarBackgroundView: View {
    let isEnabled: Bool

    var body: some View {
        if !isEnabled {
            Color.clear
        } else if #available(macOS 26.0, *) {
            Color.clear
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }
}

private struct StatusBarLiquidGlassModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled, #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        } else {
            content
        }
    }
}

private struct StatusBarPathBarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let document: EditorDocument

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    HStack(spacing: 0) {
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(.horizontal, 4)
                        }

                        let isLast = index == pathComponents.count - 1
                        Image(systemName: iconForComponent(component, isLast: isLast))
                            .foregroundStyle(colorForComponent(component, isLast: isLast))
                            .font(.system(size: 10))
                            .padding(.trailing, 4)

                        Text(component)
                            .foregroundStyle(isLast ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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
                components = ["..."] + Array(components.suffix(3))
            }

            return [root.lastPathComponent] + components
        }

        return [document.url.deletingLastPathComponent().lastPathComponent, document.url.lastPathComponent]
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
