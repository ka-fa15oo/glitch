import Foundation

/// One Claude Code hook payload, reduced to what the sentinel cares about.
struct SentinelEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case permission, question, finished, error, userActed, ended }

    let sessionID: String
    let cwd: String
    let kind: Kind
    let date: Date

    /// nil = ignore (unknown event, ordinary tool error, malformed payload).
    static func parse(_ data: Data, date: Date) -> SentinelEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = object["hook_event_name"] as? String,
              let id = object["session_id"] as? String, !id.isEmpty else { return nil }
        let tool = object["tool_name"] as? String
        guard let kind = kind(event: event, tool: tool, notification: object["notification_type"] as? String) else { return nil }
        return SentinelEvent(sessionID: id, cwd: object["cwd"] as? String ?? "", kind: kind, date: date)
    }

    /// Hook event → sentinel state. See "Bulgular (Task 0)" in the spec for where this mapping comes from.
    private static func kind(event: String, tool: String?, notification: String?) -> Kind? {
        switch event {
        case "PermissionRequest":
            return tool == "AskUserQuestion" ? .question : .permission
        case "PreToolUse":
            return tool == "AskUserQuestion" ? .question : nil   // Claude asked the user an explicit question
        case "Notification":
            switch notification {
            case "permission_prompt": return .permission
            case "elicitation_dialog": return .question
            default: return nil                                // idle reminders etc.
            }
        case "UserPromptSubmit", "PostToolUse", "PermissionDenied":
            return .userActed                                  // the user answered, approved, denied or wrote again
        case "PostToolUseFailure":
            return nil                                         // an ordinary tool error is not a session error
        case "Stop":
            return .finished
        case "StopFailure":
            return .error                                      // the turn died (API error); tool failures never get here
        case "SessionEnd":
            return .ended
        default:
            return nil
        }
    }
}
