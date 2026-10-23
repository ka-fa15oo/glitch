import AppKit
import SwiftUI

/// Menu bar entries for the Claude Code and Codex sentinel: install/remove the hook (with consent) and the project filter.
struct SentinelMenu: View {
    /// The menu bar menu is only rebuilt when its state changes, so every action bumps this.
    @State private var revision = 0

    var body: some View {
        let _ = revision
        ForEach(HookSetup.Tool.allCases, id: \.self) { tool in
            if HookSetup.isInstalled(tool) {
                Button("\(tool.name) sentinel: Remove") { HookSetup.uninstall(tool); revision += 1 }
            } else {
                Button("\(tool.name) sentinel: Install…") { HookSetup.askAndInstall(tool); revision += 1 }
            }
        }
        let projects = SentinelHub.shared.projects
        if !projects.known.isEmpty {
            Menu("Watched projects") {
                ForEach(projects.known, id: \.self) { cwd in
                    Button((projects.isIncluded(cwd) ? "✓ " : "    ") + projects.name(for: cwd)) {
                        projects.setIncluded(cwd, !projects.isIncluded(cwd))
                        SentinelHub.shared.store.refilter()
                        revision += 1
                    }
                }
            }
        }
    }
}

/// Reads and writes ~/.claude/settings.json or ~/.codex/hooks.json for the hook; only ever after the user confirms.
@MainActor
enum HookSetup {
    enum Tool: CaseIterable {
        case claudeCode, codex

        var name: String { self == .claudeCode ? "Claude Code" : "Codex" }
        var file: String { self == .claudeCode ? "~/.claude/settings.json" : "~/.codex/hooks.json" }
        var settingsURL: URL {
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(file.dropFirst(2)))
        }
        var events: [HookInstaller.Event] { self == .claudeCode ? HookInstaller.events : HookInstaller.codexEvents }
        /// Codex skips a new or changed hook until the user trusts it.
        var note: String { self == .claudeCode ? "" : "\n\nAfterwards, run /hooks in Codex once and trust Glitch's hook." }
    }

    static func isInstalled(_ tool: Tool = .claudeCode) -> Bool {
        HookInstaller.isInstalled(settings: try? Data(contentsOf: tool.settingsURL), scriptPath: HookInstaller.scriptPath,
                                  events: tool.events)
    }

    static func askAndInstall(_ tool: Tool = .claudeCode) {
        let alert = NSAlert()
        alert.messageText = "Install the \(tool.name) sentinel?"
        alert.informativeText = HookInstaller.preview(scriptPath: HookInstaller.scriptPath, file: tool.file,
                                                      events: tool.events, note: tool.note)
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try copyScript()
            let current = try? Data(contentsOf: tool.settingsURL)
            let updated = try HookInstaller.merged(settings: current, scriptPath: HookInstaller.scriptPath, events: tool.events)
            try write(updated, backingUp: current, to: tool.settingsURL)
        } catch HookInstaller.Failure.invalidJSON {
            show("Couldn't read \(tool.file). Nothing was changed.")
        } catch {
            show("Couldn't install: \(error.localizedDescription)")
        }
    }

    static func uninstall(_ tool: Tool = .claudeCode) {
        guard let current = try? Data(contentsOf: tool.settingsURL) else { return }
        do {
            try write(try HookInstaller.removed(settings: current, scriptPath: HookInstaller.scriptPath), backingUp: current,
                      to: tool.settingsURL)
        } catch HookInstaller.Failure.invalidJSON {
            show("Couldn't read \(tool.file). Nothing was changed.")
        } catch {
            show("Couldn't remove: \(error.localizedDescription)")
        }
    }

    /// The hook script ships inside the app; Claude Code and Codex run a stable copy in Application Support.
    private static func copyScript() throws {
        guard let bundled = Bundle.main.url(forResource: "glitch-hook", withExtension: "sh") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let target = URL(fileURLWithPath: HookInstaller.scriptPath)
        let files = FileManager.default
        try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if files.fileExists(atPath: target.path) { try files.removeItem(at: target) }
        try files.copyItem(at: bundled, to: target)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
    }

    private static func write(_ data: Data, backingUp old: Data?, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let old { try old.write(to: url.appendingPathExtension("glitch-backup"), options: .atomic) }
        try data.write(to: url, options: .atomic)
    }

    private static func show(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        NSApp.activate()
        alert.runModal()
    }
}
