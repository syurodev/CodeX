import ACPClient
import Foundation
import Testing
@testable import CodeX

@MainActor
struct AgentPanelViewModelTests {

    @Test func runtimeStreamsAssistantReplyFromACPTransport() async throws {
        let runtime = AgentRuntimeViewModel(
            provider: .claudeCode,
            title: "Claude Code #1",
            workingDirectory: URL(fileURLWithPath: "/tmp/MyProject"),
            transportFactory: {
                MockAgentRuntimeTransport(
                    handshake: .init(
                        protocolVersion: 1,
                        agentName: "claude-code-acp",
                        agentTitle: "Claude Code",
                        agentVersion: "0.16.1",
                        authMethodNames: []
                    ),
                    session: .init(id: "session-1", currentModeID: nil, currentModelID: nil),
                    promptEvents: [
                        .session(.textChunk(sessionID: "session-1", source: .agent, text: "Xin chào")),
                        .session(.textChunk(sessionID: "session-1", source: .agent, text: " từ ACP"))
                    ]
                )
            }
        )

        try await waitUntil { runtime.state == .ready }
        runtime.submitPrompt("Hello")

        try await waitUntil {
            runtime.state == .ready
            && runtime.messages.contains(where: { $0.role == .assistant && $0.content == "Xin chào từ ACP" })
        }

        #expect(runtime.lastError == nil)
    }

    @Test func runtimeTracksRealtimeThinkingAndToolActivities() async throws {
        let runtime = AgentRuntimeViewModel(
            provider: .claudeCode,
            title: "Claude Code #1",
            workingDirectory: URL(fileURLWithPath: "/tmp/MyProject"),
            transportFactory: {
                MockAgentRuntimeTransport(
                    handshake: .init(
                        protocolVersion: 1,
                        agentName: "claude-code-acp",
                        agentTitle: "Claude Code",
                        agentVersion: "0.16.1",
                        authMethodNames: []
                    ),
                    session: .init(id: "session-1", currentModeID: nil, currentModelID: nil),
                    promptEvents: [
                        .session(.textChunk(sessionID: "session-1", source: .thought, text: "Đang đọc project")),
                        .session(.toolCall(.init(
                            sessionID: "session-1",
                            toolCallID: "tool-1",
                            title: "Read file",
                            kind: "read_file",
                            status: "running"
                        ))),
                        .session(.toolCallUpdate(.init(
                            sessionID: "session-1",
                            toolCallID: "tool-1",
                            title: "Read file",
                            kind: "read_file",
                            status: "completed"
                        ))),
                        .session(.textChunk(sessionID: "session-1", source: .agent, text: "Xong rồi"))
                    ]
                )
            }
        )

        try await waitUntil { runtime.state == .ready }
        runtime.submitPrompt("Check project")

        try await waitUntil {
            runtime.state == .ready
            && runtime.activities.contains(where: { $0.kind == .thinking && $0.detail == "Đang đọc project" })
            && runtime.activities.contains(where: { $0.kind == .tool && $0.title == "Read file" && $0.status == .completed })
        }

        let thinking = try #require(runtime.activities.first(where: { $0.kind == .thinking }))
        #expect(thinking.status == .completed)

        #expect(runtime.messages.contains(where: { $0.role == .assistant && $0.content == "Xong rồi" }))
        #expect(runtime.messages.contains(where: { $0.content.contains("Thought:") }) == false)
        #expect(runtime.messages.contains(where: { $0.content.contains("Tool started:") || $0.content.contains("Tool update:") }) == false)

        let transcriptLabels = runtime.transcriptEntries.map { entry in
            switch entry {
            case let .message(message):
                return "message:\(message.role.rawValue):\(message.content)"
            case let .activity(activity):
                return "activity:\(activity.id):\(activity.status.label)"
            }
        }

        let userIndex = try #require(transcriptLabels.firstIndex(of: "message:user:Check project"))
        let thinkingIndex = try #require(transcriptLabels.firstIndex(of: "activity:thinking:Done"))
        let toolIndex = try #require(transcriptLabels.firstIndex(of: "activity:tool-tool-1:Done"))
        let assistantIndex = try #require(transcriptLabels.firstIndex(of: "message:assistant:Xong rồi"))

        #expect(userIndex < thinkingIndex)
        #expect(thinkingIndex < toolIndex)
        #expect(toolIndex < assistantIndex)
        #expect(transcriptLabels.filter { $0 == "activity:tool-tool-1:Done" }.count == 1)
    }

