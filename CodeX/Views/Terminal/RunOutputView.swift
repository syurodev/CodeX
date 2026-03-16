import SwiftUI

/// Read-only log view that streams `ProjectRunViewModel.outputLines`
/// and is shown as a pinned tab in the bottom terminal panel.
struct RunOutputView: View {
    var runViewModel: ProjectRunViewModel

    var body: some View {
        VStack(spacing: 0) {
            logView
            statusBar
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Log

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(runViewModel.outputLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 1)
                    }
                    // Sentinel anchor for auto-scroll
                    Color.clear.frame(height: 1).id("run-log-bottom")
                }
                .padding(.vertical, 6)
            }
            // Auto-scroll to bottom whenever new lines arrive
            .onChange(of: runViewModel.outputLines.count) {
                proxy.scrollTo("run-log-bottom", anchor: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            stateIcon
            Text(stateLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if !runViewModel.runState.isRunning && !runViewModel.outputLines.isEmpty {
                Button("Clear") { runViewModel.clearOutput() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch runViewModel.runState {
        case .idle:
            EmptyView()
        case .starting:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        case .running:
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
        }
    }

    private var stateLabel: String {
        switch runViewModel.runState {
        case .idle:
            return runViewModel.outputLines.isEmpty ? "" : "Process ended"
        case .starting:
            return "Starting \(runViewModel.selectedScript?.name ?? "")…"
        case .running(let pid, let port):
            let portStr = port.map { " · Port \($0)" } ?? ""
            return "Running · PID \(pid)\(portStr)"
        case .error(let msg):
            return msg
        }
    }
}
