import Foundation

enum HookEvent: Equatable {
    case sessionStart
    case userPromptSubmit
    case preToolUse
    case postToolUse
    case stop
    case notificationIdle
    case notificationPermission
    case notificationOther
    case permissionRequest
    case preCompact
    case sessionEnd
    case unknown

    static func parse(hookName: String, notificationType: String?) -> HookEvent {
        switch hookName {
        case "SessionStart": return .sessionStart
        case "UserPromptSubmit": return .userPromptSubmit
        case "PreToolUse": return .preToolUse
        case "PostToolUse": return .postToolUse
        case "Stop": return .stop
        case "Notification":
            switch notificationType {
            case "idle_prompt": return .notificationIdle
            case "permission_prompt": return .notificationPermission
            default: return .notificationOther
            }
        case "PermissionRequest": return .permissionRequest
        case "PreCompact": return .preCompact
        case "SessionEnd": return .sessionEnd
        default: return .unknown
        }
    }
}

enum Transition {
    /// Returns nil to mean "preserve current status".
    /// The `source` parameter allows source-specific behavior (e.g. Copilot's Stop means waiting for input).
    static func forEvent(_ event: HookEvent, source: SessionSource? = nil) -> SessionStatus? {
        switch event {
        case .sessionStart: return .idle
        case .stop:
            // VS Code Copilot and Copilot CLI don't send Notification hooks — Stop
            // means the agent finished and is waiting for the user's next prompt
            // (= waitingInput). For Claude Code (nil source), Stop means the user
            // explicitly stopped, and a separate Notification(idle_prompt) event
            // signals waiting for input.
            if SessionSource.resolve(source).isCopilotFamily { return .waitingInput }
            return .idle
        case .userPromptSubmit, .preToolUse, .postToolUse: return .working
        case .notificationIdle: return .waitingInput
        case .notificationPermission, .permissionRequest: return .waitingPermission
        case .preCompact: return .compacting
        case .notificationOther, .sessionEnd, .unknown: return nil
        }
    }
}
