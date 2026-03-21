import ACP
import ACPModel

final class ACPClientDelegateBridge: ClientDelegate, @unchecked Sendable {
    private let fileSystemDelegate: FileSystemDelegate
    private let terminalDelegate: TerminalDelegate
    private let permissionHandler: ACPClientPermissionHandler?

    init(
        fileSystemDelegate: FileSystemDelegate = FileSystemDelegate(),
        terminalDelegate: TerminalDelegate = TerminalDelegate(),
        permissionHandler: ACPClientPermissionHandler?
    ) {
        self.fileSystemDelegate = fileSystemDelegate
        self.terminalDelegate = terminalDelegate
        self.permissionHandler = permissionHandler
    }

    func handleFileReadRequest(_ path: String, sessionId: String, line: Int?, limit: Int?) async throws -> ReadTextFileResponse {
        try await fileSystemDelegate.handleFileReadRequest(path, sessionId: sessionId, line: line, limit: limit)
    }

    func handleFileWriteRequest(_ path: String, content: String, sessionId: String) async throws -> WriteTextFileResponse {
        try await fileSystemDelegate.handleFileWriteRequest(path, content: content, sessionId: sessionId)
    }

    func handleTerminalCreate(
        command: String,
        sessionId: String,
        args: [String]?,
        cwd: String?,
        env: [EnvVariable]?,
        outputByteLimit: Int?
    ) async throws -> CreateTerminalResponse {
        try await terminalDelegate.handleTerminalCreate(
            command: command,
            sessionId: sessionId,
            args: args,
            cwd: cwd,
            env: env,
            outputByteLimit: outputByteLimit
        )
    }

    func handleTerminalOutput(terminalId: TerminalId, sessionId: String) async throws -> TerminalOutputResponse {
        try await terminalDelegate.handleTerminalOutput(terminalId: terminalId, sessionId: sessionId)
    }

    func handleTerminalWaitForExit(terminalId: TerminalId, sessionId: String) async throws -> WaitForExitResponse {
        try await terminalDelegate.handleTerminalWaitForExit(terminalId: terminalId, sessionId: sessionId)
    }

    func handleTerminalKill(terminalId: TerminalId, sessionId: String) async throws -> KillTerminalResponse {
        try await terminalDelegate.handleTerminalKill(terminalId: terminalId, sessionId: sessionId)
    }

    func handleTerminalRelease(terminalId: TerminalId, sessionId: String) async throws -> ReleaseTerminalResponse {
        try await terminalDelegate.handleTerminalRelease(terminalId: terminalId, sessionId: sessionId)
    }

    func handlePermissionRequest(request: RequestPermissionRequest) async throws -> RequestPermissionResponse {
        guard let permissionHandler else {
            return RequestPermissionResponse(outcome: PermissionOutcome(cancelled: true))
        }

        let bridgedRequest = ACPClientPermissionRequest(
            message: request.message,
            options: request.options?.map { ACPClientPermissionOption(id: $0.optionId, kind: $0.kind, name: $0.name) } ?? [],
            sessionID: request.sessionId?.value,
            toolCallID: request.toolCall?.toolCallId,
            toolCallTitle: request.toolCall?.title
        )

        switch try await permissionHandler(bridgedRequest) {
        case .select(let optionID):
            return RequestPermissionResponse(outcome: PermissionOutcome(optionId: optionID))
        case .cancel:
            return RequestPermissionResponse(outcome: PermissionOutcome(cancelled: true))
        }
    }
}