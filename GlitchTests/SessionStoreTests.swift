import Foundation
import Testing

@MainActor
struct SessionStoreTests {
    let store = SessionStore()
    private func e(_ id: String, _ kind: SentinelEvent.Kind, cwd: String = "/p", at t: TimeInterval = 0) -> SentinelEvent {
        Fixture.event(id, kind, cwd: cwd, at: t)
    }

    @Test func permissionBeatsQuestionBeatsFinished() {
        store.apply(e("A", .finished, at: 0))
        store.apply(e("B", .question, at: 1))
        store.apply(e("C", .permission, at: 2))
        #expect(store.visible.map(\.id) == ["C", "B", "A"])
        #expect(store.redSparks == 2)
        #expect(store.goldSparks == 1)
        #expect(store.mostUrgent?.id == "C")
    }

    @Test func samePriorityOldestFirst() {
        store.apply(e("new", .permission, at: 5))
        store.apply(e("old", .permission, at: 1))
        #expect(store.visible.map(\.id) == ["old", "new"])
    }

    @Test func userActedClearsSpark() {
        store.apply(e("A", .permission))
        store.apply(e("A", .userActed, at: 1))
        #expect(store.visible.isEmpty)
    }

    private func tool(_ id: String, _ kind: SentinelEvent.Kind, _ name: String?, _ useID: String? = nil, at t: TimeInterval = 0) -> SentinelEvent {
        var event = Fixture.event(id, kind, at: t)
        event.tool = name
        event.toolUseID = useID
        return event
    }

    @Test func permissionSurvivesOtherToolCompletion() {
        store.apply(tool("A", .permission, "Bash", "t1"))
        store.apply(tool("A", .toolDone, "Read", "t2", at: 1))
        #expect(store.visible.map(\.state) == [.permission])
    }

    @Test func permissionClearedBySameToolCompletion() {
        store.apply(tool("A", .permission, "Bash", "t1"))
        store.apply(tool("A", .toolDone, "Bash", "t1", at: 1))
        #expect(store.visible.isEmpty)
    }

    @Test func permissionWithoutUseIDMatchesByToolName() {
        store.apply(tool("A", .permission, "Bash"))
        store.apply(tool("A", .toolDone, "Read", "t2", at: 1))
        #expect(store.visible.count == 1)
        store.apply(tool("A", .toolDone, "Bash", "t3", at: 2))
        #expect(store.visible.isEmpty)
    }

    @Test func questionClearedOnlyByItsAnswer() {
        store.apply(tool("A", .question, "AskUserQuestion", "q1"))
        store.apply(tool("A", .toolDone, "Bash", "t2", at: 1))
        #expect(store.visible.count == 1)
        store.apply(tool("A", .toolDone, "AskUserQuestion", "q1", at: 2))
        #expect(store.visible.isEmpty)
    }

    @Test func markOpenedClearsGold() {
        store.apply(e("A", .finished))
        store.markOpened("A")
        #expect(store.visible.isEmpty)
    }

    @Test func markOpenedKeepsPermission() {
        store.apply(e("A", .permission))
        store.markOpened("A")
        #expect(store.visible.count == 1)
    }

    @Test func endedRemovesSession() {
        store.apply(e("A", .question))
        store.apply(e("A", .ended, at: 1))
        #expect(store.visible.isEmpty)
    }

    @Test func errorHasNoSparkButIsListed() {
        store.apply(e("A", .error))
        #expect(store.visible.count == 1)
        #expect(store.redSparks == 0)
        #expect(store.goldSparks == 0)
    }

    @Test func deadSessionExpiresAfter24h() {
        store.apply(e("A", .finished, at: 0))
        store.expire(now: Date(timeIntervalSince1970: 86_399))
        #expect(store.visible.count == 1)
        store.expire(now: Date(timeIntervalSince1970: 86_401))
        #expect(store.visible.isEmpty)
    }

    @Test func filterHidesAndRestores() {
        store.apply(e("X", .permission, cwd: "/x"))
        store.apply(e("Y", .permission, cwd: "/y"))
        store.isIncluded = { $0 != "/x" }
        store.refilter()
        #expect(store.visible.map(\.id) == ["Y"])
        store.isIncluded = { _ in true }
        store.refilter()
        #expect(store.visible.count == 2)
    }

    @Test func reminderOnceAfterFiveMinutes() {
        store.apply(e("A", .permission, at: 0))
        #expect(store.reminderDue(now: Date(timeIntervalSince1970: 299)) == [])
        #expect(store.reminderDue(now: Date(timeIntervalSince1970: 300)) == ["A"])
        #expect(store.reminderDue(now: Date(timeIntervalSince1970: 400)) == [])
    }

    @Test func repeatedPermissionKeepsStartTime() {
        store.apply(e("A", .permission, at: 0))
        store.apply(e("A", .permission, at: 50))
        #expect(store.visible.first?.since == Date(timeIntervalSince1970: 0))
    }

    @Test func changesAreReported() {
        var calls = 0
        store.onChange = { calls += 1 }
        store.apply(e("A", .permission))
        store.markOpened("A")
        store.refilter()
        #expect(calls == 2)   // markOpened on a permission changes nothing
    }
}
