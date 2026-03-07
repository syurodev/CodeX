import Foundation

@MainActor
@Observable
final class AgentPanelViewModel {
    var runtimes: [AgentRuntimeViewModel] = []
    var activeRuntimeID: UUID?
    var isShowingLauncher = true
    var selectedLaunchProviderID: AgentProviderID = .claudeCode

    private(set) var workspaceRootURL: URL?
    private let runtimeFactory: @MainActor (AgentProvider, String, URL?) -> AgentRuntimeViewModel

    init(
        runtimeFactory: @escaping @MainActor (AgentProvider, String, URL?) -> AgentRuntimeViewModel = { provider, title, workingDirectory in
            AgentRuntimeViewModel(
                provider: provider,
                title: title,
                workingDirectory: workingDirectory
            )
        }
    ) {
        self.runtimeFactory = runtimeFactory
    }

    deinit {
        MainActor.assumeIsolated {
            shutdownAllRuntimes()
        }
    }

    var availableProviders: [AgentProvider] {
        AgentProviderRegistry.availableProviders
    }

    var activeRuntime: AgentRuntimeViewModel? {
        guard let activeRuntimeID else { return nil }
        return runtimes.first { $0.id == activeRuntimeID }
    }

    var selectedLaunchProvider: AgentProvider? {
        AgentProviderRegistry.provider(for: selectedLaunchProviderID)
    }

    var workspaceDisplayName: String {
        workspaceRootURL?.lastPathComponent ?? "No project opened"
    }

    func updateWorkspaceRoot(_ url: URL?) {
        workspaceRootURL = url
    }

    func showLauncher() {
        isShowingLauncher = true
    }

    func startSelectedProvider() {
        guard let provider = selectedLaunchProvider else { return }

        let runtime = runtimeFactory(provider, nextRuntimeTitle(for: provider), workspaceRootURL)

        runtimes.append(runtime)
        activeRuntimeID = runtime.id
        isShowingLauncher = false
    }

    func selectRuntime(id: UUID) {
        activeRuntimeID = id
        isShowingLauncher = false
    }

    func closeRuntime(id: UUID) {
        guard let index = runtimes.firstIndex(where: { $0.id == id }) else { return }
        let runtime = runtimes[index]
        runtime.stop()

        let wasActive = activeRuntimeID == id
        runtimes.remove(at: index)

        guard !runtimes.isEmpty else {
            activeRuntimeID = nil
            isShowingLauncher = true
            return
        }

        if wasActive {
            let newIndex = min(index, runtimes.count - 1)
            activeRuntimeID = runtimes[newIndex].id
        }
    }

    func shutdownAllRuntimes() {
        guard !runtimes.isEmpty else {
            activeRuntimeID = nil
            isShowingLauncher = true
            return
        }

        let currentRuntimes = runtimes
        runtimes.removeAll()
        activeRuntimeID = nil
        isShowingLauncher = true

        for runtime in currentRuntimes {
            runtime.stop()
        }
    }

    private func nextRuntimeTitle(for provider: AgentProvider) -> String {
        let ordinal = runtimes.filter { $0.provider.id == provider.id }.count + 1
        return "\(provider.displayName) #\(ordinal)"
    }
}