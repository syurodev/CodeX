//
//  CodeXTests.swift
//  CodeXTests
//
//  Created by Syuro on 4/3/26.
//

import ACPClient
import Foundation
import Testing
@testable import CodeX

struct CodeXTests {

    @Test func claudeLaunchConfigurationUsesUsrBinEnvForDefaultNPXCommand() async throws {
        let config = try #require(
            AgentProvider.claudeCode.defaultACPLaunchConfiguration(
                workingDirectory: URL(fileURLWithPath: "/tmp/MyProject"),
                environment: [:]
            )
        )

        #expect(config.executablePath == "/usr/bin/env")
        #expect(config.arguments == ["npx", "@zed-industries/claude-agent-acp@0.22.2"])
        #expect(config.workingDirectory == "/tmp/MyProject")
    }

    @Test func claudeLaunchConfigurationWrapsBareOverrideCommandWithUsrBinEnv() async throws {
        let config = try #require(
            AgentProvider.claudeCode.defaultACPLaunchConfiguration(
                workingDirectory: nil,
                environment: [
                    "CODEX_CLAUDE_ACP_PATH": "npx",
                    "CODEX_CLAUDE_ACP_ARGS": "tsx /tmp/agent.js"
                ]
            )
        )

        #expect(config.executablePath == "/usr/bin/env")
        #expect(config.arguments == ["npx", "tsx", "/tmp/agent.js"])
    }

    @Test func claudeLaunchConfigurationKeepsAbsoluteOverridePath() async throws {
        let config = try #require(
            AgentProvider.claudeCode.defaultACPLaunchConfiguration(
                workingDirectory: nil,
                environment: [
                    "CODEX_CLAUDE_ACP_PATH": "/Users/test/.nvm/versions/node/v22/bin/npx",
                    "CODEX_CLAUDE_ACP_ARGS": "@zed-industries/claude-agent-acp@0.22.2"
                ]
            )
        )

        #expect(config.executablePath == "/Users/test/.nvm/versions/node/v22/bin/npx")
        #expect(config.arguments == ["@zed-industries/claude-agent-acp@0.22.2"])
    }

    @Test func claudeInitializationOptionsAlwaysIncludeClientVersion() async throws {
        let options = AgentProvider.claudeCode.defaultACPInitializationOptions(environment: [:])

        #expect(options.clientInfo.name == "CodeX")
        #expect(options.clientInfo.version != nil)
        #expect(options.clientInfo.version?.isEmpty == false)
        #expect(options.enableDebugMessages)
    }

    @Test func acpInitializationOptionsDefaultClientVersionIsNonEmpty() async throws {
        let options = ACPClientInitializationOptions()

        #expect(options.clientInfo.version == ACPClientInitializationOptions.defaultClientVersion)
        #expect(options.clientInfo.version?.isEmpty == false)
    }

}
