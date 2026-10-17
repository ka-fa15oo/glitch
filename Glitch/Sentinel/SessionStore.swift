import Foundation

enum SessionState: Int, Comparable, Sendable {
    case permission = 1, question, error, finished          // lower = more urgent

    static func < (a: SessionState, b: SessionState) -> Bool { a.rawValue < b.rawValue }
}

struct SessionStatus: Equatable, Sendable {
    let id: String
    let cwd: String
    let state: SessionState
    let since: Date
}

/// Which Claude Code sessions are waiting on the user, in priority order.
@MainActor
final class SessionStore {
    var isIncluded: (String) -> Bool = { _ in true }       // cwd -> project filter
    var onChange: (() -> Void)?

    private var sessions: [String: SessionStatus] = [:]
    private var lastEvent: [String: Date] = [:]
    private var reminded: Set<String> = []

    private static let deadAfter: TimeInterval = 24 * 60 * 60
    private static let remindAfter: TimeInterval = 5 * 60

    func apply(_ event: SentinelEvent) {
        let id = event.sessionID
        lastEvent[id] = event.date
        switch event.kind {
        case .permission: set(id, event.cwd, .permission, event.date)
        case .question: set(id, event.cwd, .question, event.date)
        case .error: set(id, event.cwd, .error, event.date)
        case .finished: set(id, event.cwd, .finished, event.date)
        case .userActed:
            sessions[id] = nil
            reminded.remove(id)
        case .ended:
            sessions[id] = nil
            lastEvent[id] = nil
            reminded.remove(id)
        }
        onChange?()
    }

    /// The user opened this session from Glitch: a finished or failed one no longer needs a look.
    func markOpened(_ id: String) {
        guard let status = sessions[id], status.state == .finished || status.state == .error else { return }
        sessions[id] = nil
        onChange?()
    }

    /// Sessions that died without an end event stop showing after a day of silence.
    func expire(now: Date) {
        let dead = lastEvent.filter { now.timeIntervalSince($0.value) > Self.deadAfter }.map(\.key)
        guard !dead.isEmpty else { return }
        for id in dead {
            sessions[id] = nil
            lastEvent[id] = nil
            reminded.remove(id)
        }
        onChange?()
    }

    func refilter() { onChange?() }

    var visible: [SessionStatus] {
        sessions.values.filter { isIncluded($0.cwd) }.sorted { ($0.state, $0.since) < ($1.state, $1.since) }
    }

    var mostUrgent: SessionStatus? { visible.first }
    var redSparks: Int { visible.filter { $0.state == .permission || $0.state == .question }.count }
    var goldSparks: Int { visible.filter { $0.state == .finished }.count }

    /// Permission requests left unanswered for 5 minutes; each one is returned only once.
    func reminderDue(now: Date) -> [String] {
        let due = visible.filter {
            $0.state == .permission && now.timeIntervalSince($0.since) >= Self.remindAfter && !reminded.contains($0.id)
        }.map(\.id)
        reminded.formUnion(due)
        return due
    }

    private func set(_ id: String, _ cwd: String, _ state: SessionState, _ date: Date) {
        if let old = sessions[id], old.state == state { return }   // still waiting: keep the original start time
        sessions[id] = SessionStatus(id: id, cwd: cwd, state: state, since: date)
        if state != .permission { reminded.remove(id) }
    }
}
