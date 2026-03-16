import SwiftUI
import AppKit
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
    var projectRunViewModel = ProjectRunViewModel()
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
        setupRunCallbacks()
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.editorViewModel = EditorViewModel(settingsStore: settingsStore)
        let prettierPath = settingsStore.settings.tools.prettier_path
        self.codeFormatService = CodeFormatService(prettierPath: prettierPath.isEmpty ? nil : prettierPath)
        syncToolPaths()
        setupRunCallbacks()
    }

    // MARK: - Run orchestration

    /// Wire `ProjectRunViewModel` events → terminal panel updates.
    private func setupRunCallbacks() {
        projectRunViewModel.onRunEnded = { [weak self] in
            self?.terminalPanelViewModel.updateRunTabAlive(false)
        }
    }

    /// Open the run output tab, show the panel, then start the process.
    func startRun() {
        guard let script = projectRunViewModel.selectedScript else { return }
        terminalPanelViewModel.openRunTab(title: script.name)
        if !isTerminalPanelPresented {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTerminalPanelPresented = true
            }
        }
        projectRunViewModel.run()
    }

    /// Stop the running process and mark the tab as ended.
    func stopRun() {
        projectRunViewModel.stop()
        terminalPanelViewModel.updateRunTabAlive(false)
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
        projectRunViewModel.detect(in: url)

        // Load AI model when a project is opened (if enabled and available)
        let ai = settingsStore.settings.aiCompletion
        if ai.enabled && LocalLLMService.shared.isModelAvailable {
            Task { await LocalLLMService.shared.loadModel() }
        }
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
        editorViewModel.openDocument(from: url, projectRoot: project?.rootURL, using: fileSystemService)
        editorViewModel.editorState.cursorPositions = [CursorPosition(line: line, column: column)]
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
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder to open"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
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

        // Step 1: Try Prettier (synchronous, --write trực tiếp ra đĩa)
        let prettierResult = try? codeFormatService.formatFile(
            at: currentURL,
            workingDirectory: project?.rootURL,
            formatConfig: formatConfig
        )

        if let result = prettierResult, result.changed {
            // Prettier thành công — reload doc đang mở từ đĩa (không dùng openDocument vì nó skip file đã mở)
            editorViewModel.reloadDocument(from: currentURL, using: fileSystemService)
            editorViewModel.editorState.cursorPositions = cursorPositions
            return
        }

        // Step 2: Prettier thất bại hoặc chưa cài — fallback sang Biome
        if let stderr = prettierResult?.stderr, !stderr.isEmpty {
            print("⚠️ Prettier failed, falling back to Biome: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        let docText = editorViewModel.currentDocument?.text ?? ""
        Task { @MainActor in
            if let formatted = await BiomeService.shared.format(
                text: docText,
                fileName: currentURL.lastPathComponent,
                projectRoot: self.project?.rootURL,
                formatConfig: formatConfig
            ) {
                // Biome thành công — ghi ra đĩa rồi reload doc đang mở
                try? self.fileSystemService.writeFile(text: formatted, to: currentURL)
                self.editorViewModel.reloadDocument(from: currentURL, using: self.fileSystemService)
                self.editorViewModel.editorState.cursorPositions = cursorPositions
            } else {
                // Cả Prettier lẫn Biome đều thất bại — plain save không format
                print("⚠️ Biome format also failed — saving without format")
                self.editorViewModel.saveCurrentDocument(using: self.fileSystemService)
            }
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
            projectRunViewModel.stop()
        }
    }
}

// MARK: - File Navigator Context Menu Actions

extension AppViewModel {

    func fileNavigator_newFile(in directory: URL) {
        do {
            let url = try fileSystemService.createFile(named: "untitled", in: directory)
            refreshFileTree()
            editorViewModel.openDocument(from: url, projectRoot: project?.rootURL, using: fileSystemService)
        } catch {
            print("❌ New file failed: \(error)")
        }
    }

    func fileNavigator_newFolder(in directory: URL) {
        do {
            try fileSystemService.createFolder(named: "untitled folder", in: directory)
            refreshFileTree()
        } catch {
            print("❌ New folder failed: \(error)")
        }
    }

    func fileNavigator_rename(_ node: FileNode) {
        let alert = NSAlert()
        alert.messageText = "Rename \"\(node.name)\""
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = node.name
        alert.accessoryView = textField
        alert.layout()
        alert.window.initialFirstResponder = textField
        // Pre-select stem only (exclude extension) for UX convenience
        let stem = (node.name as NSString).deletingPathExtension
        textField.currentEditor()?.selectedRange = NSRange(location: 0, length: stem.count)

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != node.name else { return }

        // Close the document if it's currently open in the editor
        if let doc = editorViewModel.openDocuments.first(where: { $0.url == node.url }) {
            editorViewModel.closeDocument(id: doc.id)
        }
        do {
            try fileSystemService.renameItem(at: node.url, to: newName)
            refreshFileTree()
        } catch {
            print("❌ Rename failed: \(error)")
        }
    }

    func fileNavigator_trash(_ node: FileNode) {
        // Close the document or any documents inside the trashed directory
        if node.isDirectory {
            let prefix = node.url.path
            editorViewModel.openDocuments
                .filter { $0.url.path.hasPrefix(prefix) }
                .forEach { editorViewModel.closeDocument(id: $0.id) }
        } else if let doc = editorViewModel.openDocuments.first(where: { $0.url == node.url }) {
            editorViewModel.closeDocument(id: doc.id)
        }
        do {
            try fileSystemService.trashItem(at: node.url)
            refreshFileTree()
        } catch {
            print("❌ Trash failed: \(error)")
        }
    }

    func fileNavigator_duplicate(_ node: FileNode) {
        do {
            try fileSystemService.duplicateFile(at: node.url)
            refreshFileTree()
        } catch {
            print("❌ Duplicate failed: \(error)")
        }
    }

    func fileNavigator_revealInFinder(_ node: FileNode) {
        fileSystemService.revealInFinder(node.url)
    }

    func fileNavigator_copyPath(_ node: FileNode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.url.path, forType: .string)
    }

    func fileNavigator_copyRelativePath(_ node: FileNode) {
        guard let rootURL = project?.rootURL else {
            fileNavigator_copyPath(node)
            return
        }
        var relative = node.url.path
        let rootPath = rootURL.path
        if relative.hasPrefix(rootPath) {
            relative = String(relative.dropFirst(rootPath.count))
            if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(relative, forType: .string)
    }
}

