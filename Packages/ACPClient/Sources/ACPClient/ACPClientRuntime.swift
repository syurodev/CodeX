import ACP
import ACPModel
import Foundation

public actor ACPClientRuntime {
    private let client: Client
    private let delegateBridge: ACPClientDelegateBridge
    private let eventStream: AsyncStream<ACPClientEvent>
    private let eventContinuation: AsyncStream<ACPClientEvent>.Continuation
    private let debugStream: AsyncStream<ACPClientDebugMessage>
    private let debugContinuation: AsyncStream<ACPClientDebugMessage>.Continuation

    private var didPrepareClient = false
    private var notificationTask: Task<Void, Never>?
    private var debugTask: Task<Void, Never>?

    public init(permissionHandler: ACPClientPermissionHandler? = nil) {
        client = Client()
        delegateBridge = ACPClientDelegateBridge(permissionHandler: permissionHandler)

        var eventContinuation: AsyncStream<ACPClientEvent>.Continuation!
        eventStream = AsyncStream { continuation in
            eventContinuation = continuation
        }
        self.eventContinuation = eventContinuation

        var debugContinuation: AsyncStream<ACPClientDebugMessage>.Continuation!
        debugStream = AsyncStream { continuation in
            debugContinuation = continuation
        }
        self.debugContinuation = debugContinuation
    }

    public func events() -> AsyncStream<ACPClientEvent> {
        eventStream
    }

    public func debugMessages() -> AsyncStream<ACPClientDebugMessage> {
        debugStream
    }

    public func launch(_ configuration: ACPClientLaunchConfiguration) async throws {
        try await prepareClientIfNeeded()
        try await client.launch(
            agentPath: configuration.executablePath,
            arguments: configuration.arguments,
            workingDirectory: configuration.workingDirectory,
            environment: configuration.environment
        )
        await startNotificationTaskIfNeeded()
    }

    public func initialize(_ options: ACPClientInitializationOptions = .init()) async throws -> ACPClientHandshake {
        try await prepareClientIfNeeded()

        if options.enableDebugMessages {
            await client.enableDebugStream()
            await startDebugTaskIfNeeded()
        }

        let response = try await client.initialize(
            protocolVersion: options.protocolVersion,
            capabilities: ClientCapabilities(
                fs: .init(
                    readTextFile: options.capabilities.canReadTextFiles,
                    writeTextFile: options.capabilities.canWriteTextFiles
                ),
                terminal: options.capabilities.supportsTerminal
            ),
            clientInfo: ClientInfo(
                name: options.clientInfo.name,
                title: options.clientInfo.title,
                version: options.clientInfo.version
            ),
            timeout: options.timeout
        )

        return ACPClientHandshake(
            protocolVersion: response.protocolVersion,
            agentName: response.agentInfo?.name,
            agentTitle: response.agentInfo?.title,
            agentVersion: response.agentInfo?.version,
            authMethodNames: response.authMethods?.map(\.name) ?? []
        )
    }

    public func startSession(_ configuration: ACPClientSessionConfiguration) async throws -> ACPClientSession {
        let response = try await client.newSession(workingDirectory: configuration.workingDirectory)
        return ACPClientSession(
            id: response.sessionId.value,
            currentModeID: response.modes?.currentModeId,
            currentModelID: response.models?.currentModelId
        )
    }

    public func sendPrompt(_ text: String, sessionID: String) async throws -> ACPClientPromptResult {
        let response = try await client.sendPrompt(
            sessionId: SessionId(sessionID),
            content: [.text(TextContent(text: text))]
        )
        return ACPClientPromptResult(stopReason: response.stopReason.rawValue)
    }

    public func cancelPrompt(sessionID: String) async throws {
        try await client.cancelSession(sessionId: SessionId(sessionID))
    }

    public func terminate() async {
        notificationTask?.cancel()
        debugTask?.cancel()
        notificationTask = nil
        debugTask = nil
        await client.terminate()
        eventContinuation.finish()
        debugContinuation.finish()
    }

    private func prepareClientIfNeeded() async throws {
        guard !didPrepareClient else { return }
        await client.setDelegate(delegateBridge)
        didPrepareClient = true
    }

    private func startNotificationTaskIfNeeded() async {
        guard notificationTask == nil else { return }

        let notifications = await client.notifications
        let continuation = eventContinuation

        notificationTask = Task {
            for await notification in notifications {
                if Task.isCancelled { break }
                let event = (try? ACPClientNotificationMapper.map(notification)) ?? .rawNotification(method: notification.method)
                continuation.yield(event)
            }
        }
    }

    private func startDebugTaskIfNeeded() async {
        guard debugTask == nil, let debugMessages = await client.debugMessages else { return }
        let continuation = debugContinuation

        debugTask = Task {
            for await message in debugMessages {
                if Task.isCancelled { break }
                continuation.yield(ACPClientDebugMessage(
                    direction: message.direction == .incoming ? .incoming : .outgoing,
                    timestamp: message.timestamp,
                    method: message.method,
                    payload: message.jsonString
                ))
            }
        }
    }
}