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
                status: update.status.rawValue
            ))
        case .toolCallUpdate(let details):
            return .toolCallUpdate(.init(
                sessionID: sessionID,
                toolCallID: details.toolCallId,
                title: details.title,
                kind: details.kind?.rawValue,
                status: details.status?.rawValue
            ))
        case .plan(let plan):
            return .plan(sessionID: sessionID, entries: plan.entries.map(\.content))
        case .availableCommandsUpdate(let commands):
            return .availableCommands(sessionID: sessionID, names: commands.map(\.name))
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

    private static func decode<T: Decodable>(_ type: T.Type, from value: AnyCodable) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}