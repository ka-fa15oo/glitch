import Foundation

/// Adds Glitch's hook to Claude Code's settings and takes it out again, leaving everything else as it was.
enum HookInstaller {
    enum Failure: Error, Equatable { case invalidJSON }

    /// The hook events the sentinel listens to, with the tool matcher where one is needed.
    static let events: [(name: String, matcher: String?)] = [
        ("PermissionRequest", nil),
        ("Notification", nil),
        ("PreToolUse", "AskUserQuestion"),
        ("PostToolUse", nil),
        ("PermissionDenied", nil),
        ("UserPromptSubmit", nil),
        ("Stop", nil),
        ("StopFailure", nil),
        ("SessionEnd", nil),
    ]

    /// Where the installer copies the bundled hook script.
    static var scriptPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Glitch/glitch-hook.sh").path
    }

    static func merged(settings: Data?, scriptPath: String) throws -> Data {
        var root = try object(settings)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for (name, matcher) in events {
            var groups = hooks[name] as? [[String: Any]] ?? []
            if groups.contains(where: { isOurs($0, scriptPath) }) { continue }
            var group: [String: Any] = ["hooks": [["type": "command", "command": scriptPath]]]
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
            groups = groups.compactMap { group in
                guard var commands = group["hooks"] as? [[String: Any]] else { return group }
                commands.removeAll { $0["command"] as? String == scriptPath }
                if commands.isEmpty { return nil }
                var kept = group
                kept["hooks"] = commands
                return kept
            }
            hooks[name] = groups.isEmpty ? nil : groups
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .withoutEscapingSlashes])
    }

    static func isInstalled(settings: Data?, scriptPath: String) -> Bool {
        guard let root = try? object(settings), let hooks = root["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { name, _ in
            (hooks[name] as? [[String: Any]] ?? []).contains { isOurs($0, scriptPath) }
        }
    }

    /// What the consent dialog lists.
    static func preview(scriptPath: String) -> String {
        """
        ~/.claude/settings.json içine şu olaylar için bir komut eklenecek:
        \(events.map { event in event.matcher.map { "\(event.name) (\($0))" } ?? event.name }.joined(separator: ", "))

        Komut: \(scriptPath)
        Her olayı Glitch'e bir dosya olarak bırakır, hiçbir şeyi engellemez, internete bir şey göndermez.
        Mevcut ayarların ve hook'ların değişmez; önce settings.json.glitch-backup yedeği alınır.
        """
    }

    private static func object(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x09 || $0 == 0x0D }) else { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalidJSON }
        return root
    }

    private static func isOurs(_ group: [String: Any], _ scriptPath: String) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == scriptPath }
    }
}
