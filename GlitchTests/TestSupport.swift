import Foundation

enum Fixture {
    /// Repo root, found from this file's location (tests compile the sources straight from the repo).
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    static func data(_ name: String) -> Data {
        // swiftlint:disable:next force_try
        try! Data(contentsOf: repo.appendingPathComponent("GlitchTests/Fixtures/\(name).json"))
    }

    static func event(_ id: String, _ kind: SentinelEvent.Kind, cwd: String = "/p", at seconds: TimeInterval = 0) -> SentinelEvent {
        SentinelEvent(sessionID: id, cwd: cwd, kind: kind, date: Date(timeIntervalSince1970: seconds))
    }

    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("glitch-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
