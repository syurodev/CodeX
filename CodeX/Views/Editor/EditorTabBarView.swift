import SwiftUI

struct EditorTabBarView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(viewModel.openDocuments.enumerated()), id: \.element.id) { index, document in
                    TitlebarTabItemView(
                        document: document,
                        isSelected: document.id == viewModel.currentDocumentID,
                        showsTrailingDivider: shouldShowTrailingDivider(after: index),
                        onSelect: { viewModel.selectDocument(id: document.id) },
                        onClose: { viewModel.closeDocument(id: document.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    private func shouldShowTrailingDivider(after index: Int) -> Bool {
        guard index < viewModel.openDocuments.count - 1 else { return false }

        let currentID = viewModel.currentDocumentID
        let currentDocument = viewModel.openDocuments[index]
        let nextDocument = viewModel.openDocuments[index + 1]

        return currentDocument.id != currentID && nextDocument.id != currentID
    }
}

private struct TitlebarTabItemView: View {
    let document: EditorDocument
    let isSelected: Bool
    let showsTrailingDivider: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: FileIcon.iconName(for: document.fileName))
                .foregroundStyle(FileIcon.iconColor(for: document.fileName))
                .font(.system(size: 12, weight: .medium))

            Text(document.fileName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)

            if document.isModified {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }

            closeButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .frame(minWidth: 118, maxWidth: 240, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background {
            TitlebarTabBackground(isSelected: isSelected, isHovering: isHovering)
                .padding(.horizontal, 2)
        }
        .overlay(alignment: .bottom) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.9))
                    .frame(width: 28, height: 2)
                    .padding(.bottom, 1)
            }
        }
        .overlay(alignment: .trailing) {
            if showsTrailingDivider {
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1, height: 18)
            }
        }
        .opacity(isSelected ? 1.0 : (isHovering ? 0.94 : 0.86))
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(isSelected ? .primary.opacity(0.82) : .secondary)
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close \(document.fileName)")
        .opacity(isSelected || isHovering ? 1 : 0)
        .allowsHitTesting(isSelected || isHovering)
    }
}

private struct TitlebarTabBackground: View {
    let isSelected: Bool
    let isHovering: Bool

    var body: some View {
        if isSelected {
            Group {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.10))
            }
        } else if isHovering {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.07))
                }
        }
    }
}