    @Test func transcriptEntriesMergeMessagesAndActivitiesByCreationOrder() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let entries = AgentTranscriptEntry.merge(
            messages: [
                AgentMessage(role: .system, content: "System", createdAt: start),
                AgentMessage(role: .user, content: "Open file", createdAt: start.addingTimeInterval(1)),
                AgentMessage(role: .assistant, content: "Done", createdAt: start.addingTimeInterval(4))
            ],
            activities: [
                AgentActivity(
                    id: "thinking",
                    kind: .thinking,
                    title: "Thinking",
                    detail: "Checking project",
                    status: .completed,
                    createdAt: start.addingTimeInterval(2),
                    updatedAt: start.addingTimeInterval(5)
                ),
                AgentActivity(
                    id: "tool-read-file",
                    kind: .tool,
                    title: "Read file",
                    detail: "AgentPanelView.swift",
                    status: .completed,
                    createdAt: start.addingTimeInterval(3),
                    updatedAt: start.addingTimeInterval(6)
                )
            ]
        )

        let labels = entries.map { entry in
            switch entry {
            case let .message(message):
                return "message:\(message.role.rawValue):\(message.content)"
            case let .activity(activity):
                return "activity:\(activity.id)"
            }
        }

        #expect(labels == [
            "message:user:Open file",
            "activity:thinking",
            "activity:tool-read-file",
            "message:assistant:Done"
        ])
    }

    @Test func stoppingResponseCancelsPromptWithoutTerminatingRuntime() async throws {
        let probe = RuntimeLifecycleProbe()
        let runtime = AgentRuntimeViewModel(
            provider: .claudeCode,
            title: "Claude Code #1",
            workingDirectory: URL(fileURLWithPath: "/tmp/MyProject"),
            transportFactory: {
                MockAgentRuntimeTransport(
                    handshake: .init(
                        protocolVersion: 1,
                        agentName: "claude-code-acp",
                        agentTitle: "Claude Code",
                        agentVersion: "0.16.1",
                        authMethodNames: []
                    ),
                    session: .init(id: "session-1", currentModeID: nil, currentModelID: nil),
                    promptResult: .init(stopReason: "cancelled"),
                    lifecycleProbe: probe,
                    waitForCancelBeforeCompletingPrompt: true
                )
            }
        )

        try await waitUntil { runtime.state == .ready }
        runtime.submitPrompt("Stop this response")

        try await waitUntil { runtime.state == .busy }
        runtime.stopResponding()

        try await waitUntil { runtime.state == .ready }

        #expect(probe.cancelPromptCallCount == 1)
        #expect(probe.terminateCallCount == 0)
        #expect(runtime.lastError == nil)
    }

    @Test func panelStartsEmptyAndShowsLauncher() async throws {
        let viewModel = AgentPanelViewModel(runtimeFactory: makeRuntimeFactory())

        #expect(viewModel.runtimes.isEmpty)
        #expect(viewModel.activeRuntime == nil)
        #expect(viewModel.isShowingLauncher)
    }

    @Test func streamingTextChangeAnimatesOnlyNewSuffix() {
        let change = AgentStreamingTextChange(previous: "Xin chào", current: "Xin chào thế giới")

        #expect(change.stablePrefix == "Xin chào")
        #expect(change.animatedSuffix == " thế giới")
    }

    @Test func streamingTextChangeFallsBackToStaticWhenTextIsRewritten() {
        let change = AgentStreamingTextChange(previous: "Xin chào", current: "Chào lại từ đầu")

        #expect(change.stablePrefix == "Chào lại từ đầu")
        #expect(change.animatedSuffix.isEmpty)
    }

    @Test func streamingTextBatchingKeepsShortSuffixInSingleBatch() {
        let batches = AgentStreamingTextBatching.batches(for: " thế giới")

        #expect(batches.count == 1)
        #expect(batches.first?.text == " thế giới")
        #expect(batches.first?.totalCount == 1)
    }

    @Test func streamingTextBatchingSplitsLongSuffixIntoSmallerBatches() {
        let suffix = " đang stream một đoạn text đủ dài để tách batch"
        let batches = AgentStreamingTextBatching.batches(for: suffix)

        #expect(batches.count > 1)
        #expect(batches.map(\.text).joined() == suffix)
        #expect(batches.allSatisfy { !$0.text.isEmpty })
        #expect(batches.allSatisfy { $0.text.count <= 24 })
        #expect(batches.map(\.totalCount).allSatisfy { $0 == batches.count })
    }

    @Test func transcriptAutoScrollDetectsWhenViewportIsNearBottom() {
        #expect(
            AgentTranscriptAutoScrollState.isNearBottom(
                contentOffsetY: 520,
                contentHeight: 1000,
                containerHeight: 440,
                threshold: 72
            )
        )
    }

    @Test func transcriptAutoScrollStopsWhenUserScrollsAwayFromBottom() {
        #expect(
            AgentTranscriptAutoScrollState.isNearBottom(
                contentOffsetY: 320,
                contentHeight: 1000,
                containerHeight: 440,
                threshold: 72
            ) == false
        )
    }

    @Test func transcriptAutoScrollStaysPinnedWhenContentGrowsAtBottom() {
        let previousMetrics = AgentTranscriptScrollMetrics(
            contentOffsetY: 520,
            contentHeight: 1000,
            containerHeight: 440
        )
        let newMetrics = AgentTranscriptScrollMetrics(
            contentOffsetY: 520,
            contentHeight: 1040,
            containerHeight: 440
        )

        #expect(
            AgentTranscriptAutoScrollState.nextPinnedState(
                currentPinned: true,
                previousMetrics: previousMetrics,
                newMetrics: newMetrics,
                threshold: 72
            )
        )
    }

    @Test func transcriptAutoScrollUnpinsWhenUserIntentionallyScrollsUp() {
        let previousMetrics = AgentTranscriptScrollMetrics(
            contentOffsetY: 520,
            contentHeight: 1000,
            containerHeight: 440
        )
        let newMetrics = AgentTranscriptScrollMetrics(
            contentOffsetY: 420,
            contentHeight: 1000,
            containerHeight: 440
        )

        #expect(
            AgentTranscriptAutoScrollState.nextPinnedState(
                currentPinned: true,
                previousMetrics: previousMetrics,
                newMetrics: newMetrics,
                threshold: 72
            ) == false
        )
    }

    @Test func transcriptBottomClearanceIncludesComposerHeightAndOuterPadding() {
        #expect(
            AgentTranscriptLayout.bottomClearance(
                composerHeight: 72,
                composerOuterPadding: 16
            ) == 88
        )
    }

    @Test func transcriptBottomClearanceIgnoresNegativeOuterPadding() {
        #expect(
            AgentTranscriptLayout.bottomClearance(
                composerHeight: 72,
                composerOuterPadding: -10
            ) == 72
        )
    }

    @Test func transcriptUnreadCountAccumulatesWhenNotPinned() {
        let unreadCount = AgentTranscriptUnreadState.nextUnreadCount(currentCount: 2, isPinnedToBottom: false)

        #expect(unreadCount == 3)
        #expect(AgentTranscriptUnreadState.badgeText(for: unreadCount) == "3")
    }

    @Test func transcriptUnreadCountResetsWhenPinnedToBottom() {
        #expect(AgentTranscriptUnreadState.nextUnreadCount(currentCount: 5, isPinnedToBottom: true) == 0)
    }

    @Test func transcriptUnreadCountCapsAtNinetyNine() {
        let unreadCount = AgentTranscriptUnreadState.nextUnreadCount(currentCount: 99, isPinnedToBottom: false)

        #expect(unreadCount == 99)
        #expect(AgentTranscriptUnreadState.badgeText(for: 120) == "99+")
    }

    @Test func startingProviderCreatesActiveRuntimeTab() async throws {
        let viewModel = AgentPanelViewModel(runtimeFactory: makeRuntimeFactory())
        viewModel.updateWorkspaceRoot(URL(fileURLWithPath: "/tmp/MyProject"))

        viewModel.startSelectedProvider()

        #expect(viewModel.runtimes.count == 1)
        #expect(viewModel.activeRuntime?.title == "Claude Code #1")
        #expect(viewModel.activeRuntime?.workingDirectory?.lastPathComponent == "MyProject")
        #expect(viewModel.isShowingLauncher == false)
    }

    @Test func closingLastRuntimeReturnsToLauncher() async throws {
        let viewModel = AgentPanelViewModel(runtimeFactory: makeRuntimeFactory())
        viewModel.startSelectedProvider()

        let runtimeID = try #require(viewModel.activeRuntime?.id)
        viewModel.closeRuntime(id: runtimeID)

        #expect(viewModel.runtimes.isEmpty)
        #expect(viewModel.activeRuntime == nil)
        #expect(viewModel.isShowingLauncher)
    }

    @Test func closingRuntimeTerminatesAgentProcess() async throws {
        let probe = RuntimeLifecycleProbe()
        let viewModel = AgentPanelViewModel(runtimeFactory: makeRuntimeFactory(lifecycleProbe: probe))
        viewModel.startSelectedProvider()

        try await waitUntil { viewModel.activeRuntime?.state == .ready }

        let runtimeID = try #require(viewModel.activeRuntime?.id)
        viewModel.closeRuntime(id: runtimeID)

        try await waitUntil {
            viewModel.runtimes.isEmpty
            && probe.terminateCallCount == 1
        }
    }

    @Test func shuttingDownAllRuntimesTerminatesEveryAgentProcess() async throws {
        let probe = RuntimeLifecycleProbe()
        let viewModel = AgentPanelViewModel(runtimeFactory: makeRuntimeFactory(lifecycleProbe: probe))
        viewModel.startSelectedProvider()
        viewModel.startSelectedProvider()

        try await waitUntil {
            viewModel.runtimes.count == 2
            && viewModel.runtimes.allSatisfy { $0.state == .ready }
        }

        viewModel.shutdownAllRuntimes()

        try await waitUntil {
            viewModel.runtimes.isEmpty
            && viewModel.activeRuntime == nil
            && viewModel.isShowingLauncher
            && probe.terminateCallCount == 2
        }
    }

    @Test func togglingAgentPanelKeepsRuntimeTabsAndProcessesAlive() async throws {
        let probe = RuntimeLifecycleProbe()
        let appViewModel = AppViewModel()
        appViewModel.agentPanelViewModel = AgentPanelViewModel(runtimeFactory: makeRuntimeFactory(lifecycleProbe: probe))

        appViewModel.agentPanelViewModel.startSelectedProvider()

        try await waitUntil { appViewModel.agentPanelViewModel.activeRuntime?.state == .ready }

        let runtimeID = try #require(appViewModel.agentPanelViewModel.activeRuntime?.id)

        appViewModel.openAgentPanel()
        appViewModel.openAgentPanel()

        #expect(appViewModel.isAgentInspectorPresented == false)
        #expect(appViewModel.agentPanelViewModel.runtimes.count == 1)
        #expect(appViewModel.agentPanelViewModel.activeRuntime?.id == runtimeID)
        #expect(probe.terminateCallCount == 0)
    }

    private func makeRuntimeFactory(
        lifecycleProbe: RuntimeLifecycleProbe? = nil
    ) -> @MainActor (AgentProvider, String, URL?) -> AgentRuntimeViewModel {
        { provider, title, workingDirectory in
            AgentRuntimeViewModel(
                provider: provider,
                title: title,
                workingDirectory: workingDirectory,
                transportFactory: {
                    MockAgentRuntimeTransport(
                        handshake: .init(
                            protocolVersion: 1,
                            agentName: "claude-code-acp",
                            agentTitle: "Claude Code",
                            agentVersion: "0.16.1",
                            authMethodNames: []
                        ),
                        session: .init(id: UUID().uuidString, currentModeID: nil, currentModelID: nil),
                        lifecycleProbe: lifecycleProbe
                    )
                }
            )
        }
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        Issue.record("Condition was not satisfied before timeout")
        throw CancellationError()
    }
}

