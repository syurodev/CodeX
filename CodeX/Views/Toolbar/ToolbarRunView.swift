import SwiftUI

/// Center toolbar component (`.principal` placement).
///
/// Single-row layout:  [▶/■]  [script ▾]  ·  [status]
///
/// Falls back to the standard file-name/path display when no
/// runnable scripts are detected in the current project.
struct ToolbarRunView: View {
    var appViewModel: AppViewModel

    private var vm: ProjectRunViewModel { appViewModel.projectRunViewModel }

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
            // ── Left cluster: action + script ─────────────────────────────
            HStack(spacing: 6) {
                actionButton
                scriptControl
            }

            Spacer(minLength: 16)

            // ── Right cluster: state indicator ────────────────────────────
            stateTrailing
        }
        // Horizontal inset so content never touches the pill edges
        .padding(.horizontal, 10)
        // idealWidth pushes the toolbar pill wider;
        // maxWidth lets it grow if the window is large
        .frame(minWidth: 280, idealWidth: 460, maxWidth: 600)
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
        .disabled(vm.selectedScript == nil)
    }

    private var actionIcon: String {
        switch vm.runState {
        case .idle, .error:   return "play.fill"
        case .starting, .running: return "stop.fill"
        }
    }

    private var actionTint: Color {
        switch vm.runState {
        case .idle:     return .accentColor
        case .error:    return .red
        case .starting: return .orange
        case .running:  return .red
        }
    }

    private var actionHelp: String {
        let name = vm.selectedScript?.name ?? ""
        switch vm.runState {
        case .idle:    return "Run \"\(name)\""
        case .error:   return "Retry \"\(name)\""
        case .starting, .running: return "Stop \"\(name)\""
        }
    }

    private func handleAction() {
        switch vm.runState {
        case .idle, .error:       appViewModel.startRun()
        case .starting, .running: appViewModel.stopRun()
        }
    }

    // MARK: Script control (Menu when idle, plain label when running)

    @ViewBuilder
    private var scriptControl: some View {
        if vm.runState.isRunning {
            Text(vm.selectedScript?.name ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        } else {
            Menu {
                ForEach(vm.scripts) { script in
                    Button(script.name) { vm.selectedScript = script }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.selectedScript?.name ?? "Select…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: Trailing state indicator

    @ViewBuilder
    private var stateTrailing: some View {
        switch vm.runState {

        case .idle:
            let icon = vm.detectedKind.iconName
            if !icon.isEmpty {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.tertiary)
            }

        case .starting:
            HStack(spacing: 5) {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 13, height: 13)
                Text("Starting…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

        case .running:
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)

        case .error(let msg):
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .lineLimit(1)
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
