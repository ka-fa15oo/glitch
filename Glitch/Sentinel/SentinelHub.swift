import Foundation

/// The sentinel's shared state: one store, one project map, one spool feed for the whole app.
@MainActor
final class SentinelHub {
    static let shared = SentinelHub()

    let store = SessionStore()
    let projects = ProjectMap()
    private(set) lazy var feed = EventFeed(spool: EventFeed.defaultSpool, store: store)

    private init() {
        store.isIncluded = { [projects] in projects.isIncluded($0) }
    }
}
