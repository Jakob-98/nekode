import XCTest
@testable import Nekode

final class HookEventTests: XCTestCase {

    // MARK: - HookEvent.parse()

    func testParseSessionStart() {
        XCTAssertEqual(HookEvent.parse(hookName: "SessionStart", notificationType: nil), .sessionStart)
    }

    func testParseUserPromptSubmit() {
        XCTAssertEqual(HookEvent.parse(hookName: "UserPromptSubmit", notificationType: nil), .userPromptSubmit)
    }

    func testParsePreToolUse() {
        XCTAssertEqual(HookEvent.parse(hookName: "PreToolUse", notificationType: nil), .preToolUse)
    }

    func testParsePostToolUse() {
        XCTAssertEqual(HookEvent.parse(hookName: "PostToolUse", notificationType: nil), .postToolUse)
    }

    func testParseStop() {
        XCTAssertEqual(HookEvent.parse(hookName: "Stop", notificationType: nil), .stop)
    }

    func testParsePermissionRequest() {
        XCTAssertEqual(HookEvent.parse(hookName: "PermissionRequest", notificationType: nil), .permissionRequest)
    }

    func testParsePreCompact() {
        XCTAssertEqual(HookEvent.parse(hookName: "PreCompact", notificationType: nil), .preCompact)
    }

    func testParseSessionEnd() {
        XCTAssertEqual(HookEvent.parse(hookName: "SessionEnd", notificationType: nil), .sessionEnd)
    }

    func testParseUnknownHookName() {
        XCTAssertEqual(HookEvent.parse(hookName: "FutureHook", notificationType: nil), .unknown)
    }

    func testParseNotificationIdlePrompt() {
        XCTAssertEqual(HookEvent.parse(hookName: "Notification", notificationType: "idle_prompt"), .notificationIdle)
    }

    func testParseNotificationPermissionPrompt() {
        XCTAssertEqual(HookEvent.parse(hookName: "Notification", notificationType: "permission_prompt"), .notificationPermission)
    }

    func testParseNotificationNilType() {
        XCTAssertEqual(HookEvent.parse(hookName: "Notification", notificationType: nil), .notificationOther)
    }

    func testParseNotificationUnknownType() {
        XCTAssertEqual(HookEvent.parse(hookName: "Notification", notificationType: "future_type"), .notificationOther)
    }

    // MARK: - Transition.forEvent() — Stop always idles

    func testStopAlwaysTransitionsToIdle() {
        XCTAssertEqual(Transition.forEvent(.stop), .idle, "Stop should -> idle")
    }

    // MARK: - Transition.forEvent() — SessionStart always idles

    func testSessionStartAlwaysTransitionsToIdle() {
        XCTAssertEqual(Transition.forEvent(.sessionStart), .idle, "SessionStart should -> idle")
    }

    // MARK: - Transition.forEvent() — Working transitions

    func testUserPromptSubmitTransitionsToWorking() {
        XCTAssertEqual(Transition.forEvent(.userPromptSubmit), .working)
    }

    func testPreToolUseTransitionsToWorking() {
        XCTAssertEqual(Transition.forEvent(.preToolUse), .working)
    }

    func testPostToolUseTransitionsToWorking() {
        XCTAssertEqual(Transition.forEvent(.postToolUse), .working)
    }

    // MARK: - Transition.forEvent() — Notification transitions

    func testNotificationIdleTransitionsToWaitingInput() {
        XCTAssertEqual(Transition.forEvent(.notificationIdle), .waitingInput)
    }

    func testNotificationPermissionTransitionsToWaitingPermission() {
        XCTAssertEqual(Transition.forEvent(.notificationPermission), .waitingPermission)
    }

    func testPermissionRequestTransitionsToWaitingPermission() {
        XCTAssertEqual(Transition.forEvent(.permissionRequest), .waitingPermission)
    }

    func testPreCompactTransitionsToCompacting() {
        XCTAssertEqual(Transition.forEvent(.preCompact), .compacting)
    }

    // MARK: - Transition.forEvent() — Preserve status (nil return)

