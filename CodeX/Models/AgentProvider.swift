import ACPClient
import Foundation

enum AgentProviderID: String, CaseIterable, Identifiable {
    case claudeCode
    case githubCopilot

    var id: String { rawValue }
}

struct AgentProvider: Identifiable, Hashable {
    let id: AgentProviderID
    let displayName: String
    let subtitle: String
    let systemImage: String
    let iconImageName: String

    static let claudeCode = AgentProvider(
        id: .claudeCode,
        displayName: "Claude Code",
        subtitle: "ACP runtime via claude-agent-acp adapter",
        systemImage: "sparkles.rectangle.stack",
        iconImageName: "claude-icon"
    )

    static let githubCopilot = AgentProvider(
        id: .githubCopilot,
        displayName: "GitHub Copilot",
        subtitle: "Copilot CLI in ACP server mode",
        systemImage: "bolt.horizontal.circle",
        iconImageName: "copilot-icon"
    )
}

extension AgentProvider {
    func defaultACPLaunchConfiguration(workingDirectory: URL?) -> ACPClientLaunchConfiguration? {
        defaultACPLaunchConfiguration(
            workingDirectory: workingDirectory,
            environment: ProcessInfo.processInfo.environment
        )
    }

    func defaultACPLaunchConfiguration(
        workingDirectory: URL?,
        environment: [String: String]
    ) -> ACPClientLaunchConfiguration? {
        switch id {
        case .claudeCode:
            let executablePath = environment["CODEX_CLAUDE_ACP_PATH"] ?? "npx"
            let arguments: [String]

            if environment["CODEX_CLAUDE_ACP_PATH"] != nil {
                arguments = environment["CODEX_CLAUDE_ACP_ARGS"]?
                    .split(separator: " ")
                    .map(String.init) ?? []
            } else {
                let package = environment["CODEX_CLAUDE_ACP_PACKAGE"] ?? "@zed-industries/claude-agent-acp@0.22.2"
                arguments = [package]
            }

            return makeLaunchConfiguration(
                command: executablePath,
                arguments: arguments,
                workingDirectory: workingDirectory
            )
        case .githubCopilot:
            let executablePath = environment["CODEX_COPILOT_ACP_PATH"] ?? "copilot"
            let arguments = environment["CODEX_COPILOT_ACP_ARGS"]?
                .split(separator: " ")
                .map(String.init)
                ?? ["--acp", "--stdio"]
            return makeLaunchConfiguration(
                command: executablePath,
                arguments: arguments,
                workingDirectory: workingDirectory
            )
        }
    }

    var defaultACPInitializationOptions: ACPClientInitializationOptions {
        let environment = ProcessInfo.processInfo.environment
        return defaultACPInitializationOptions(environment: environment)
    }

    func defaultACPInitializationOptions(
        environment: [String: String]
    ) -> ACPClientInitializationOptions {
        ACPClientInitializationOptions(
            clientInfo: .init(
                name: "CodeX",
                title: "CodeX",
                version: defaultACPClientVersion
            ),
            enableDebugMessages: shouldEnableACPDebugMessages(environment: environment)
        )
    }

    private var defaultACPClientVersion: String {
        let versionKeys = ["CFBundleShortVersionString", "CFBundleVersion"]

        for key in versionKeys {
            if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        return ACPClientInitializationOptions.defaultClientVersion
    }

    private func makeLaunchConfiguration(
        command: String,
        arguments: [String],
        workingDirectory: URL?
    ) -> ACPClientLaunchConfiguration {
        let normalizedCommand = (command as NSString).expandingTildeInPath

        if normalizedCommand.contains("/") {
            return ACPClientLaunchConfiguration(
                executablePath: normalizedCommand,
                arguments: arguments,
                workingDirectory: workingDirectory?.path,
                environment: nil
            )
        }

        return ACPClientLaunchConfiguration(
            executablePath: "/usr/bin/env",
            arguments: [normalizedCommand] + arguments,
            workingDirectory: workingDirectory?.path,
            environment: nil
        )
    }

    private func shouldEnableACPDebugMessages(environment: [String: String]) -> Bool {
        if let rawValue = environment["CODEX_ACP_DEBUG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            return ["1", "true", "yes", "on"].contains(rawValue)
        }

        return true
    }
}

enum AgentRuntimeState: String {
    case starting
    case ready
    case busy
    case stopped
    case error

    var label: String {
        switch self {
        case .starting: return "Starting"
        case .ready: return "Ready"
        case .busy: return "Busy"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }
}

struct AgentProviderRegistry {
    static let availableProviders: [AgentProvider] = [
        .claudeCode,
        .githubCopilot
    ]

    static func provider(for id: AgentProviderID) -> AgentProvider? {
        availableProviders.first { $0.id == id }
    }
}