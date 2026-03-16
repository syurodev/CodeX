import SwiftUI

struct TerminalPanelView: View {
    @Bindable var viewModel: TerminalPanelViewModel
    @Binding var height: CGFloat
    /// Passed down so the run output tab can render live output.
    var runViewModel: ProjectRunViewModel? = nil
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
        // All session views are kept in the ZStack at all times so their shell
        // processes are never killed when the user switches tabs.
        // Inactive sessions are hidden at the AppKit level (nsView.isHidden)
        // inside TerminalSessionView, which keeps the process running while
        // preventing the hidden view from receiving keyboard input.
        ZStack {
            ForEach(viewModel.sessions) { session in
                let active = !viewModel.isRunTabActive && viewModel.activeSessionID == session.id
                TerminalSessionView(session: session, isActive: active)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let runVM = runViewModel, viewModel.runOutputItem != nil {
                RunOutputView(runViewModel: runVM)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(viewModel.isRunTabActive ? 1 : 0)
                    .allowsHitTesting(viewModel.isRunTabActive)
            }

            if viewModel.sessions.isEmpty && !viewModel.isRunTabActive {
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