@MainActor
private final class RuntimeLifecycleProbe {
    var cancelPromptCallCount = 0
    var terminateCallCount = 0
}

private actor MockAgentRuntimeTransport: AgentRuntimeTransporting {
    private let handshake: ACPClientHandshake
    private let session: ACPClientSession
    private let promptEvents: [ACPClientEvent]
    private let promptResult: ACPClientPromptResult
    private let lifecycleProbe: RuntimeLifecycleProbe?
    private let waitForCancelBeforeCompletingPrompt: Bool

    private let eventStream: AsyncStream<ACPClientEvent>
    private let continuation: AsyncStream<ACPClientEvent>.Continuation
    private var hasPendingCancelRequest = false
    private var waitForCancelContinuation: CheckedContinuation<Void, Never>?

    init(
        handshake: ACPClientHandshake,
        session: ACPClientSession,
        promptEvents: [ACPClientEvent] = [],
        promptResult: ACPClientPromptResult = .init(stopReason: "end_turn"),
        lifecycleProbe: RuntimeLifecycleProbe? = nil,
        waitForCancelBeforeCompletingPrompt: Bool = false
    ) {
        self.handshake = handshake
        self.session = session
        self.promptEvents = promptEvents
        self.promptResult = promptResult
        self.lifecycleProbe = lifecycleProbe
        self.waitForCancelBeforeCompletingPrompt = waitForCancelBeforeCompletingPrompt

        var continuation: AsyncStream<ACPClientEvent>.Continuation!
        self.eventStream = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    func launch(_ configuration: ACPClientLaunchConfiguration) async throws {}

    func initialize(_ options: ACPClientInitializationOptions) async throws -> ACPClientHandshake {
        handshake
    }

    func startSession(_ configuration: ACPClientSessionConfiguration) async throws -> ACPClientSession {
        session
    }

    func sendPrompt(_ text: String, sessionID: String) async throws -> ACPClientPromptResult {
        if waitForCancelBeforeCompletingPrompt {
            if hasPendingCancelRequest {
                hasPendingCancelRequest = false
            } else {
                await withCheckedContinuation { continuation in
                    waitForCancelContinuation = continuation
                }
            }
        }

        for event in promptEvents {
            continuation.yield(event)
        }
        return promptResult
    }

    func cancelPrompt(sessionID: String) async throws {
        await MainActor.run {
            lifecycleProbe?.cancelPromptCallCount += 1
        }

        if let waitForCancelContinuation {
            self.waitForCancelContinuation = nil
            waitForCancelContinuation.resume()
        } else {
            hasPendingCancelRequest = true
        }
    }

    func events() async -> AsyncStream<ACPClientEvent> {
        eventStream
    }

    func debugMessages() async -> AsyncStream<ACPClientDebugMessage> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func terminate() async {
        await MainActor.run {
            lifecycleProbe?.terminateCallCount += 1
        }
        continuation.finish()
    }
}