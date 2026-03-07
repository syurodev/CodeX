@testable import ACPClient
import ACPModel
import XCTest

final class ACPClientDelegateBridgeTests: XCTestCase {
    func testCancelsPermissionRequestWhenNoHandlerIsConfigured() async throws {
        let bridge = ACPClientDelegateBridge(permissionHandler: nil)
        let request = RequestPermissionRequest(
            message: "Allow edit?",
            options: [PermissionOption(kind: "allow_once", name: "Allow once", optionId: "allow-once")],
            sessionId: SessionId("session-1"),
            toolCall: PermissionToolCall(toolCallId: "tool-1")
        )

        let response = try await bridge.handlePermissionRequest(request: request)

        XCTAssertEqual(response.outcome.outcome, "cancelled")
        XCTAssertNil(response.outcome.optionId)
    }

    func testForwardsPermissionRequestIntoWrapperHandler() async throws {
        let bridge = ACPClientDelegateBridge(permissionHandler: { request in
            XCTAssertEqual(request.message, "Allow edit?")
            XCTAssertEqual(request.sessionID, "session-1")
            XCTAssertEqual(request.toolCallID, "tool-1")
            XCTAssertEqual(request.options, [ACPClientPermissionOption(id: "allow-once", kind: "allow_once", name: "Allow once")])
            return .select(optionID: "allow-once")
        })
        let request = RequestPermissionRequest(
            message: "Allow edit?",
            options: [PermissionOption(kind: "allow_once", name: "Allow once", optionId: "allow-once")],
            sessionId: SessionId("session-1"),
            toolCall: PermissionToolCall(toolCallId: "tool-1")
        )

        let response = try await bridge.handlePermissionRequest(request: request)

        XCTAssertEqual(response.outcome.outcome, "selected")
        XCTAssertEqual(response.outcome.optionId, "allow-once")
    }
}