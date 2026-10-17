import Foundation

/// Project names for working folders and which projects the sentinel watches; kept in UserDefaults.
@MainActor
final class ProjectMap {
    private let defaults: UserDefaults
    private static let namesKey = "sentinel.projectNames"
    private static let excludedKey = "sentinel.excludedProjects"
    private static let knownKey = "sentinel.knownProjects"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The user's name for the folder, else its last path component ("PET", "Obsidian Vault").
    func name(for cwd: String) -> String {
        names[cwd] ?? URL(fileURLWithPath: cwd).lastPathComponent
    }

    func rename(_ cwd: String, to name: String) {
        var all = names
        all[cwd] = name
        defaults.set(all, forKey: Self.namesKey)
    }

    func isIncluded(_ cwd: String) -> Bool { !excluded.contains(cwd) }

    func setIncluded(_ cwd: String, _ on: Bool) {
        var all = Set(excluded)
        if on { all.remove(cwd) } else { all.insert(cwd) }
        defaults.set(all.sorted(), forKey: Self.excludedKey)
    }

    var known: [String] { defaults.stringArray(forKey: Self.knownKey) ?? [] }

    func noteSeen(_ cwd: String) {
        guard !cwd.isEmpty, !known.contains(cwd) else { return }
        defaults.set(known + [cwd], forKey: Self.knownKey)
    }

    private var names: [String: String] { defaults.dictionary(forKey: Self.namesKey) as? [String: String] ?? [:] }
    private var excluded: [String] { defaults.stringArray(forKey: Self.excludedKey) ?? [] }
}
