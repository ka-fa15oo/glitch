import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SessionDirectoryTests {
    private func useRoot(_ url: URL) {
        SessionDirectory.root = url
        SessionDirectory.reset()
    }

    private func write(_ text: String, _ name: String, in root: URL) {
        let dir = root.appendingPathComponent("org/account", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Data(text.utf8).write(to: dir.appendingPathComponent(name))
    }

    @Test func sessionLookupFallsBackWhenFileMissingOrMalformed() {
        // no folder at all
        useRoot(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        #expect(SessionDirectory.localID(for: "abcdef123") == nil)
        #expect(SessionDirectory.title(for: "abcdef123") == "abcdef")

        // malformed JSON and renamed fields
        let root = Fixture.tempDir()
        write("{ not json", "local_1.json", in: root)
        write(#"{"cli_session":"abcdef123","id":"local_2","name":"X"}"#, "local_2.json", in: root)
        useRoot(root)
        #expect(SessionDirectory.localID(for: "abcdef123") == nil)
        #expect(SessionDirectory.title(for: "abcdef123") == "abcdef")
    }

    @Test func sessionLookupReadsTitleAndLocalID() {
        let root = Fixture.tempDir()
        write(#"{"sessionId":"local_9","cliSessionId":"abcdef123","title":"Main"}"#, "local_9.json", in: root)
        write("garbage", "local_bad.json", in: root)                 // one bad file doesn't spoil the rest
        useRoot(root)
        #expect(SessionDirectory.localID(for: "abcdef123") == "local_9")
        #expect(SessionDirectory.title(for: "abcdef123") == "Main")
    }
}
