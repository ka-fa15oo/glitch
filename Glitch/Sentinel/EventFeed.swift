import Foundation

/// Reads the hook payloads Glitch's hook script drops into the spool folder and feeds them to the store.
@MainActor
final class EventFeed {
    static let defaultSpool: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Glitch/events", isDirectory: true)

    private let spool: URL
    private let store: SessionStore
    private var source: DispatchSourceFileSystemObject?
    private var folder: Int32 = -1

    init(spool: URL, store: SessionStore) {
        self.spool = spool
        self.store = store
    }

    /// Starts empty (events from while Glitch was closed would only be ghosts), then watches the folder.
    func start() {
        let files = FileManager.default
        try? files.createDirectory(at: spool, withIntermediateDirectories: true)
        for url in (try? files.contentsOfDirectory(at: spool, includingPropertiesForKeys: nil)) ?? []
            where url.pathExtension == "json" {
            try? files.removeItem(at: url)
        }
        folder = open(spool.path, O_EVTONLY)
        guard folder >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: folder, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.drain() } }
        source.setCancelHandler { [folder] in close(folder) }
        source.resume()
        self.source = source
    }

    /// Applies every finished `*.json` file, oldest first, and deletes it; unreadable files are just deleted.
    func drain() {
        let files = FileManager.default
        let urls = ((try? files.contentsOfDirectory(at: spool, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        for url in urls {
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            if let data = try? Data(contentsOf: url), let event = SentinelEvent.parse(data, date: date) {
                store.apply(event)
            }
            try? files.removeItem(at: url)
        }
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
