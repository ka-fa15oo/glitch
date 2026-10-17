import Foundation
import Testing

@MainActor
struct EventFeedTests {
    let spool = Fixture.tempDir()
    let store = SessionStore()

    private func write(_ name: String, _ data: Data) {
        try? data.write(to: spool.appendingPathComponent(name))
    }

    private var files: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: spool.path)) ?? []).sorted()
    }

    @Test func startClearsOldFiles() {
        for i in 1 ... 3 { write("\(i).1.json", Fixture.data("permission")) }
        let feed = EventFeed(spool: spool, store: store)
        feed.start()
        defer { feed.stop() }
        #expect(files.isEmpty)
        #expect(store.visible.isEmpty)
    }

    @Test func drainAppliesInOrderAndDeletes() {
        let feed = EventFeed(spool: spool, store: store)
        write("1000.1.json", Fixture.data("permission"))
        write("1001.2.json", Fixture.data("userActed"))
        feed.drain()
        #expect(store.visible.isEmpty)
        #expect(files.isEmpty)
    }

    @Test func badFileSkippedAndDeleted() {
        let feed = EventFeed(spool: spool, store: store)
        write("1.1.json", Data("not json".utf8))
        write("2.2.json", Fixture.data("permission"))
        feed.drain()
        #expect(store.visible.count == 1)
        #expect(files.isEmpty)
    }

    @Test func ignoresTmpFiles() {
        let feed = EventFeed(spool: spool, store: store)
        write("3.3.tmp", Fixture.data("permission"))
        feed.drain()
        #expect(files == ["3.3.tmp"])
        #expect(store.visible.isEmpty)
    }

    @Test func hookScriptWritesOneFile() throws {
        let home = Fixture.tempDir()
        let status = try runHook(home: home, input: #"{"x":1}"#)
        #expect(status == 0)
        let dir = home.appendingPathComponent("Library/Application Support/Glitch/events")
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.count == 1)
        #expect(names.first?.hasSuffix(".json") == true)
        #expect(try String(contentsOf: dir.appendingPathComponent(names[0]), encoding: .utf8) == #"{"x":1}"#)
    }

    @Test func hookScriptExitsZeroWhenItCannotWrite() throws {
        #expect(try runHook(home: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"), input: "{}") == 0)
    }

    private func runHook(home: URL, input: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [Fixture.repo.appendingPathComponent("Tools/glitch-hook.sh").path]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardError = Pipe()
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
