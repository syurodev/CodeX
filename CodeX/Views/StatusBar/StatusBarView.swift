import SwiftUI
// import CodeEditLanguages

struct StatusBarView: View {
    @Environment(\.colorScheme) private var colorScheme

    static let height: CGFloat = 28

    let document: EditorDocument?
    let cursorPosition: (line: Int, column: Int)

    var body: some View {
        HStack(spacing: 12) {
            if let doc = document {
                Spacer(minLength: 0)

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
                Spacer()
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
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
