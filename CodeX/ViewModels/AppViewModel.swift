import SwiftUI
import CodeEditSourceEditor

@Observable
class AppViewModel {
    var project: Project?
    var fileNavigatorViewModel = FileNavigatorViewModel()
    var editorViewModel = EditorViewModel()
    var gitViewModel = GitViewModel()
    var agentPanelViewModel = AgentPanelViewModel()
    var selectedSidebarTab: SidebarTab = .explorer
    var splitViewVisibility: NavigationSplitViewVisibility = .all
    var isAgentInspectorPresented = false

    private let fileSystemService = FileSystemService()
    private let gitService = GitService()

    var projectName: String {
        project?.name ?? "CodeX"
    }

    func openProject(at url: URL) {
        let name = url.lastPathComponent
        project = Project(name: name, rootURL: url)
        agentPanelViewModel.updateWorkspaceRoot(url)
        editorViewModel.closeAllDocuments()
        fileNavigatorViewModel.loadDirectory(at: url, using: fileSystemService)
        gitViewModel.load(url: url, using: gitService)
        refreshGitFileStatuses()
    }

    func openFile(_ node: FileNode) {
        guard !node.isDirectory else { return }
        fileNavigatorViewModel.selectedNode = node
        editorViewModel.openDocument(from: node.url, projectRoot: project?.rootURL, using: fileSystemService)
    }

    func openFile(at url: URL, line: Int, column: Int) {
        print("📁 AppViewModel.openFile(at: \(url.lastPathComponent), line: \(line), column: \(column))")
        editorViewModel.openDocument(from: url, projectRoot: project?.rootURL, using: fileSystemService)
        // Cập nhật vị trí con trỏ để SourceEditor tự động nhảy tới
        let position = CursorPosition(line: line, column: column)
        print("📍 Setting cursor position to: \(line):\(column)")
        editorViewModel.editorState.cursorPositions = [position]
    }

    func refreshFileTree() {
        guard let rootURL = project?.rootURL else { return }
        fileNavigatorViewModel.refresh(at: rootURL, using: fileSystemService)
        refreshGitFileStatuses()
    }

    func switch_branch(_ branch: String) {
        guard let rootURL = project?.rootURL else { return }
        gitViewModel.checkout(branch: branch, url: rootURL, using: gitService) { [weak self] in
            guard let self else { return }
            self.editorViewModel.closeAllDocuments()
            self.refreshFileTree()
        }
    }
    
    func rename_branch(oldName: String, newName: String) {
        guard let rootURL = project?.rootURL else { return }
        gitViewModel.rename_branch(oldName: oldName, newName: newName, url: rootURL, using: gitService) { [weak self] in
            self?.refreshFileTree()
        }
    }
    
    func create_branch(from baseBranch: String, newName: String) {
        guard let rootURL = project?.rootURL else { return }
        gitViewModel.create_branch(from: baseBranch, newName: newName, url: rootURL, using: gitService) { [weak self] in
            self?.refreshFileTree()
        }
    }

    private func refreshGitFileStatuses() {
        guard let rootURL = project?.rootURL else {
            fileNavigatorViewModel.updateGitStatuses([:])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let statuses = self.gitService.file_statuses(at: rootURL)
            DispatchQueue.main.async { [weak self] in
                self?.fileNavigatorViewModel.updateGitStatuses(statuses)
            }
        }
    }

    func openFolderPanel() {
        print("➡️ AppViewModel.openFolderPanel()") // Added log
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder to open"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                print("⚠️ Folder panel cancelled or no URL selected.") // Added log
                return
            }
            DispatchQueue.main.async {
                print("✅ Folder selected: \(url.lastPathComponent). Opening project...") // Added log
                self?.openProject(at: url)
            }
        }
    }

    func openAgentPanel() {
        if !isAgentInspectorPresented {
            selectedSidebarTab = .spray
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isAgentInspectorPresented.toggle()
        }
    }

    func shutdownAgentRuntimes() {
        agentPanelViewModel.shutdownAllRuntimes()
    }

    deinit {
        shutdownAgentRuntimes()
    }
}
