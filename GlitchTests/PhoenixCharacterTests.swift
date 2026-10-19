import Foundation
import Testing

/// The phoenix (Character 5) is a caster like Wizzy and Faelis: no sword moves or sounds, its own fire reactions.
/// Serialized: the selected character is a global preference.
@MainActor
@Suite(.serialized)
struct PhoenixCharacterTests {
    private func brain() -> (Brain, () -> [SoundEffect]) {
        Prefs.register()
        Prefs.d.set(Phoenix.id, forKey: Prefs.character)
        let brain = Brain()
        var heard: [SoundEffect] = []
        brain.onSound = { heard.append($0) }
        return (brain, { heard })
    }

    private func run(_ brain: Brain, from start: Double, seconds: Double) {
        var t = start
        while t < start + seconds { brain.update(at: t); t += 1.0 / 30 }
    }

    @Test func reactsWithFireNotTheSword() {
        let (phoenix, heard) = brain()
        phoenix.setSentinel(hold: .barrier, redSparks: 1, goldSparks: 0, at: 100)
        #expect(phoenix.idleLifeRuns)
        phoenix.playFinished(at: 102)
        #expect(phoenix.actionKind == nil)
        run(phoenix, from: 102, seconds: 0.5)
        #expect(phoenix.current.feast >= 0)
        phoenix.playError(at: 103)
        #expect(phoenix.actionKind != .fumble)
        run(phoenix, from: 103, seconds: 2)
        phoenix.setSentinel(hold: .none, redSparks: 0, goldSparks: 1, at: 105)
        phoenix.clicked(at: 107)
        #expect(phoenix.actionKind != .flourish)
        run(phoenix, from: 107, seconds: 0.3)
        #expect(phoenix.current.cast >= 0)
        let sounds = heard()
        #expect(Set(sounds).isDisjoint(with: [.clang, .scrape, .swish]))
        #expect(sounds.contains(.smother) && sounds.contains(.shriek) && sounds.contains(.whoosh))
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    @Test func goodbyeBurnsToAsh() {
        let (phoenix, _) = brain()
        #expect(phoenix.farewellLength == Phoenix.farewellLength)
        phoenix.start(.farewell, at: 200)
        run(phoenix, from: 200, seconds: Phoenix.burnAt + 0.8)
        #expect(phoenix.current.ash > Phoenix.burnAt)
        #expect(phoenix.current.reveal < 0.05)
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    /// It flies where the others walk: up off its perch in a curve over the screen, down onto the next perch.
    @Test func fliesFromPerchToPerch() {
        let (phoenix, _) = brain()
        var origin = CGPoint(x: 500, y: 0)
        phoenix.windowOrigin = { origin }
        phoenix.setWindowOrigin = { origin = $0 }
        phoenix.walkBounds = { CGRect(x: 0, y: 0, width: 1000, height: 700) }
        phoenix.groundY = { 0 }
        var box: CGRect? = CGRect(x: 480, y: -20, width: 40, height: 40)   // someone types right where it perches
        phoenix.keepOut = { box }
        run(phoenix, from: 300, seconds: 0.1)
        box = nil
        var highest = 0.0
        var t = 300.1
        while t < 330 { phoenix.update(at: t); highest = max(highest, Double(origin.y)); t += 1.0 / 30 }
        #expect(highest > 100)                  // it went up into the air ...
        #expect(origin.y == 0 && abs(origin.x - 500) > 20)   // ... and came down somewhere else
        #expect(phoenix.current.aloft < 0.1)    // wings folded again
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    @Test func itsCryReplacesTheKnightsVoice() {
        #expect(Phoenix.voice(.angry) == .shriek && Phoenix.voice(.sad) == .shriek && Phoenix.voice(.happy) == .whoosh)
        #expect(Phoenix.voice(.thud) == .thud)
    }
}
