import SwiftUI

/// Center toolbar component (`.principal` placement).
///
/// Single-row layout:  [▶/■]  ·  [status]
///
/// Falls back to the standard file-name/path display when no
/// runnable scripts are detected in the current project.
struct ToolbarRunView: View {
    var appViewModel: AppViewModel

    private var vm: ProjectRunViewModel { appViewModel.projectRunViewModel }
    private var store: WorkspaceDiagnosticsStore { appViewModel.editorViewModel.workspaceStore }

    @State private var isScriptPopoverPresented = false

    var body: some View {
        if vm.hasScripts {
            scriptView
        } else {
            fallbackView
        }
    }

    // MARK: - Single-row script view

    private var scriptView: some View {
        HStack(spacing: 0) {
            // ── Left cluster: action button with popover ───────────────────
            actionButton
                .popover(isPresented: $isScriptPopoverPresented, arrowEdge: .bottom) {
                    RunScriptPopoverView(appViewModel: appViewModel, isPresented: $isScriptPopoverPresented)
                }

            Spacer(minLength: 16)

            // ── Right cluster: state indicator ────────────────────────────
            stateTrailing
        }
        // Horizontal inset so content never touches the pill edges
        .padding(.horizontal, 10)
        // idealWidth pushes the toolbar pill wider;
        // maxWidth lets it grow if the window is large
        .frame(minWidth: 160, idealWidth: 300, maxWidth: 500)
    }

    // MARK: Action button

    private var actionButton: some View {
        Button(action: handleAction) {
            Image(systemName: actionIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(actionTint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(actionHelp)
    }

    private var actionIcon: String { "play.fill" }

    private var actionTint: Color {
        if vm.hasAnyRunning { return .green }
        if store.totalErrors > 0 { return .red }
        if store.totalWarnings > 0 { return .yellow }
        return store.isIndexing ? .accentColor : .green
    }

    private var actionHelp: String { "Manage scripts" }

    private func handleAction() {
        isScriptPopoverPresented = true
    }

    // MARK: Diagnostics badge

    @ViewBuilder
    private var diagnosticsBadge: some View {
        if store.isIndexing {
            ProgressView()
                .controlSize(.mini)
                .help("Indexing workspace…")
        } else if store.totalErrors > 0 || store.totalWarnings > 0 {
            HStack(spacing: 4) {
                if store.totalErrors > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        Text("\(store.totalErrors)")
                    }
                }
                if store.totalWarnings > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text("\(store.totalWarnings)")
                    }
                }
            }
            .font(.system(size: 11, weight: .medium))
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 11))
        }
    }

    // MARK: Trailing state indicator

    @ViewBuilder
    private var stateTrailing: some View {
        HStack(spacing: 6) {
            diagnosticsBadge
            if vm.hasAnyRunning {
                // Count of running scripts
                let runningCount = vm.scriptStates.values.filter { $0.isRunning }.count
                if runningCount > 1 {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("\(runningCount) running")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Show port if available
                    let portText = vm.scriptStates.values.compactMap(\.port).first.map { ":\($0)" }
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        if let port = portText {
                            Text(port)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                let icon = vm.detectedKind.iconName
                if !icon.isEmpty {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Fallback (no scripts detected)
    //
    // Standard macOS title + subtitle layout (unchanged from original).

    private var fallbackView: some View {
        VStack(spacing: 1) {
            Text(fallbackTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            if !fallbackSubtitle.isEmpty {
                Text(fallbackSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(minWidth: 220, idealWidth: 320, maxWidth: 420)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private var fallbackTitle: String {
        appViewModel.editorViewModel.currentDocument?.fileName ?? appViewModel.projectName
    }

    private var fallbackSubtitle: String {
        if let document = appViewModel.editorViewModel.currentDocument {
            return relativeDirectoryPath(for: document.url)
        }
        if appViewModel.gitViewModel.is_git_repo {
            return appViewModel.gitViewModel.current_branch
        }
        return appViewModel.project == nil ? "Open a project to start editing" : "No file selected"
    }

    private func relativeDirectoryPath(for fileURL: URL) -> String {
        let directoryURL = fileURL.deletingLastPathComponent()
        if let rootURL = appViewModel.project?.rootURL {
            let rootPath = rootURL.path
            let directoryPath = directoryURL.path
            if directoryPath.hasPrefix(rootPath) {
                let suffix = String(directoryPath.dropFirst(rootPath.count))
                let trimmed = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return trimmed.isEmpty ? appViewModel.projectName : trimmed
            }
        }
        return directoryURL.lastPathComponent
    }
}
