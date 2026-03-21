import ACPModel
import Foundation

enum ACPClientNotificationMapper {
    static func map(_ notification: JSONRPCNotification) throws -> ACPClientEvent {
        guard notification.method == "session/update", let params = notification.params else {
            return .rawNotification(method: notification.method)
        }

        let updateNotification: SessionUpdateNotification = try decode(SessionUpdateNotification.self, from: params)
        return .session(map(updateNotification))
    }

    private static func map(_ notification: SessionUpdateNotification) -> ACPClientSessionEvent {
        let sessionID = notification.sessionId.value

        switch notification.update {
        case .userMessageChunk(let block):
            return mapMessageBlock(block, sessionID: sessionID, source: .user)
        case .agentMessageChunk(let block):
            return mapMessageBlock(block, sessionID: sessionID, source: .agent)
        case .agentThoughtChunk(let block):
            return mapMessageBlock(block, sessionID: sessionID, source: .thought)
        case .toolCall(let update):
            return .toolCall(.init(
                sessionID: sessionID,
                toolCallID: update.toolCallId,
                title: update.title,
                kind: update.kind?.rawValue,
                status: update.status.rawValue,
                command: extractCommand(from: update.rawInput),
                output: extractOutput(from: update.rawOutput)
            ))
        case .toolCallUpdate(let details):
            return .toolCallUpdate(.init(
                sessionID: sessionID,
                toolCallID: details.toolCallId,
                title: details.title,
                kind: details.kind?.rawValue,
                status: details.status?.rawValue,
                command: extractCommand(from: details.rawInput),
                output: extractOutput(from: details.rawOutput)
            ))
        case .plan(let plan):
            return .plan(sessionID: sessionID, entries: plan.entries.map(\.content))
        case .availableCommandsUpdate(let commands):
            return .availableCommands(sessionID: sessionID, commands: commands.map {
                ACPClientAvailableCommand(name: $0.name, description: $0.description)
            })
        case .currentModeUpdate(let modeID):
            return .currentMode(sessionID: sessionID, modeID: modeID)
        case .configOptionUpdate(let options):
            return .configOptions(sessionID: sessionID, names: options.map(\.name))
        }
    }

    private static func mapMessageBlock(
        _ block: ContentBlock,
        sessionID: String,
        source: ACPClientMessageSource
    ) -> ACPClientSessionEvent {
        switch block {
        case .text(let text):
            return .textChunk(sessionID: sessionID, source: source, text: text.text)
        case .image:
            return .nonTextChunk(sessionID: sessionID, source: source, kind: "image")
        case .audio:
            return .nonTextChunk(sessionID: sessionID, source: source, kind: "audio")
        case .resourceLink:
            return .nonTextChunk(sessionID: sessionID, source: source, kind: "resource_link")
        case .resource:
            return .nonTextChunk(sessionID: sessionID, source: source, kind: "resource")
        }
    }

    private static func extractCommand(from rawInput: AnyCodable?) -> String? {
        guard let dict = rawInput?.value as? [String: any Sendable] else { return nil }
        if let command = dict["command"] as? String { return command }
        if let path = dict["path"] as? String { return path }
        return nil
    }

    private static func extractOutput(from rawOutput: AnyCodable?) -> String? {
        guard let dict = rawOutput?.value as? [String: any Sendable] else { return nil }
        if let content = dict["content"] as? String, !content.isEmpty { return content }
        return nil
    }

    private static func decode<T: Decodable>(_ type: T.Type, from value: AnyCodable) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}