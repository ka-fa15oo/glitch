import AppKit

/// Finds a Claude Code session's title and opens it.
/// Desktop sessions: the Claude app keeps a file per session (`claude-code-sessions/*/*/local_<id>.json`) holding the
/// hook's session id as `cliSessionId`, the `local_…` id its `claude://` link uses, and the title.
/// Terminal sessions have no such file: their terminal app is brought forward instead.
@MainActor
enum SessionDirectory {
    struct Entry { let localID: String; let title: String }

    private static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions", isDirectory: true)
    private static var cache: [String: Entry] = [:]
    private static var cachedAt = Date.distantPast

    static func entry(for sessionID: String) -> Entry? {
        if cache[sessionID] == nil, Date().timeIntervalSince(cachedAt) > 5 { reload() }
        return cache[sessionID]
    }

    /// The title shown in the list: the desktop title, else the first 6 characters of the id.
    static func title(for sessionID: String) -> String {
        entry(for: sessionID)?.title ?? String(sessionID.prefix(6))
    }

    static func open(_ sessionID: String) {
        if let entry = entry(for: sessionID), let url = URL(string: "claude://claude.ai/epitaxy/\(entry.localID)") {
            NSWorkspace.shared.open(url)
            return
        }
        // a terminal `claude` session: bring the terminal forward
        let terminals = ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable"]
        if let app = NSWorkspace.shared.runningApplications.first(where: { terminals.contains($0.bundleIdentifier ?? "") }) {
            app.activate()
        }
    }

    private static func reload() {
        cachedAt = Date()
        let files = FileManager.default
        guard let walker = files.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        var found: [String: Entry] = [:]
        for case let url as URL in walker where url.lastPathComponent.hasPrefix("local_") && url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cli = object["cliSessionId"] as? String,
                  let local = object["sessionId"] as? String else { continue }
            found[cli] = Entry(localID: local, title: object["title"] as? String ?? String(cli.prefix(6)))
        }
        cache = found
    }
}
