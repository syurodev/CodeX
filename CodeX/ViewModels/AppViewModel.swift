import SwiftUI
import CodeXEditor
import Foundation

@MainActor
@Observable
class AppViewModel {
    let settingsStore: SettingsStore
    var project: Project?
    var fileNavigatorViewModel = FileNavigatorViewModel()
    var editorViewModel: EditorViewModel
    var gitViewModel = GitViewModel()
    var agentPanelViewModel = AgentPanelViewModel()
    var terminalPanelViewModel = TerminalPanelViewModel()
    var isTerminalPanelPresented = false
    var terminalPanelHeight: CGFloat = 260
    var selectedSidebarTab: SidebarTab = .explorer
    var splitViewVisibility: NavigationSplitViewVisibility = .all
    var isAgentInspectorPresented = false

    private let fileSystemService = FileSystemService()
    private let gitService = GitService()
    private var codeFormatService: CodeFormatService

    init() {
        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore
        self.editorViewModel = EditorViewModel(settingsStore: settingsStore)
        let prettierPath = settingsStore.settings.tools.prettier_path
        self.codeFormatService = CodeFormatService(prettierPath: prettierPath.isEmpty ? nil : prettierPath)
        syncToolPaths()
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.editorViewModel = EditorViewModel(settingsStore: settingsStore)
        let prettierPath = settingsStore.settings.tools.prettier_path
        self.codeFormatService = CodeFormatService(prettierPath: prettierPath.isEmpty ? nil : prettierPath)
        syncToolPaths()
    }

    /// Sync custom tool paths from ToolsSettings into the format services.
    /// Call this after any ToolsSettings mutation.
    func syncToolPaths() {
        let tools = settingsStore.settings.tools
        codeFormatService.prettierPath = tools.prettier_path.isEmpty ? nil : tools.prettier_path
        BiomeService.shared.customBiomePath = tools.biome_path
    }

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

    func toggleTerminalPanel() {
        if !isTerminalPanelPresented && terminalPanelViewModel.sessions.isEmpty {
            terminalPanelViewModel.newSession(workingDirectory: project?.rootURL)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isTerminalPanelPresented.toggle()
        }
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
        isAgentInspectorPresented.toggle()
    }

    func shutdownAgentRuntimes() {
        agentPanelViewModel.shutdownAllRuntimes()
    }
    
    func saveCurrentDocument() {
        guard let currentURL = editorViewModel.currentDocument?.url else { return }
        let formatOnSave = settingsStore.settings.format.format_on_save_js_ts
        let prettierEnabled = settingsStore.settings.format.enable_prettier_js_ts

        if formatOnSave && prettierEnabled && codeFormatService.isSupported(url: currentURL) {
            // Format first (prettier --write rewrites disk), then reload + save marks isModified=false
            formatCurrentFile()
        } else {
            editorViewModel.saveCurrentDocument(using: fileSystemService)
        }
    }

    func formatCurrentFile() {
        guard let currentURL = editorViewModel.currentDocument?.url else { return }
        guard settingsStore.settings.format.enable_prettier_js_ts else { return }
        guard codeFormatService.isSupported(url: currentURL) else { return }
        let cursorPositions = editorViewModel.editorState.cursorPositions
        let formatConfig = settingsStore.settings.format.default_style
        do {
            let result = try codeFormatService.formatFile(at: currentURL, workingDirectory: project?.rootURL, formatConfig: formatConfig)
            editorViewModel.openDocument(from: currentURL, projectRoot: project?.rootURL, using: fileSystemService)
            editorViewModel.editorState.cursorPositions = cursorPositions
            if !result.stderr.isEmpty {
                print("Prettier stderr: \(result.stderr)")
            }
        } catch {
            print("Format error: \(error)")
        }
    }

    func formatProject() {
        guard let root = project?.rootURL else { return }
        guard settingsStore.settings.format.enable_prettier_js_ts else { return }
        let formatConfig = settingsStore.settings.format.default_style
        let results = codeFormatService.formatProject(at: root, formatConfig: formatConfig)
        // Reload file tree and any open docs possibly affected
        refreshFileTree()
        // If current file was formatted, reload it and restore cursor
        if let currentURL = editorViewModel.currentDocument?.url, results.contains(where: { $0.url == currentURL }) {
            let cursorPositions = editorViewModel.editorState.cursorPositions
            editorViewModel.openDocument(from: currentURL, projectRoot: project?.rootURL, using: fileSystemService)
            editorViewModel.editorState.cursorPositions = cursorPositions
        }
        // Log errors if any
        for res in results where !res.stderr.isEmpty {
            print("Prettier stderr (\(res.url.lastPathComponent)): \(res.stderr)")
        }
    }

    deinit {
        MainActor.assumeIsolated {
            shutdownAgentRuntimes()
            terminalPanelViewModel.killAll()
        }
    }
}

