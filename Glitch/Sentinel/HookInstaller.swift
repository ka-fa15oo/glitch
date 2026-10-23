import Foundation

/// Adds Glitch's hook to Claude Code's settings (or Codex's hooks.json, same shape) and takes it out again,
/// leaving everything else as it was.
enum HookInstaller {
    enum Failure: Error, Equatable { case invalidJSON }

    typealias Event = (name: String, matcher: String?)

    /// The hook events the sentinel listens to, with the tool matcher where one is needed.
    static let events: [Event] = [
        ("PermissionRequest", nil),
        ("Notification", nil),
        ("PreToolUse", "AskUserQuestion"),
        ("PostToolUse", nil),
        ("PostToolUseFailure", nil),
        ("PermissionDenied", nil),
        ("UserPromptSubmit", nil),
        ("Stop", nil),
        ("StopFailure", nil),
        ("SessionEnd", nil),
    ]

    /// Codex has no Notification, failure or denial events; Interrupt is the user stopping a turn.
    static let codexEvents: [Event] = [
        ("PermissionRequest", nil),
        ("PostToolUse", nil),
        ("UserPromptSubmit", nil),
        ("Stop", nil),
        ("Interrupt", nil),
        ("SessionEnd", nil),
    ]

    /// Where the installer copies the bundled hook script.
    static var scriptPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Glitch/glitch-hook.sh").path
    }

    /// The settings entry; Claude Code runs it through a shell, and the path contains "Application Support".
    static func command(_ scriptPath: String) -> String {
        "'" + scriptPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func merged(settings: Data?, scriptPath: String, events: [Event] = events) throws -> Data {
        var root = try object(settings)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for (name, matcher) in events {
            var groups = hooks[name] as? [[String: Any]] ?? []
            if groups.contains(where: { isOurs($0, scriptPath, legacy: false) }) { continue }
            // Drops an older unquoted entry so a reinstall replaces it rather than adding a second one.
            groups = groups.compactMap { strip($0, scriptPath) }
            var group: [String: Any] = ["hooks": [["type": "command", "command": command(scriptPath)]]]
            if let matcher { group["matcher"] = matcher }
            groups.append(group)
            hooks[name] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .withoutEscapingSlashes])
    }

    static func removed(settings: Data, scriptPath: String) throws -> Data {
        var root = try object(settings)
        guard var hooks = root["hooks"] as? [String: Any] else { return settings }
        for (name, value) in hooks {
            guard var groups = value as? [[String: Any]] else { continue }
            groups = groups.compactMap { strip($0, scriptPath) }
            hooks[name] = groups.isEmpty ? nil : groups
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .withoutEscapingSlashes])
    }

    static func isInstalled(settings: Data?, scriptPath: String, events: [Event] = events) -> Bool {
        guard let root = try? object(settings), let hooks = root["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { name, _ in
            (hooks[name] as? [[String: Any]] ?? []).contains { isOurs($0, scriptPath, legacy: true) }
        }
    }

    /// What the consent dialog lists.
    static func preview(scriptPath: String, file: String = "~/.claude/settings.json", events: [Event] = events,
                        note: String = "") -> String {
        """
        A command will be added to \(file) for these events:
        \(events.map { event in event.matcher.map { "\(event.name) (\($0))" } ?? event.name }.joined(separator: ", "))

        Command: \(command(scriptPath))
        It hands each event to Glitch as a file. It never blocks anything and sends nothing to the internet.
        Your existing settings and hooks stay as they are; a .glitch-backup copy is made first.\(note)
        """
    }

    private static func object(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x09 || $0 == 0x0D }) else { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalidJSON }
        return root
    }

    private static func isOurs(_ group: [String: Any], _ scriptPath: String, legacy: Bool) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains {
            let entry = $0["command"] as? String
            return entry == command(scriptPath) || (legacy && entry == scriptPath)
        }
    }

    /// The group without our entries (quoted or the older bare path), or nil when nothing else is left in it.
    private static func strip(_ group: [String: Any], _ scriptPath: String) -> [String: Any]? {
        guard var commands = group["hooks"] as? [[String: Any]] else { return group }
        commands.removeAll { [command(scriptPath), scriptPath].contains($0["command"] as? String) }
        if commands.isEmpty { return nil }
        var kept = group
        kept["hooks"] = commands
        return kept
    }
}
