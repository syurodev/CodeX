@testable import ACPClient
import ACPModel
import XCTest

final class ACPClientNotificationMapperTests: XCTestCase {
    func testMapsAgentTextChunkIntoWrapperEvent() throws {
        let notification = JSONRPCNotification(
            method: "session/update",
            params: AnyCodable([
                "sessionId": "session-1",
                "update": [
                    "sessionUpdate": "agent_message_chunk",
                    "content": [
                        "type": "text",
                        "text": "hello from agent",
                    ] as [String: any Sendable],
                ] as [String: any Sendable],
            ] as [String: any Sendable])
        )

        let event = try ACPClientNotificationMapper.map(notification)

        XCTAssertEqual(
            event,
            .session(.textChunk(sessionID: "session-1", source: .agent, text: "hello from agent"))
        )
    }

    func testMapsToolCallUpdateIntoWrapperEvent() throws {
        let notification = JSONRPCNotification(
            method: "session/update",
            params: AnyCodable([
                "sessionId": "session-2",
                "update": [
                    "sessionUpdate": "tool_call_update",
                    "toolCallId": "tool-1",
                    "status": "in_progress",
                    "kind": "execute",
                    "title": "Run tests",
                ] as [String: any Sendable],
            ] as [String: any Sendable])
        )

        let event = try ACPClientNotificationMapper.map(notification)

        XCTAssertEqual(
            event,
            .session(.toolCallUpdate(.init(
                sessionID: "session-2",
                toolCallID: "tool-1",
                title: "Run tests",
                kind: "execute",
                status: "in_progress"
            )))
        )
    }

    func testKeepsUnknownNotificationsAsRawEvents() throws {
        let notification = JSONRPCNotification(method: "agent/auth_required", params: nil)

        let event = try ACPClientNotificationMapper.map(notification)

        XCTAssertEqual(event, .rawNotification(method: "agent/auth_required"))
    }
}