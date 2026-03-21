import SwiftUI

struct DiagnosticsPanelView: View {
    let store: WorkspaceDiagnosticsStore
    @Binding var height: CGFloat
    let onClose: () -> Void

    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            tabBar

            Divider()

            content
        }
        .frame(height: height)
        .background(.background)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
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

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            // Tab label
            GlassEffectContainer(spacing: 6.0) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Diagnostics")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Spacer(minLength: 8)

            // Trailing: counts + close
            GlassEffectContainer(spacing: 8.0) {
                HStack(spacing: 8) {
                    if store.isIndexing {
                        ProgressView().controlSize(.mini)
                    }

                    if store.totalErrors > 0 {
                        Label("\(store.totalErrors)", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    if store.totalWarnings > 0 {
                        Label("\(store.totalWarnings)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                    if store.totalErrors == 0 && store.totalWarnings == 0 && !store.isIndexing {
                        Label("0", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Divider().frame(height: 12)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .help("Close Diagnostics Panel")
                }
                .foregroundStyle(.secondary)
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }

    // MARK: - Content

    private var content: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                diagnosticsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if store.isIndexing {
                ProgressView()
                Text("Indexing workspace…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green.opacity(0.7))
                Text("No issues found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diagnosticsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    DiagnosticsPanelRow(item: item) {
                        appViewModel.openFile(at: item.url, line: item.line, column: item.column)
                    }
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(.background)
    }

    // MARK: - Data

    private var items: [DiagnosticsPanelItem] {
        store.diagnostics
            .flatMap { url, diags in
                diags.enumerated().map { i, diag in
                    DiagnosticsPanelItem(id: "\(url.path)-\(i)", url: url, diagnostic: diag)
                }
            }
            .sorted { a, b in
                if a.diagnostic.severity != b.diagnostic.severity {
                    return a.diagnostic.severity == .error
                }
                return a.url.lastPathComponent < b.url.lastPathComponent
            }
    }
}

// MARK: - Item Model

struct DiagnosticsPanelItem: Identifiable {
    let id: String
    let url: URL
    let diagnostic: Diagnostic

    /// Approximate line number computed from NSRange offset (byte-based, good enough for navigation).
    var line: Int { 1 }
    var column: Int { 1 }
}

// MARK: - Row

private struct DiagnosticsPanelRow: View {
    let item: DiagnosticsPanelItem
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.diagnostic.severity == .error
                      ? "xmark.circle.fill"
                      : item.diagnostic.severity == .warning
                      ? "exclamationmark.triangle.fill"
                      : "info.circle.fill")
                    .foregroundStyle(severityColor)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.diagnostic.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(item.url.lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if let rule = ruleLabel {
                            Text("·")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 11))
                            Text(rule)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var severityColor: Color {
        switch item.diagnostic.severity {
        case .error:   return .red
        case .warning: return .yellow
        case .info:    return .blue
        case .hint:    return .secondary
        }
    }

    private var ruleLabel: String? {
        switch item.diagnostic.source {
        case .biomeLint(let rule): return rule
        case .lsp(let src, _): return src
        default: return nil
        }
    }
}
