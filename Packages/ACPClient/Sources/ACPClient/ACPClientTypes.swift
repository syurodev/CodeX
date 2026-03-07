import Foundation

public struct ACPClientLaunchConfiguration: Sendable, Equatable {
    public let executablePath: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let environment: [String: String]?

    public init(
        executablePath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

public struct ACPClientIdentity: Sendable, Equatable {
    public let name: String
    public let title: String?
    public let version: String?

    public init(name: String, title: String? = nil, version: String? = nil) {
        self.name = name
        self.title = title
        self.version = version
    }
}

public struct ACPClientCapabilities: Sendable, Equatable {
    public let canReadTextFiles: Bool
    public let canWriteTextFiles: Bool
    public let supportsTerminal: Bool

    public init(canReadTextFiles: Bool = true, canWriteTextFiles: Bool = true, supportsTerminal: Bool = true) {
        self.canReadTextFiles = canReadTextFiles
        self.canWriteTextFiles = canWriteTextFiles
        self.supportsTerminal = supportsTerminal
    }

    public static let `default` = ACPClientCapabilities()
}

public struct ACPClientInitializationOptions: Sendable, Equatable {
    public let protocolVersion: Int
    public let capabilities: ACPClientCapabilities
    public let clientInfo: ACPClientIdentity
    public let timeout: TimeInterval?
    public let enableDebugMessages: Bool

    public static let defaultClientVersion = "1.0.0"

    public init(
        protocolVersion: Int = 1,
        capabilities: ACPClientCapabilities = .default,
        clientInfo: ACPClientIdentity = .init(
            name: "ACPClient",
            title: "ACP Client",
            version: defaultClientVersion
        ),
        timeout: TimeInterval? = nil,
        enableDebugMessages: Bool = false
    ) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
        self.timeout = timeout
        self.enableDebugMessages = enableDebugMessages
    }
}

public struct ACPClientHandshake: Sendable, Equatable {
    public let protocolVersion: Int
    public let agentName: String?
    public let agentTitle: String?
    public let agentVersion: String?
    public let authMethodNames: [String]

    public init(protocolVersion: Int, agentName: String?, agentTitle: String?, agentVersion: String?, authMethodNames: [String]) {
        self.protocolVersion = protocolVersion
        self.agentName = agentName
        self.agentTitle = agentTitle
        self.agentVersion = agentVersion
        self.authMethodNames = authMethodNames
    }
}

public struct ACPClientSessionConfiguration: Sendable, Equatable {
    public let workingDirectory: String

    public init(workingDirectory: String) {
        self.workingDirectory = workingDirectory
    }
}

public struct ACPClientSession: Sendable, Hashable {
    public let id: String
    public let currentModeID: String?
    public let currentModelID: String?

    public init(id: String, currentModeID: String?, currentModelID: String?) {
        self.id = id
        self.currentModeID = currentModeID
        self.currentModelID = currentModelID
    }
}

public struct ACPClientPromptResult: Sendable, Equatable {
    public let stopReason: String

    public init(stopReason: String) {
        self.stopReason = stopReason
    }
}

public struct ACPClientPermissionOption: Sendable, Equatable {
    public let id: String
    public let kind: String
    public let name: String

    public init(id: String, kind: String, name: String) {
        self.id = id
        self.kind = kind
        self.name = name
    }
}

public struct ACPClientPermissionRequest: Sendable, Equatable {
    public let message: String?
    public let options: [ACPClientPermissionOption]
    public let sessionID: String?
    public let toolCallID: String?

    public init(message: String?, options: [ACPClientPermissionOption], sessionID: String?, toolCallID: String?) {
        self.message = message
        self.options = options
        self.sessionID = sessionID
        self.toolCallID = toolCallID
    }
}

public enum ACPClientPermissionDecision: Sendable, Equatable {
    case select(optionID: String)
    case cancel
}

public typealias ACPClientPermissionHandler = @Sendable (ACPClientPermissionRequest) async throws -> ACPClientPermissionDecision

public enum ACPClientMessageSource: String, Sendable, Equatable {
    case user
    case agent
    case thought
}

public struct ACPClientToolCallEvent: Sendable, Equatable {
    public let sessionID: String
    public let toolCallID: String
    public let title: String?
    public let kind: String?
    public let status: String?

    public init(sessionID: String, toolCallID: String, title: String?, kind: String?, status: String?) {
        self.sessionID = sessionID
        self.toolCallID = toolCallID
        self.title = title
        self.kind = kind
        self.status = status
    }
}

public enum ACPClientSessionEvent: Sendable, Equatable {
    case textChunk(sessionID: String, source: ACPClientMessageSource, text: String)
    case nonTextChunk(sessionID: String, source: ACPClientMessageSource, kind: String)
    case toolCall(ACPClientToolCallEvent)
    case toolCallUpdate(ACPClientToolCallEvent)
    case plan(sessionID: String, entries: [String])
    case availableCommands(sessionID: String, names: [String])
    case currentMode(sessionID: String, modeID: String)
    case configOptions(sessionID: String, names: [String])
}

public enum ACPClientEvent: Sendable, Equatable {
    case session(ACPClientSessionEvent)
    case rawNotification(method: String)
}

public enum ACPClientDebugDirection: String, Sendable, Equatable {
    case incoming
    case outgoing
}

public struct ACPClientDebugMessage: Sendable, Equatable {
    public let direction: ACPClientDebugDirection
    public let timestamp: Date
    public let method: String?
    public let payload: String?

    public init(direction: ACPClientDebugDirection, timestamp: Date, method: String?, payload: String?) {
        self.direction = direction
        self.timestamp = timestamp
        self.method = method
        self.payload = payload
    }
}