import Foundation
import Testing

struct SentinelEventTests {
    let date = Date(timeIntervalSince1970: 100)

    private func parsed(_ name: String) -> SentinelEvent? { SentinelEvent.parse(Fixture.data(name), date: date) }

    @Test func parsesPermission() {
        let e = parsed("permission")
        #expect(e?.kind == .permission)
        #expect(e?.sessionID == "s-perm")
        #expect(e?.cwd == "/Users/x/PET")
        #expect(e?.date == date)
    }

    @Test func parsesQuestion() { #expect(parsed("question")?.kind == .question) }
    @Test func parsesFinished() {
        #expect(parsed("finished")?.kind == .finished)
        #expect(parsed("finished")?.cwd == "/Users/x/Obsidian Vault")
    }
    @Test func parsesError() { #expect(parsed("error")?.kind == .error) }
    @Test func parsesUserActed() { #expect(parsed("userActed")?.kind == .userActed) }
    @Test func parsesEnded() { #expect(parsed("ended")?.kind == .ended) }

    /// An approved command that fails still ends the wait; it is not a session error.
    @Test func toolFailureEndsTheWait() {
        let e = parsed("toolFailure")
        #expect(e?.kind == .toolDone)
        #expect(e?.toolUseID == "toolu_01MzM8qyVGkkL3qzZkGMHtQa")
    }
    @Test func ignoresIdlePrompt() { #expect(parsed("idlePrompt") == nil) }   // Stop already says "finished"

    @Test func toolDoneCarriesToolAndID() {
        let data = Data(#"{"session_id":"a","cwd":"/p","hook_event_name":"PostToolUse","tool_name":"Bash","tool_use_id":"t1"}"#.utf8)
        let e = SentinelEvent.parse(data, date: date)
        #expect(e?.kind == .toolDone)
        #expect(e?.tool == "Bash")
        #expect(e?.toolUseID == "t1")
    }

    @Test func realToolDoneIsToolDone() {
        let e = parsed("toolDone")
        #expect(e?.kind == .toolDone)
        #expect(e?.tool == "Bash")
        #expect(e?.toolUseID != nil)
    }

    @Test func ignoresSessionStart() { #expect(parsed("sessionStart") == nil) }

    @Test func desktopPromptCarriesTitle() { #expect(parsed("userActed")?.title == "Main") }

    /// Codex sends the same fields; its PermissionRequest has no tool_use_id, so the wait is matched by tool name.
    @Test func parsesCodexEvents() {
        let interrupt = Data(#"{"hook_event_name":"Interrupt","session_id":"c1","cwd":"/p","turn_id":"t"}"#.utf8)
        #expect(SentinelEvent.parse(interrupt, date: date)?.kind == .userActed)
        let ask = Data(#"{"hook_event_name":"PermissionRequest","session_id":"c1","cwd":"/p","tool_name":"Bash"}"#.utf8)
        #expect(SentinelEvent.parse(ask, date: date)?.kind == .permission)
    }

    @Test func ignoresUnknownEvent() { #expect(parsed("unknown") == nil) }
    @Test func ignoresMalformedJSON() { #expect(SentinelEvent.parse(Data("{\"hook_event".utf8), date: date) == nil) }
    @Test func ignoresMissingSessionID() {
        #expect(SentinelEvent.parse(Data(#"{"hook_event_name":"Stop","cwd":"/p"}"#.utf8), date: date) == nil)
    }
    @Test func ignoresOtherToolsBeforeUse() {
        let data = Data(#"{"session_id":"a","cwd":"/p","hook_event_name":"PreToolUse","tool_name":"Bash"}"#.utf8)
        #expect(SentinelEvent.parse(data, date: date) == nil)
    }
}
