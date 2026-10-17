import AppKit

/// Connects the session store to the knight: held poses and sparks, one-shot moves, reminders, the hover list
/// and click-to-open.
@MainActor
final class SentinelController {
    private let brain: Brain
    private let store: SessionStore
    private let feed: EventFeed
    private let projects: ProjectMap
    private let list = SessionListPanel()
    private var timer: Timer?
    private var hovering = false
    private var lastFrame = CGRect.zero

    init(brain: Brain, store: SessionStore, feed: EventFeed, projects: ProjectMap) {
        self.brain = brain
        self.store = store
        self.feed = feed
        self.projects = projects
    }

    func start() {
        store.onChange = { [weak self] in self?.update() }
        store.onEvent = { [weak self] event in self?.react(to: event) }
        feed.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        update()
    }

    /// true = the click opened the most urgent session; false = let the knight's own click behaviour run.
    func handleClick() -> Bool {
        guard let session = store.mostUrgent else { return false }
        SessionDirectory.open(session.id)
        store.markOpened(session.id)
        return true
    }

    /// The list shows only while the cursor is on the knight and something is waiting or done.
    func hover(_ inside: Bool, near frame: CGRect) {
        hovering = inside
        lastFrame = frame
        refreshList()
    }

    private func update() {
        let visible = store.visible
        let hold: Brain.SentinelHold = visible.contains { $0.state == .permission } ? .barrier
            : visible.contains { $0.state == .question } ? .attend : .none
        brain.setSentinel(hold: hold, redSparks: store.redSparks, goldSparks: store.goldSparks)
        refreshList()
    }

    private func react(to event: SentinelEvent) {
        projects.noteSeen(event.cwd)
        guard projects.isIncluded(event.cwd) else { return }
        switch event.kind {
        case .finished: brain.playFinished()
        case .error: brain.playError()
        default: break
        }
    }

    private func tick() {
        let now = Date()
        store.expire(now: now)
        if !store.reminderDue(now: now).isEmpty { brain.remindPermission() }
        if hovering { refreshList() }   // keeps the ages current
    }

    private func refreshList() {
        let rows = store.visible
        if hovering, !rows.isEmpty {
            list.show(rows, names: { [projects] in projects.name(for: $0) }, beside: lastFrame)
        } else {
            list.hide()
        }
    }
}
