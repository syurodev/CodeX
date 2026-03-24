import Foundation

// MARK: - Run output tab model

/// Lightweight descriptor for a pinned "run output" tab.
/// The actual output content lives in `ProjectRunViewModel`.
struct RunOutputTabModel: Identifiable {
    let id = UUID()
    let scriptId: String   // links to ProjectRunViewModel.perScriptOutputLines key
    var title: String
    /// `false` once the process exits (tab stays visible but icon changes).
    var isAlive: Bool
}

// MARK: - TerminalPanelViewModel

@MainActor
@Observable
final class TerminalPanelViewModel {
    var sessions: [TerminalSessionViewModel] = []
    var activeSessionID: UUID?

    // Run output tabs — always rendered first in the tab bar
    var runOutputItems: [RunOutputTabModel] = []
    var activeRunTabID: UUID? = nil

    /// `true` when a run tab is the active pane.
    var isRunTabActive: Bool { activeRunTabID != nil }

    /// The currently active run tab item, if any.
    var activeRunItem: RunOutputTabModel? {
        runOutputItems.first { $0.id == activeRunTabID }
    }

    private let terminalService: TerminalService

    init() {
        self.terminalService = TerminalService()
    }

    init(terminalService: TerminalService) {
        self.terminalService = terminalService
    }

    /// Non-nil only when a terminal session (not the run tab) is the active pane.
    var activeSession: TerminalSessionViewModel? {
        guard !isRunTabActive, let activeSessionID else { return nil }
        return sessions.first { $0.id == activeSessionID }
    }

    func newSession(workingDirectory: URL?) {
        let config = terminalService.makeConfig(workingDirectory: workingDirectory)
        let session = TerminalSessionViewModel(title: nextTitle(), config: config)
        sessions.append(session)
        activeSessionID = session.id
        activeRunTabID = nil   // switch away from run tab
    }

    func closeSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = (activeSessionID == id) && !isRunTabActive
        sessions.remove(at: index)

        if sessions.isEmpty {
            activeSessionID = nil
            activeRunTabID = runOutputItems.last?.id
            return
        }

        if wasActive {
            let newIndex = min(index, sessions.count - 1)
            activeSessionID = sessions[newIndex].id
        }
    }

    func selectSession(id: UUID) {
        activeSessionID = id
        activeRunTabID = nil   // switch away from run tab
    }

    // MARK: - Run tab management

    /// Create or refresh the run output tab for the given script and make it active.
    func openRunTab(scriptId: String, title: String) {
        if let idx = runOutputItems.firstIndex(where: { $0.scriptId == scriptId }) {
            runOutputItems[idx].title = title
            runOutputItems[idx].isAlive = true
            activeRunTabID = runOutputItems[idx].id
        } else {
            let item = RunOutputTabModel(scriptId: scriptId, title: title, isAlive: true)
            runOutputItems.append(item)
            activeRunTabID = item.id
        }
    }

    /// Remove a specific run output tab.
    func closeRunTab(id: UUID) {
        runOutputItems.removeAll { $0.id == id }
        if activeRunTabID == id {
            activeRunTabID = runOutputItems.last?.id
            if activeRunTabID == nil, let first = sessions.first {
                activeSessionID = first.id
            }
        }
    }

    func selectRunTab(id: UUID) {
        guard runOutputItems.contains(where: { $0.id == id }) else { return }
        activeRunTabID = id
    }

    /// Update the alive indicator for the run tab associated with a specific script.
    func updateRunTabAlive(scriptId: String, alive: Bool) {
        if let idx = runOutputItems.firstIndex(where: { $0.scriptId == scriptId }) {
            runOutputItems[idx].isAlive = alive
        }
    }

    /// Update the alive indicator for all run tabs.
    func updateAllRunTabsAlive(_ alive: Bool) {
        for i in runOutputItems.indices {
            runOutputItems[i].isAlive = alive
        }
    }

    func killAll() {
        sessions.removeAll()
        activeSessionID = nil
    }

    /// Open a new session at the directory of the currently edited file, falling back to the project root.
    func newSessionAtCurrentFile(fileURL: URL?, projectRoot: URL?) {
        let directory = fileURL?.deletingLastPathComponent() ?? projectRoot
        newSession(workingDirectory: directory)
    }

    private func nextTitle() -> String {
        let shellName = URL(fileURLWithPath: TerminalService.userShell()).lastPathComponent
        let count = sessions.count + 1
        return count == 1 ? shellName : "\(shellName) \(count)"
    }
}
