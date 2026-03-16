import Foundation

// MARK: - Run output tab model

/// Lightweight descriptor for the pinned "run output" tab.
/// The actual output content lives in `ProjectRunViewModel`.
struct RunOutputTabModel: Identifiable {
    let id = UUID()
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

    // Run output tab — always rendered first in the tab bar
    var runOutputItem: RunOutputTabModel? = nil
    /// When `true`, the run output view is shown instead of a terminal session.
    var isRunTabActive: Bool = false

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
        isRunTabActive = false   // switch away from run tab
    }

    func closeSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = (activeSessionID == id) && !isRunTabActive
        sessions.remove(at: index)

        if sessions.isEmpty {
            activeSessionID = nil
            // Fall back to run tab if it exists, otherwise nothing
            isRunTabActive = runOutputItem != nil
            return
        }

        if wasActive {
            let newIndex = min(index, sessions.count - 1)
            activeSessionID = sessions[newIndex].id
        }
    }

    func selectSession(id: UUID) {
        activeSessionID = id
        isRunTabActive = false   // switch away from run tab
    }

    // MARK: - Run tab management

    /// Create or refresh the run output tab and make it active.
    func openRunTab(title: String) {
        if runOutputItem == nil {
            runOutputItem = RunOutputTabModel(title: title, isAlive: true)
        } else {
            runOutputItem?.title = title
            runOutputItem?.isAlive = true
        }
        isRunTabActive = true
    }

    /// Remove the run output tab entirely.
    func closeRunTab() {
        runOutputItem = nil
        isRunTabActive = false
    }

    func selectRunTab() {
        guard runOutputItem != nil else { return }
        isRunTabActive = true
    }

    /// Call when the process exits to update the tab's alive indicator.
    func updateRunTabAlive(_ alive: Bool) {
        runOutputItem?.isAlive = alive
    }

    func killAll() {
        sessions.removeAll()
        activeSessionID = nil
    }

    /// Mở session mới tại thư mục của file đang chỉnh sửa (nếu có), fallback về project root.
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
