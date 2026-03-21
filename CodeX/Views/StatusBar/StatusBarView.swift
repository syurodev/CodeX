import SwiftUI
// import CodeEditLanguages

struct StatusBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppViewModel.self) private var appViewModel

    static let height: CGFloat = 28

    let document: EditorDocument?
    let cursorPosition: (line: Int, column: Int)

    var body: some View {
        HStack(spacing: 0) {
            // Left: action buttons
            HStack(spacing: 2) {
                StatusBarActionButton(
                    icon: "terminal",
                    isActive: appViewModel.isTerminalPanelPresented,
                    help: appViewModel.isTerminalPanelPresented ? "Hide Terminal" : "Show Terminal",
                    action: { appViewModel.toggleTerminalPanel() }
                )
                StatusBarActionButton(
                    icon: "exclamationmark.triangle",
                    isActive: appViewModel.activeBottomPanel == .diagnostics,
                    help: appViewModel.activeBottomPanel == .diagnostics ? "Hide Diagnostics" : "Show Diagnostics",
                    action: { appViewModel.toggleDiagnosticsPanel() }
                )
            }
            .padding(.leading, 6)

            Spacer(minLength: 0)

            // Right: document info
            HStack(spacing: 12) {
                if let doc = document {
                    Text(languageDisplayName(for: doc.language).uppercased())
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

                    if doc.lspStatus != .off {
                        Divider()
                            .frame(height: 12)

                        LSPStatusIndicator(status: doc.lspStatus, document: doc)
                    }
                } else {
                    Text("No file open")
                        .foregroundStyle(.secondary)
                }
            }

            // Far right: panel area toggle
            StatusBarActionButton(
                icon: "square.bottomhalf.filled",
                isActive: appViewModel.activeBottomPanel != nil,
                help: appViewModel.activeBottomPanel != nil ? "Hide Panel" : "Show Panel",
                action: {
                    if appViewModel.activeBottomPanel != nil {
                        withAnimation(.easeInOut(duration: 0.2)) { appViewModel.activeBottomPanel = nil }
                    } else {
                        appViewModel.toggleTerminalPanel()
                    }
                }
            )
            .padding(.horizontal, 6)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(colorScheme == .dark ? 0.08 : 0.14))
                .frame(height: 1)
        }
    }

    private func languageDisplayName(for language: CodeLanguage) -> String {
        switch language {
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        default: return "Text"
        }
    }
}

// MARK: - Action Button

private struct StatusBarActionButton: View {
    let icon: String
    let isActive: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - LSP Status Indicator (unchanged)

private struct LSPStatusIndicator: View {
    let status: EditorDocument.LSPStatus
    let document: EditorDocument
    @Environment(AppViewModel.self) private var appViewModel
    @State private var isShowingPopover = false

    var body: some View {
        Button(action: {
            isShowingPopover.toggle()
        }) {
            if status == .starting {
                ProgressView()
                    .controlSize(.mini)
                    .help("Deno LSP: Starting")
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .help(status == .ready ? "Deno LSP: Ready" : "Deno LSP: Error")
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
            LSPLogsPopover(projectRoot: appViewModel.project?.rootURL)
        }
    }

    private var iconName: String {
        switch status {
        case .ready: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        default: return ""
        }
    }

    private var iconColor: Color {
        switch status {
        case .ready: return .green
        case .error: return .red
        default: return .clear
        }
    }
}

private struct LSPLogsPopover: View {
    let projectRoot: URL?

    private var logs: [String] {
        guard let root = projectRoot else { return [] }
        let key = "deno-\(root.path)"
        return LSPManager.shared.serverLogs[key] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Deno LSP Logs")
                .font(.headline)
                .padding()

            Divider()

            if logs.isEmpty {
                Text("No logs available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logs.indices, id: \.self) { index in
                            Text(logs[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 350)
    }
}
