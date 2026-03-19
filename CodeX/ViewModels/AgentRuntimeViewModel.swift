import ACPClient
import ACPModel
import Foundation

enum AgentMessageRole: String {
    case system
    case user
    case assistant
}

struct AgentMessage: Identifiable, Hashable {
    let id: UUID
    let role: AgentMessageRole
    var content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: AgentMessageRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum AgentActivityKind: String, Hashable {
    case thinking
    case tool
    case plan

    var title: String {
        switch self {
        case .thinking: return "Thinking"
        case .tool: return "Tool"
        case .plan: return "Plan"
        }
    }

    var systemImage: String {
        switch self {
        case .thinking: return "ellipsis.bubble"
        case .tool: return "hammer"
        case .plan: return "list.bullet.rectangle"
        }
    }
}

enum AgentActivityStatus: Hashable {
    case running
    case completed
    case failed
    case info

    var label: String {
        switch self {
        case .running: return "Live"
        case .completed: return "Done"
        case .failed: return "Failed"
        case .info: return "Info"
        }
    }

    var isRunning: Bool {
        self == .running
    }
}

struct AgentActivity: Identifiable, Hashable {
    let id: String
    let kind: AgentActivityKind
    var title: String
    var detail: String?
    var status: AgentActivityStatus
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        kind: AgentActivityKind,
        title: String,
        detail: String? = nil,
        status: AgentActivityStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AgentTranscriptEntry: Identifiable, Hashable {
    case message(AgentMessage)
    case activity(AgentActivity)

    var id: String {
        switch self {
        case let .message(message):
            return "message-\(message.id.uuidString)"
        case let .activity(activity):
            return "activity-\(activity.id)"
        }
    }

    var createdAt: Date {
        switch self {
        case let .message(message):
            return message.createdAt
        case let .activity(activity):
            return activity.createdAt
        }
    }

    var changeToken: String {
        switch self {
        case let .message(message):
            return "message|\(message.id.uuidString)|\(message.role.rawValue)|\(message.content)"
        case let .activity(activity):
            return "activity|\(activity.id)|\(activity.status.label)|\(activity.title)|\(activity.detail ?? "")"
        }
    }

    static func merge(messages: [AgentMessage], activities: [AgentActivity]) -> [AgentTranscriptEntry] {
        let filteredMessages = messages.filter { $0.role != .system }.map(AgentTranscriptEntry.message)
        let activityEntries = activities.map(AgentTranscriptEntry.activity)

        return Array((filteredMessages + activityEntries).enumerated())
            .sorted { lhs, rhs in
                if lhs.element.createdAt != rhs.element.createdAt {
                    return lhs.element.createdAt < rhs.element.createdAt
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

struct AgentTranscriptSection: Identifiable {
    enum Content {
        case message(AgentMessage)
        case activityGroup([AgentActivity])
    }

    let id: String
    let content: Content

    var changeToken: String {
        switch content {
        case let .message(msg):
            return "msg|\(msg.id.uuidString)|\(msg.content)"
        case let .activityGroup(acts):
            return "grp|\(acts.map { "\($0.id):\($0.status.label):\($0.title)" }.joined(separator: "|"))"
        }
    }

    static func sections(from entries: [AgentTranscriptEntry]) -> [AgentTranscriptSection] {
        var result: [AgentTranscriptSection] = []
        var currentActivities: [AgentActivity] = []

        for entry in entries {
            switch entry {
            case let .message(msg):
                if !currentActivities.isEmpty {
                    let groupID = "group-\(currentActivities[0].id)"
                    result.append(.init(id: groupID, content: .activityGroup(currentActivities)))
                    currentActivities = []
                }
                result.append(.init(id: "msg-\(msg.id.uuidString)", content: .message(msg)))
            case let .activity(act):
                currentActivities.append(act)
            }
        }

        if !currentActivities.isEmpty {
            let groupID = "group-\(currentActivities[0].id)"
            result.append(.init(id: groupID, content: .activityGroup(currentActivities)))
        }

        return result
    }
}

protocol AgentRuntimeTransporting: Sendable {
    func launch(_ configuration: ACPClientLaunchConfiguration) async throws
    func initialize(_ options: ACPClientInitializationOptions) async throws -> ACPClientHandshake
    func startSession(_ configuration: ACPClientSessionConfiguration) async throws -> ACPClientSession
    func sendPrompt(_ text: String, sessionID: String) async throws -> ACPClientPromptResult
    func cancelPrompt(sessionID: String) async throws
    func events() async -> AsyncStream<ACPClientEvent>
    func debugMessages() async -> AsyncStream<ACPClientDebugMessage>
    func terminate() async
}

typealias AgentRuntimeTransportFactory = @MainActor @Sendable () -> any AgentRuntimeTransporting

actor LiveAgentRuntimeTransport: AgentRuntimeTransporting {
    private let runtime = ACPClientRuntime()

    func launch(_ configuration: ACPClientLaunchConfiguration) async throws {
        try await runtime.launch(configuration)
    }

    func initialize(_ options: ACPClientInitializationOptions) async throws -> ACPClientHandshake {
        try await runtime.initialize(options)
    }

    func startSession(_ configuration: ACPClientSessionConfiguration) async throws -> ACPClientSession {
        try await runtime.startSession(configuration)
    }

    func sendPrompt(_ text: String, sessionID: String) async throws -> ACPClientPromptResult {
        try await runtime.sendPrompt(text, sessionID: sessionID)
    }

    func cancelPrompt(sessionID: String) async throws {
        try await runtime.cancelPrompt(sessionID: sessionID)
    }

    func events() async -> AsyncStream<ACPClientEvent> {
        await runtime.events()
    }

    func debugMessages() async -> AsyncStream<ACPClientDebugMessage> {
        await runtime.debugMessages()
    }

    func terminate() async {
        await runtime.terminate()
    }
}

private struct AgentRuntimeConnection {
    let transport: any AgentRuntimeTransporting
    let session: ACPClientSession
}

@MainActor
@Observable
final class AgentRuntimeViewModel: Identifiable {
    let id = UUID()
    let provider: AgentProvider
    let workingDirectory: URL?

    var title: String
    var state: AgentRuntimeState
    var messages: [AgentMessage]
    var activities: [AgentActivity]
    var lastError: String?
    var requiresAuthentication = false

    private let transportFactory: AgentRuntimeTransportFactory
    private var transport: (any AgentRuntimeTransporting)?
    private var session: ACPClientSession?
    private var startupTask: Task<Void, Error>?
    private var eventTask: Task<Void, Never>?
    private var debugTask: Task<Void, Never>?
    private var promptTask: Task<Void, Never>?
    private var needsNewAssistantMessage = false

    init(
        provider: AgentProvider,
        title: String,
        workingDirectory: URL?,
        transportFactory: @escaping AgentRuntimeTransportFactory = { LiveAgentRuntimeTransport() }
    ) {
        self.provider = provider
        self.title = title
        self.workingDirectory = workingDirectory
        self.transportFactory = transportFactory
        self.state = .starting
        self.messages = [
            AgentMessage(
                role: .system,
                content: "Starting \(provider.displayName) ACP runtime…"
            )
        ]
        self.activities = []

        Task { [weak self] in
            await self?.bootstrapRuntimeIfNeeded()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            startupTask?.cancel()
            eventTask?.cancel()
            debugTask?.cancel()
            promptTask?.cancel()
            requestTransportTermination(transport)
        }
    }

    var workingDirectoryName: String {
        workingDirectory?.lastPathComponent ?? "No workspace"
    }

    var footerText: String {
        if let lastError, !lastError.isEmpty {
            return lastError
        }

        if state == .busy, let liveActivitySummary {
            return liveActivitySummary
        }

        switch state {
        case .starting:
            return "Launching \(provider.displayName) via ACP…"
        case .ready:
            return "Connected to \(provider.displayName) over ACP."
        case .busy:
            return "\(provider.displayName) is processing the current prompt…"
        case .stopped:
            return "Runtime stopped."
        case .error:
            return "Runtime failed. Check the launch configuration."
        }
    }

    var visibleActivities: [AgentActivity] {
        activities.sorted {
            if $0.status.isRunning != $1.status.isRunning {
                return $0.status.isRunning && !$1.status.isRunning
            }

            return $0.updatedAt > $1.updatedAt
        }
    }

    var transcriptEntries: [AgentTranscriptEntry] {
        AgentTranscriptEntry.merge(messages: messages, activities: activities)
    }

    var transcriptSections: [AgentTranscriptSection] {
        AgentTranscriptSection.sections(from: transcriptEntries)
    }

    var liveActivitySummary: String? {
        if let tool = visibleActivities.first(where: { $0.kind == .tool && $0.status == .running }) {
            return "Running tool: \(tool.title)"
        }

        if let thinking = visibleActivities.first(where: { $0.kind == .thinking && $0.status == .running }) {
            if let detail = thinking.detail, !detail.isEmpty {
                return "Thinking: \(compactPreview(detail, limit: 90))"
            }
            return "Thinking…"
        }

        if let latest = visibleActivities.first {
            return "Latest activity: \(latest.title)"
        }

        return nil
    }

    func stop() {
        let previousState = state
        shutdownRuntime()
        state = .stopped

        if previousState != .stopped {
            messages.append(AgentMessage(role: .system, content: "Runtime stopped."))
        }
    }

    func stopResponding() {
        guard state == .busy, let transport, let session else { return }

        Task { [transport, sessionID = session.id, weak self] in
            do {
                try await transport.cancelPrompt(sessionID: sessionID)
            } catch {
                await MainActor.run {
                    self?.applyError(error, prefix: "Failed to stop response")
                }
            }
        }
    }

    func restart() {
        shutdownRuntime()
        resetActivities()
        lastError = nil
        state = .starting
        messages.append(AgentMessage(role: .system, content: "Restart requested for \(title)."))

        Task { [weak self] in
            await self?.bootstrapRuntimeIfNeeded(forceRestart: true)
        }
    }

    func submitPrompt(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(AgentMessage(role: .user, content: trimmed))

        guard state != .stopped else {
            messages.append(AgentMessage(role: .assistant, content: "This runtime is stopped. Start a new runtime before sending a prompt."))
            return
        }

        resetActivities()
        needsNewAssistantMessage = false

        promptTask?.cancel()
        promptTask = Task { [weak self] in
            await self?.runPrompt(trimmed)
        }
    }

    private func bootstrapRuntimeIfNeeded(forceRestart: Bool = false) async {
        do {
            logDebug("Bootstrap requested | provider=\(provider.displayName) | forceRestart=\(forceRestart)")
            _ = try await ensureConnection(forceRestart: forceRestart)
        } catch is CancellationError {
            logDebug("Bootstrap cancelled | provider=\(provider.displayName)")
            return
        } catch {
            applyError(error, prefix: "Failed to start \(provider.displayName)")
        }
    }

    private func runPrompt(_ text: String) async {
        do {
            let connection = try await ensureConnection()
            state = .busy
            lastError = nil

            logDebug("Sending prompt | sessionID=\(connection.session.id) | characters=\(text.count)")

            let result = try await connection.transport.sendPrompt(text, sessionID: connection.session.id)

            logDebug("Prompt completed | sessionID=\(connection.session.id) | stopReason=\(result.stopReason)")
            finalizeActivitiesAfterPrompt()

            if state != .stopped {
                state = .ready
            }

            if result.stopReason != "end_turn" {
                messages.append(AgentMessage(role: .system, content: "Prompt finished with stop reason: \(result.stopReason)."))
            }
        } catch is CancellationError {
            logDebug("Prompt cancelled")
            return
        } catch {
            applyError(error, prefix: "Failed to send prompt")
        }
    }

    private func ensureConnection(forceRestart: Bool = false) async throws -> AgentRuntimeConnection {
        if forceRestart {
            shutdownRuntime()
            lastError = nil
        }

        if let transport, let session {
            return AgentRuntimeConnection(transport: transport, session: session)
        }

        if let startupTask {
            try await startupTask.value
            guard let transport, let session else {
                throw AgentRuntimeError.missingSession
            }
            return AgentRuntimeConnection(transport: transport, session: session)
        }

        guard let launchConfiguration = provider.defaultACPLaunchConfiguration(workingDirectory: workingDirectory) else {
            throw AgentRuntimeError.unsupportedProvider(provider.displayName)
        }

        let transport = transportFactory()
        self.transport = transport
        state = .starting

        let startupTask = Task<Void, Error> { [weak self] in
            guard let self else { return }

            let debugStream = await transport.debugMessages()
            self.startDebugLoop(with: debugStream)

            self.logDebug("Launching runtime | \(self.launchConfigurationSummary(launchConfiguration))")

            try await transport.launch(launchConfiguration)
            self.logDebug("Launch completed")

            let initializationOptions = self.provider.defaultACPInitializationOptions
            self.logDebug("Initializing ACP | \(self.initializationSummary(initializationOptions))")

            let handshake = try await transport.initialize(initializationOptions)
            self.logDebug("Initialize completed | \(self.handshakeSummary(handshake))")

            let workspacePath = self.workingDirectory?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
            self.logDebug("Creating session | cwd=\(workspacePath)")
            let session = try await transport.startSession(.init(workingDirectory: workspacePath))
            self.logDebug("Session created | id=\(session.id) | mode=\(session.currentModeID ?? "nil") | model=\(session.currentModelID ?? "nil")")
            let eventStream = await transport.events()

            self.session = session
            self.startEventLoop(with: eventStream, sessionID: session.id)

            if self.state != .stopped {
                self.state = .ready
                self.messages.append(AgentMessage(
                    role: .system,
                    content: self.connectionReadyMessage(from: handshake)
                ))
            }
        }

        self.startupTask = startupTask

        do {
            try await startupTask.value
            self.startupTask = nil

            guard let session else {
                throw AgentRuntimeError.missingSession
            }

            return AgentRuntimeConnection(transport: transport, session: session)
        } catch {
            self.startupTask = nil
            self.transport = nil
            self.session = nil
            self.debugTask?.cancel()
            self.debugTask = nil
            await transport.terminate()
            throw error
        }
    }

    private func startEventLoop(with eventStream: AsyncStream<ACPClientEvent>, sessionID: String) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }

            self.logDebug("Event loop started | sessionID=\(sessionID)")

            for await event in eventStream {
                if Task.isCancelled { break }
                self.handle(event, expectedSessionID: sessionID)
            }

            self.logDebug("Event loop finished | sessionID=\(sessionID)")
        }
    }

    private func startDebugLoop(with debugStream: AsyncStream<ACPClientDebugMessage>) {
        debugTask?.cancel()
        debugTask = Task { [weak self] in
            guard let self else { return }

            self.logDebug("Debug stream started")

            for await message in debugStream {
                if Task.isCancelled { break }
                self.logDebug(self.debugMessageSummary(message))
            }

            self.logDebug("Debug stream finished")
        }
    }

    private func handle(_ event: ACPClientEvent, expectedSessionID: String) {
        guard case .session(let sessionEvent) = event else {
            if case .rawNotification(let method) = event {
                logDebug("Notification received | method=\(method)")
            }
            return
        }

        switch sessionEvent {
        case let .textChunk(sessionID, source, text):
            guard sessionID == expectedSessionID else { return }
            logDebug("Text chunk | sessionID=\(sessionID) | source=\(source.rawValue) | characters=\(text.count)")
            handleTextChunk(text, source: source)
        case let .nonTextChunk(sessionID, source, kind):
            guard sessionID == expectedSessionID else { return }
            logDebug("Non-text chunk | sessionID=\(sessionID) | source=\(source.rawValue) | kind=\(kind)")
            upsertActivity(
                id: "non-text-\(kind)",
                kind: .tool,
                title: "Received \(humanize(kind) ?? kind) chunk",
                detail: "Source: \(humanize(source.rawValue) ?? source.rawValue)",
                status: .info
            )
        case let .toolCall(call):
            guard call.sessionID == expectedSessionID else { return }
            logDebug("Tool call started | \(toolCallSummary(call))")
            upsertToolActivity(call)
        case let .toolCallUpdate(call):
            guard call.sessionID == expectedSessionID else { return }
            logDebug("Tool call update | \(toolCallSummary(call))")
            upsertToolActivity(call)
        case let .plan(sessionID, entries):
            guard sessionID == expectedSessionID, !entries.isEmpty else { return }
            logDebug("Plan update | sessionID=\(sessionID) | entries=\(entries.count)")
            upsertActivity(
                id: "plan",
                kind: .plan,
                title: "Plan updated",
                detail: entries.joined(separator: " • "),
                status: .info
            )
        case let .availableCommands(sessionID, names):
            guard sessionID == expectedSessionID, !names.isEmpty else { return }
            logDebug("Available commands update | sessionID=\(sessionID) | count=\(names.count)")
        case let .currentMode(sessionID, modeID):
            guard sessionID == expectedSessionID else { return }
            logDebug("Current mode update | sessionID=\(sessionID) | mode=\(modeID)")
        case let .configOptions(sessionID, names):
            guard sessionID == expectedSessionID, !names.isEmpty else { return }
            logDebug("Config options update | sessionID=\(sessionID) | count=\(names.count)")
        }
    }

    private func handleTextChunk(_ text: String, source: ACPClientMessageSource) {
        guard !text.isEmpty else { return }

        switch source {
        case .agent:
            markThinkingActivityCompletedIfNeeded()
            appendChunk(text, role: .assistant)
        case .thought:
            appendThinkingActivity(text)
        case .user:
            break
        }
    }

    private func appendChunk(_ text: String, role: AgentMessageRole) {
        guard !text.isEmpty else { return }

        if !needsNewAssistantMessage,
           let lastIndex = messages.indices.last,
           messages[lastIndex].role == role {
            messages[lastIndex].content += text
            return
        }

        needsNewAssistantMessage = false
        messages.append(AgentMessage(role: role, content: text))
    }

    private func connectionReadyMessage(from handshake: ACPClientHandshake) -> String {
        let runtimeName = handshake.agentTitle ?? handshake.agentName ?? provider.displayName
        if let version = handshake.agentVersion, !version.isEmpty {
            return "Connected to \(runtimeName) (\(version)) via ACP."
        }
        return "Connected to \(runtimeName) via ACP."
    }

    private func toolCallSummary(_ call: ACPClientToolCallEvent) -> String {
        let title = call.title ?? call.kind ?? call.toolCallID
        if let status = call.status, !status.isEmpty {
            return "\(title) [\(status)]"
        }
        return title
    }

    private func appendThinkingActivity(_ text: String) {
        let thoughtID = "thinking"
        let existingDetail = activities.first(where: { $0.id == thoughtID })?.detail ?? ""
        let combinedDetail = existingDetail + text

        upsertActivity(
            id: thoughtID,
            kind: .thinking,
            title: AgentActivityKind.thinking.title,
            detail: combinedDetail,
            status: .running
        )
    }

    private func upsertToolActivity(_ call: ACPClientToolCallEvent) {
        needsNewAssistantMessage = true
        upsertActivity(
            id: "tool-\(call.toolCallID)",
            kind: .tool,
            title: call.title ?? humanize(call.kind) ?? shortToolFallback(call.toolCallID),
            detail: toolActivityDetail(for: call),
            status: activityStatus(for: call.status)
        )
    }

    private func upsertActivity(
        id: String,
        kind: AgentActivityKind,
        title: String,
        detail: String?,
        status: AgentActivityStatus
    ) {
        let timestamp = Date()

        if let index = activities.firstIndex(where: { $0.id == id }) {
            activities[index].title = title
            activities[index].detail = detail
            activities[index].status = status
            activities[index].updatedAt = timestamp
            return
        }

        activities.append(
            AgentActivity(
                id: id,
                kind: kind,
                title: title,
                detail: detail,
                status: status,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }

    private func markThinkingActivityCompletedIfNeeded() {
        guard let index = activities.firstIndex(where: { $0.id == "thinking" }) else { return }
        activities[index].status = .completed
        activities[index].updatedAt = Date()
    }

    private func finalizeActivitiesAfterPrompt() {
        for index in activities.indices {
            if activities[index].status == .running {
                activities[index].status = .completed
                activities[index].updatedAt = Date()
            }
        }
    }

    private func resetActivities() {
        activities.removeAll()
    }

    private func activityStatus(for rawStatus: String?) -> AgentActivityStatus {
        guard let rawStatus = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines), !rawStatus.isEmpty else {
            return .running
        }

        switch rawStatus.lowercased() {
        case "pending", "in_progress", "running":
            return .running
        case "completed", "done", "success", "succeeded":
            return .completed
        case "failed", "error":
            return .failed
        default:
            return .info
        }
    }

    private func toolActivityDetail(for call: ACPClientToolCallEvent) -> String? {
        var parts: [String] = []

        if let kind = humanize(call.kind), kind != (call.title ?? "") {
            parts.append(kind)
        }

        if let status = humanize(call.status) {
            parts.append(status)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func humanize(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let cleaned = value.replacingOccurrences(of: "_", with: " ")
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private func shortToolFallback(_ toolCallID: String) -> String {
        "Tool \(toolCallID.prefix(6))"
    }

    private func compactPreview(_ text: String, limit: Int) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compact.count > limit else { return compact }
        let endIndex = compact.index(compact.startIndex, offsetBy: limit)
        return String(compact[..<endIndex]) + "…"
    }

    func retryAfterAuthentication() {
        requiresAuthentication = false
        lastError = nil
        Task { await bootstrapRuntimeIfNeeded(forceRestart: true) }
    }

    private func applyError(_ error: Error, prefix: String) {
        markRunningActivitiesFailed()
        logDebug("\(prefix) | \(ACPClientErrorFormatter.debugDescription(for: error))")

        // Detect "Authentication required" từ ACP error code -32000
        if isAuthenticationError(error) {
            requiresAuthentication = true
            state = .error
            return
        }

        let message = "\(prefix): \(error.localizedDescription)"
        lastError = message
        state = .error
        messages.append(AgentMessage(role: .system, content: message))
    }

    private func isAuthenticationError(_ error: Error) -> Bool {
        if let clientError = error as? ClientError,
           case .agentError(let jsonError) = clientError,
           jsonError.code == -32000 { return true }
        // Fallback: check localizedDescription
        return error.localizedDescription.lowercased().contains("authentication required")
    }

    private func markRunningActivitiesFailed() {
        for index in activities.indices where activities[index].status == .running {
            activities[index].status = .failed
            activities[index].updatedAt = Date()
        }
    }

    private func shutdownRuntime() {
        let transport = transport
        startupTask?.cancel()
        eventTask?.cancel()
        debugTask?.cancel()
        promptTask?.cancel()
        startupTask = nil
        eventTask = nil
        debugTask = nil
        promptTask = nil
        self.transport = nil
        session = nil
        resetActivities()

        logDebug("Shutting down runtime | provider=\(provider.displayName)")
        requestTransportTermination(transport)
    }

    private func requestTransportTermination(_ transport: (any AgentRuntimeTransporting)?) {
        guard let transport else { return }

        Task.detached(priority: .userInitiated) {
            await transport.terminate()
        }
    }

    private func launchConfigurationSummary(_ configuration: ACPClientLaunchConfiguration) -> String {
        "executable=\(configuration.executablePath) | args=\(configuration.arguments) | cwd=\(configuration.workingDirectory ?? "nil")"
    }

    private func initializationSummary(_ options: ACPClientInitializationOptions) -> String {
        "protocol=\(options.protocolVersion) | client=\(options.clientInfo.name) | version=\(options.clientInfo.version ?? "nil") | debug=\(options.enableDebugMessages) | fsRead=\(options.capabilities.canReadTextFiles) | fsWrite=\(options.capabilities.canWriteTextFiles) | terminal=\(options.capabilities.supportsTerminal)"
    }

    private func handshakeSummary(_ handshake: ACPClientHandshake) -> String {
        "protocol=\(handshake.protocolVersion) | agent=\(handshake.agentTitle ?? handshake.agentName ?? provider.displayName) | version=\(handshake.agentVersion ?? "nil") | authMethods=\(handshake.authMethodNames)"
    }

    private func debugMessageSummary(_ message: ACPClientDebugMessage) -> String {
        var components = [
            "ACP \(message.direction.rawValue)",
            "method=\(message.method ?? "unknown")"
        ]

        if let payload = truncatedPayload(message.payload) {
            components.append("payload=\(payload)")
        }

        return components.joined(separator: " | ")
    }

    private func truncatedPayload(_ payload: String?, limit: Int = 600) -> String? {
        guard let payload, !payload.isEmpty else { return nil }
        if payload.count <= limit { return payload }
        let endIndex = payload.index(payload.startIndex, offsetBy: limit)
        return String(payload[..<endIndex]) + "…"
    }

    private func logDebug(_ message: String) {
        print("🤖 [AgentRuntime][\(provider.id.rawValue)] \(message)")
    }
}

private enum AgentRuntimeError: LocalizedError {
    case unsupportedProvider(String)
    case missingSession

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let providerName):
            return "No ACP launch configuration is available for \(providerName)."
        case .missingSession:
            return "ACP session was not created successfully."
        }
    }
}