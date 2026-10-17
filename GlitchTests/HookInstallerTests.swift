import Foundation
import Testing

struct HookInstallerTests {
    let script = "/Users/x/Library/Application Support/Glitch/glitch-hook.sh"
    let userSettings = Data("""
    {"model":"opus","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo hi"}]}]}}
    """.utf8)

    private func parsed(_ data: Data) -> NSDictionary {
        // swiftlint:disable:next force_try force_cast
        try! JSONSerialization.jsonObject(with: data) as! NSDictionary
    }

    private func groups(_ data: Data, _ event: String) -> [[String: Any]] {
        (parsed(data)["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
    }

    @Test func mergeIntoNil() throws {
        let out = try HookInstaller.merged(settings: nil, scriptPath: script)
        #expect(HookInstaller.isInstalled(settings: out, scriptPath: script))
        #expect(groups(out, "PreToolUse").first?["matcher"] as? String == "AskUserQuestion")
    }

    @Test func mergeIntoEmptyObject() throws {
        #expect(HookInstaller.isInstalled(settings: try HookInstaller.merged(settings: Data("{}".utf8), scriptPath: script),
                                          scriptPath: script))
        #expect(HookInstaller.isInstalled(settings: try HookInstaller.merged(settings: Data("  \n".utf8), scriptPath: script),
                                          scriptPath: script))
    }

    @Test func mergeKeepsUserHooks() throws {
        let out = try HookInstaller.merged(settings: userSettings, scriptPath: script)
        #expect(parsed(out)["model"] as? String == "opus")
        let pre = groups(out, "PreToolUse")
        #expect(pre.count == 2)
        #expect(pre[0]["matcher"] as? String == "Bash")
        #expect((pre[0]["hooks"] as? [[String: Any]])?.first?["command"] as? String == "echo hi")
    }

    @Test func mergeTwiceNoDuplicates() throws {
        let once = try HookInstaller.merged(settings: userSettings, scriptPath: script)
        let twice = try HookInstaller.merged(settings: once, scriptPath: script)
        #expect(parsed(once) == parsed(twice))
    }

    @Test func invalidJSONThrows() {
        #expect(throws: HookInstaller.Failure.invalidJSON) {
            try HookInstaller.merged(settings: Data("{ not json".utf8), scriptPath: script)
        }
    }

    @Test func removeLeavesUserHooks() throws {
        let merged = try HookInstaller.merged(settings: userSettings, scriptPath: script)
        let removed = try HookInstaller.removed(settings: merged, scriptPath: script)
        #expect(parsed(removed) == parsed(userSettings))
        #expect(!HookInstaller.isInstalled(settings: removed, scriptPath: script))
    }

    @Test func removeFromNoHooksLeavesSettings() throws {
        let plain = Data(#"{"theme":"dark"}"#.utf8)
        let merged = try HookInstaller.merged(settings: plain, scriptPath: script)
        #expect(parsed(try HookInstaller.removed(settings: merged, scriptPath: script)) == parsed(plain))
    }

    @Test func isInstalledTrueAfterMerge() throws {
        #expect(!HookInstaller.isInstalled(settings: userSettings, scriptPath: script))
        #expect(HookInstaller.isInstalled(settings: try HookInstaller.merged(settings: userSettings, scriptPath: script),
                                          scriptPath: script))
    }

    @Test func listensToFailedTools() {
        #expect(HookInstaller.events.contains { $0.name == "PostToolUseFailure" })
    }

    /// Claude Code runs the command through a shell, so the space in "Application Support" must not split it.
    @Test func hookCommandRunsThroughShellWithSpacesInPath() throws {
        let home = Fixture.tempDir().appendingPathComponent("with space")
        let path = home.appendingPathComponent("Library/Application Support/Glitch/glitch-hook.sh").path
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: Fixture.repo.appendingPathComponent("Tools/glitch-hook.sh").path, toPath: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        let command = try #require(groups(try HookInstaller.merged(settings: nil, scriptPath: path), "Stop")
            .first.flatMap { ($0["hooks"] as? [[String: Any]])?.first?["command"] as? String })

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardError = Pipe()
        try process.run()
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let events = home.appendingPathComponent("Library/Application Support/Glitch/events").path
        #expect(try FileManager.default.contentsOfDirectory(atPath: events).filter { $0.hasSuffix(".json") }.count == 1)
    }

    /// The first release wrote the bare path; uninstall must clean it up and a reinstall must replace it.
    @Test func legacyUnquotedEntryIsReplacedAndRemoved() throws {
        let legacy = Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\#(script)"}]}]}}"#.utf8)
        #expect(groups(try HookInstaller.removed(settings: legacy, scriptPath: script), "Stop").isEmpty)
        let stop = groups(try HookInstaller.merged(settings: legacy, scriptPath: script), "Stop")
        #expect(stop.count == 1)
        #expect((stop[0]["hooks"] as? [[String: Any]])?.first?["command"] as? String != script)
    }
}
