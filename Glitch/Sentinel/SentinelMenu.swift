import AppKit
import SwiftUI

/// Menu bar entries for the Claude Code sentinel: install/remove the hook (with consent) and the project filter.
struct SentinelMenu: View {
    var body: some View {
        if HookSetup.isInstalled {
            Button("Claude Code nöbetçisi: Kaldır") { HookSetup.uninstall() }
        } else {
            Button("Claude Code nöbetçisi: Kur…") { HookSetup.askAndInstall() }
        }
        let projects = SentinelHub.shared.projects
        if !projects.known.isEmpty {
            Menu("İzlenen projeler") {
                ForEach(projects.known, id: \.self) { cwd in
                    Button((projects.isIncluded(cwd) ? "✓ " : "    ") + projects.name(for: cwd)) {
                        projects.setIncluded(cwd, !projects.isIncluded(cwd))
                        SentinelHub.shared.store.refilter()
                    }
                }
            }
        }
    }
}

/// Reads and writes ~/.claude/settings.json for the hook; only ever after the user confirms.
@MainActor
enum HookSetup {
    static let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    static var backupURL: URL { settingsURL.appendingPathExtension("glitch-backup") }

    static var isInstalled: Bool {
        HookInstaller.isInstalled(settings: try? Data(contentsOf: settingsURL), scriptPath: HookInstaller.scriptPath)
    }

    static func askAndInstall() {
        let alert = NSAlert()
        alert.messageText = "Claude Code nöbetçisi kurulsun mu?"
        alert.informativeText = HookInstaller.preview(scriptPath: HookInstaller.scriptPath)
        alert.addButton(withTitle: "Kur")
        alert.addButton(withTitle: "Vazgeç")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try copyScript()
            let current = try? Data(contentsOf: settingsURL)
            let updated = try HookInstaller.merged(settings: current, scriptPath: HookInstaller.scriptPath)
            try write(updated, backingUp: current)
        } catch HookInstaller.Failure.invalidJSON {
            show("settings.json okunamadı, hiçbir şey değiştirilmedi.")
        } catch {
            show("Kurulamadı: \(error.localizedDescription)")
        }
    }

    static func uninstall() {
        guard let current = try? Data(contentsOf: settingsURL) else { return }
        do {
            try write(try HookInstaller.removed(settings: current, scriptPath: HookInstaller.scriptPath), backingUp: current)
        } catch HookInstaller.Failure.invalidJSON {
            show("settings.json okunamadı, hiçbir şey değiştirilmedi.")
        } catch {
            show("Kaldırılamadı: \(error.localizedDescription)")
        }
    }

    /// The hook script ships inside the app; Claude Code runs a stable copy in Application Support.
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

    private static func write(_ data: Data, backingUp old: Data?) throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let old { try old.write(to: backupURL, options: .atomic) }
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func show(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        NSApp.activate()
        alert.runModal()
    }
}
