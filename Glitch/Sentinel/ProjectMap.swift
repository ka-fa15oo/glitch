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

    /// The known project a folder belongs to: the folder itself or its closest known parent.
    func project(for cwd: String) -> String {
        known.filter { cwd == $0 || cwd.hasPrefix($0 + "/") }.min { $0.count < $1.count } ?? cwd
    }

    /// The user's name for the project, else its last path component ("PET", "Obsidian Vault"),
    /// with the parent folder added when two projects share that name ("PET (work)").
    func name(for cwd: String) -> String {
        let root = project(for: cwd)
        if let name = names[root] { return name }
        let url = URL(fileURLWithPath: root)
        let twins = known.filter { URL(fileURLWithPath: $0).lastPathComponent == url.lastPathComponent }
        return twins.count > 1 ? "\(url.lastPathComponent) (\(url.deletingLastPathComponent().lastPathComponent))"
            : url.lastPathComponent
    }

    func rename(_ cwd: String, to name: String) {
        var all = names
        all[cwd] = name
        defaults.set(all, forKey: Self.namesKey)
    }

    func isIncluded(_ cwd: String) -> Bool { !excluded.contains(project(for: cwd)) }

    func setIncluded(_ cwd: String, _ on: Bool) {
        var all = Set(excluded)
        if on { all.remove(cwd) } else { all.insert(cwd) }
        defaults.set(all.sorted(), forKey: Self.excludedKey)
    }

    /// Projects seen so far; subfolders stored by earlier versions are folded into their parent.
    var known: [String] {
        let all = defaults.stringArray(forKey: Self.knownKey) ?? []
        return all.filter { cwd in !all.contains { cwd.hasPrefix($0 + "/") } }
    }

    func noteSeen(_ cwd: String) {
        guard !cwd.isEmpty, project(for: cwd) == cwd, !known.contains(cwd) else { return }
        // A parent seen later absorbs the subfolders listed before it.
        defaults.set(known.filter { !$0.hasPrefix(cwd + "/") } + [cwd], forKey: Self.knownKey)
    }

    private var names: [String: String] { defaults.dictionary(forKey: Self.namesKey) as? [String: String] ?? [:] }
    private var excluded: [String] { defaults.stringArray(forKey: Self.excludedKey) ?? [] }
}
