import Foundation

@MainActor
@Observable
final class TerminalSessionViewModel: Identifiable {
    let id = UUID()
    let config: TerminalSessionConfig
    var title: String
    var workingDirectory: URL
    var isAlive: Bool = true

    init(title: String, config: TerminalSessionConfig) {
        self.title = title
        self.config = config
        self.workingDirectory = config.initialWorkingDirectory
    }
}
