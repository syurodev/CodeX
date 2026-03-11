import Foundation

@MainActor
@Observable
final class TerminalPanelViewModel {
    var sessions: [TerminalSessionViewModel] = []
    var activeSessionID: UUID?

    private let terminalService: TerminalService

    init() {
        self.terminalService = TerminalService()
    }

    init(terminalService: TerminalService) {
        self.terminalService = terminalService
    }

    var activeSession: TerminalSessionViewModel? {
        guard let activeSessionID else { return nil }
        return sessions.first { $0.id == activeSessionID }
    }

    func newSession(workingDirectory: URL?) {
        let config = terminalService.makeConfig(workingDirectory: workingDirectory)
        let session = TerminalSessionViewModel(title: nextTitle(), config: config)
        sessions.append(session)
        activeSessionID = session.id
    }

    func closeSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeSessionID == id
        sessions.remove(at: index)

        guard !sessions.isEmpty else {
            activeSessionID = nil
            return
        }

        if wasActive {
            let newIndex = min(index, sessions.count - 1)
            activeSessionID = sessions[newIndex].id
        }
    }

    func selectSession(id: UUID) {
        activeSessionID = id
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
