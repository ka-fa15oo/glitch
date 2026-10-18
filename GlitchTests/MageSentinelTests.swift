import Foundation
import Testing

/// Wizzy gets the sentinel through the same Brain API as Glitch, with its own moves and sounds.
/// Serialized: the selected character is a global preference.
@MainActor
@Suite(.serialized)
struct MageSentinelTests {
    private static let knightSounds: Set<SoundEffect> = [.clang, .scrape, .swish]

    private func brain(as character: String) -> (Brain, () -> [SoundEffect]) {
        Prefs.register()
        Prefs.d.set(character, forKey: Prefs.character)
        let brain = Brain()
        var heard: [SoundEffect] = []
        brain.onSound = { heard.append($0) }
        return (brain, { heard })
    }

    /// Runs the brain for `seconds` of simulated time from `start`.
    private func run(_ brain: Brain, from start: Double, seconds: Double) {
        var t = start
        while t < start + seconds { brain.update(at: t); t += 1.0 / 30 }
    }

    @Test func mageHoldKeepsIdleLife() {
        let (mage, _) = brain(as: Mage.id)
        mage.setSentinel(hold: .barrier, redSparks: 1, goldSparks: 0, at: 100)
        #expect(mage.idleLifeRuns)
        let (knight, _) = brain(as: "glitch")
        knight.setSentinel(hold: .barrier, redSparks: 1, goldSparks: 0, at: 100)
        #expect(!knight.idleLifeRuns)
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    @Test func mageFinishedAndErrorStartNoKnightMoveOrSound() {
        let (mage, heard) = brain(as: Mage.id)
        mage.setSentinel(hold: .barrier, redSparks: 1, goldSparks: 0, at: 100)
        mage.remindPermission(at: 101)
        mage.playFinished(at: 102)
        #expect(mage.actionKind == nil)
        run(mage, from: 102, seconds: 1)
        #expect(mage.current.feast >= 0)
        mage.playError(at: 104)
        #expect(mage.actionKind == nil)
        run(mage, from: 104, seconds: 3)
        #expect(Set(heard()).isDisjoint(with: Self.knightSounds))
        #expect(heard().contains(.chime))
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    @Test func glitchStillUsesItsSwordMoves() {
        let (knight, heard) = brain(as: "glitch")
        knight.playFinished(at: 100)
        #expect(knight.actionKind == .finished)
        run(knight, from: 100, seconds: 2)
        #expect(heard().contains(.scrape))
        Prefs.d.removeObject(forKey: Prefs.character)
    }
}