    func testNotificationOtherPreservesStatus() {
        XCTAssertNil(Transition.forEvent(.notificationOther))
    }

    func testSessionEndPreservesStatus() {
        XCTAssertNil(Transition.forEvent(.sessionEnd))
    }

    func testUnknownEventPreservesStatus() {
        XCTAssertNil(Transition.forEvent(.unknown))
    }

    // MARK: - Transition.forEvent() — Source-specific behavior

    func testStopWithCopilotSourceTransitionsToWaitingInput() {
        XCTAssertEqual(Transition.forEvent(.stop, source: .copilot), .waitingInput)
        XCTAssertEqual(Transition.forEvent(.stop, source: .copilotCLI), .waitingInput)
    }

    func testStopWithNonCopilotSourceTransitionsToIdle() {
        XCTAssertEqual(Transition.forEvent(.stop, source: .claude), .idle)
        XCTAssertEqual(Transition.forEvent(.stop, source: .opencode), .idle)
        XCTAssertEqual(Transition.forEvent(.stop), .idle)
    }

    // MARK: - Exhaustive transition test

    func testAllTransitionsExhaustive() {
        let allEvents: [HookEvent] = [
            .sessionStart, .userPromptSubmit, .preToolUse, .postToolUse,
            .stop, .notificationIdle, .notificationPermission, .notificationOther,
            .permissionRequest, .preCompact, .sessionEnd, .unknown
        ]

        // Every event should not crash
        for event in allEvents {
            _ = Transition.forEvent(event)
        }

        // Verify expected transition counts:
        // Events that always transition (non-nil): sessionStart, userPromptSubmit, preToolUse,
        //   postToolUse, stop, notificationIdle, notificationPermission, permissionRequest, preCompact
        // Events that always preserve (nil): notificationOther, sessionEnd, unknown
        XCTAssertNotNil(Transition.forEvent(.sessionStart))
        XCTAssertNotNil(Transition.forEvent(.userPromptSubmit))
        XCTAssertNotNil(Transition.forEvent(.preToolUse))
        XCTAssertNotNil(Transition.forEvent(.postToolUse))
        XCTAssertNotNil(Transition.forEvent(.stop))
        XCTAssertNotNil(Transition.forEvent(.notificationIdle))
        XCTAssertNotNil(Transition.forEvent(.notificationPermission))
        XCTAssertNotNil(Transition.forEvent(.permissionRequest))
        XCTAssertNotNil(Transition.forEvent(.preCompact))
        XCTAssertNil(Transition.forEvent(.notificationOther))
        XCTAssertNil(Transition.forEvent(.sessionEnd))
        XCTAssertNil(Transition.forEvent(.unknown))
    }

    // MARK: - sanitizeSessionId

    func testSanitizeRemovesForwardSlash() {
        XCTAssertEqual(Session.sanitizeSessionId(raw: "foo/bar"), "foobar")
    }

    func testSanitizeRemovesBackslash() {
        XCTAssertEqual(Session.sanitizeSessionId(raw: "foo\\bar"), "foobar")
    }

    func testSanitizeRemovesDoubleDot() {
        XCTAssertEqual(Session.sanitizeSessionId(raw: "../../.bashrc"), "bashrc")
    }

    func testSanitizePathTraversal() {
        XCTAssertEqual(Session.sanitizeSessionId(raw: "../etc/passwd"), "etcpasswd")
    }

    func testSanitizeDoubleDotOnly() {
        XCTAssertEqual(Session.sanitizeSessionId(raw: ".."), "")
    }

    func testSanitizeCapsLength() {
        let long = String(repeating: "a", count: 100)
        XCTAssertEqual(Session.sanitizeSessionId(raw: long).count, 64)
    }

    func testSanitizeNormalIdUnchanged() {
        XCTAssertEqual(Session.sanitizeSessionId(raw: "abc-123-def"), "abc-123-def")
    }

    func testSanitizeUUIDUnchanged() {
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
        XCTAssertEqual(Session.sanitizeSessionId(raw: uuid), uuid)
    }
}
