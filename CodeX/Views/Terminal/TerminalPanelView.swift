import SwiftUI

struct TerminalPanelView: View {
    @Bindable var viewModel: TerminalPanelViewModel
    @Binding var height: CGFloat
    let onNewSession: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            Divider()

            TerminalTabBarView(
                viewModel: viewModel,
                onNewSession: onNewSession,
                onClose: onClose
            )

            Divider()

            terminalContent
        }
        .frame(height: height)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let newHeight = height - value.translation.height
                        height = max(120, min(800, newHeight))
                    }
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
            }
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        Group {
            if let activeSession = viewModel.activeSession {
                TerminalSessionView(session: activeSession)
                    .id(activeSession.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No terminal session")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("New Terminal", action: onNewSession)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
