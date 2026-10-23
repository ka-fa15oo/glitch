import Foundation

/// One Claude Code or Codex hook payload (both send the same fields), reduced to what the sentinel cares about.
struct SentinelEvent: Equatable, Sendable {
    /// `toolDone` = a tool call finished; it only answers a wait if it is the tool that was waiting.
    enum Kind: Equatable, Sendable { case permission, question, finished, error, userActed, toolDone, ended }

    let sessionID: String
    let cwd: String
    let kind: Kind
    let date: Date
    var tool: String?
    var toolUseID: String?
    /// Desktop sessions send their title with each prompt (`session_title`).
    var title: String?

    /// nil = ignore (unknown event, ordinary tool error, malformed payload).
    static func parse(_ data: Data, date: Date) -> SentinelEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = object["hook_event_name"] as? String,
              let id = object["session_id"] as? String, !id.isEmpty else { return nil }
        let tool = object["tool_name"] as? String
        guard let kind = kind(event: event, tool: tool, notification: object["notification_type"] as? String) else { return nil }
        return SentinelEvent(sessionID: id, cwd: object["cwd"] as? String ?? "", kind: kind, date: date,
                             tool: tool, toolUseID: object["tool_use_id"] as? String,
                             title: object["session_title"] as? String)
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
        case "UserPromptSubmit", "PermissionDenied", "Interrupt":
            return .userActed                                  // the user wrote again, denied or stopped (Codex)
        case "PostToolUse", "PostToolUseFailure":
            return .toolDone                                   // approved tool ran (even if it failed) / question answered
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
