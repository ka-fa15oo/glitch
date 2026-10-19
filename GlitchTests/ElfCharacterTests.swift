import Foundation
import Testing

/// Faelis (Character 3) shares the brain but none of the knight's sword, blood or sounds, and none of Wizzy's cosmos.
/// Serialized: the selected character is a global preference.
@MainActor
@Suite(.serialized)
struct ElfCharacterTests {
    private static let knightSounds: Set<SoundEffect> = [.clang, .scrape, .swish]

    private func brain() -> (Brain, () -> [SoundEffect]) {
        Prefs.register()
        Prefs.d.set(Elf.id, forKey: Prefs.character)
        let brain = Brain()
        var heard: [SoundEffect] = []
        brain.onSound = { heard.append($0) }
        return (brain, { heard })
    }

    private func run(_ brain: Brain, from start: Double, seconds: Double) {
        var t = start
        while t < start + seconds { brain.update(at: t); t += 1.0 / 30 }
    }

    @Test func faelisIsOnThePicker() {
        let ids = CharacterInfo.all.map(\.id)
        #expect(CharacterInfo.all.contains { $0.id == Elf.id && $0.name == "Faelis" && $0.available })
        #expect(ids.count == 5)
        #expect(Set(ids).count == ids.count)
    }

    @Test func sentinelAndClickStartNoKnightMoveOrSound() {
        let (elf, heard) = brain()
        elf.setSentinel(hold: .barrier, redSparks: 1, goldSparks: 0, at: 100)
        #expect(elf.idleLifeRuns)
        elf.remindPermission(at: 101)
        elf.playFinished(at: 102)
        #expect(elf.actionKind == nil)
        elf.playError(at: 103)
        #expect(elf.actionKind != .fumble)
        run(elf, from: 103, seconds: 2)
        elf.clicked(at: 106)
        #expect(elf.actionKind != .flourish)
        run(elf, from: 106, seconds: 2)
        #expect(Set(heard()).isDisjoint(with: Self.knightSounds))
        Prefs.d.removeObject(forKey: Prefs.character)
    }
}
