import SwiftUI

struct MainWindowToolbarContent: ToolbarContent {
    @Bindable var appViewModel: AppViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            ToolbarGitBranchButton(appViewModel: appViewModel)
        }

        ToolbarItem(placement: .principal) {
            ToolbarRunView(appViewModel: appViewModel)
        }

        ToolbarItem(placement: .primaryAction) {
            ToolbarDiagnosticsButton(appViewModel: appViewModel)
        }

        if !appViewModel.isAgentInspectorPresented {
            ToolbarItem(placement: .primaryAction) {
                ToolbarAgentPanelButton(appViewModel: appViewModel)
            }
        }
    }
}

struct AgentInspectorToolbarContent: ToolbarContent {
    @Bindable var appViewModel: AppViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ToolbarAgentPanelButton(appViewModel: appViewModel)
        }
    }
}

private struct ToolbarTitlebarContextView: View {
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            if !subtitle.isEmpty {
                Text(subtitle)
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

    private var title: String {
        appViewModel.editorViewModel.currentDocument?.fileName ?? appViewModel.projectName
    }

    private var subtitle: String {
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

struct ToolbarGitBranchButton: View {
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        Button(action: {
            appViewModel.gitViewModel.is_popover_presented.toggle()
        }) {
            Label(branchLabel, systemImage: "arrow.triangle.branch")
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(!appViewModel.gitViewModel.is_git_repo)
        .help(appViewModel.gitViewModel.is_git_repo ? "Switch Git branch" : "Open a Git repository to enable branch actions")
        .popover(isPresented: $appViewModel.gitViewModel.is_popover_presented, arrowEdge: .bottom) {
            BranchPopoverView(appViewModel: appViewModel)
        }
        .alert("Rename Branch", isPresented: $appViewModel.gitViewModel.isShowingRenameAlert) {
            TextField("New branch name", text: $appViewModel.gitViewModel.branchNameInput)
            Button("Rename") {
                let oldName = appViewModel.gitViewModel.targetBranchForAction
                let newName = appViewModel.gitViewModel.branchNameInput.trimmingCharacters(in: .whitespaces)
                if !newName.isEmpty && newName != oldName {
                    appViewModel.rename_branch(oldName: oldName, newName: newName)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new name for branch '\(appViewModel.gitViewModel.targetBranchForAction)'.")
        }
        .sheet(isPresented: $appViewModel.gitViewModel.isShowingNewBranchAlert) {
            NewBranchSheetView(appViewModel: appViewModel)
        }
    }

    private var branchLabel: String {
        appViewModel.gitViewModel.is_git_repo ? appViewModel.gitViewModel.current_branch : "Git"
    }
}

private struct ToolbarAgentPanelButton: View {
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        Button(action: appViewModel.openAgentPanel) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 18, height: 18)
                .padding(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(appViewModel.isAgentInspectorPresented ? .accentColor : .primary)
        .help(appViewModel.isAgentInspectorPresented ? "Hide Agent panel" : "Show Agent panel")
        .accessibilityLabel("Toggle Agent panel")
    }
}

private struct ToolbarDiagnosticsButton: View {
    let appViewModel: AppViewModel

    private var store: WorkspaceDiagnosticsStore { appViewModel.editorViewModel.workspaceStore }

    var body: some View {
        HStack(spacing: 6) {
            if store.isIndexing {
                ProgressView()
                    .controlSize(.mini)
                    .help("Indexing workspace…")
            }

            if store.totalErrors > 0 || store.totalWarnings > 0 {
                if store.totalErrors > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("\(store.totalErrors)")
                    }
                }
                if store.totalWarnings > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("\(store.totalWarnings)")
                    }
                }
            } else if !store.isIndexing {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("0")
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.primary)
        .help("Workspace diagnostics")
        .padding(.horizontal, 4)
    }
}