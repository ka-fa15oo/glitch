import CoreGraphics
import Foundation
import Testing

/// Faelis is always happy: no cross or startled voice, and a click flicks her wand for a shower of flowers.
@MainActor
@Suite(.serialized)
struct ElfJoyTests {
    @Test func herVoiceIsAlwaysCheerful() {
        #expect(Elf.voice(.angry) == .happy)
        #expect(Elf.voice(.surprised) == .happy)
        #expect(Elf.voice(.sad) == .happy)
        #expect(Elf.voice(.chime) == .chime)
    }

    @Test func flowersFlyOutBothWaysThenSettleAndFade() {
        let drop = 106.0
        let petals = ElfMeadow.petals(count: ElfMeadow.burstCount)
        #expect(petals.count >= 24)
        let early = petals.map { ElfMeadow.petal($0, age: 0.25, drop: drop) }
        #expect(early.contains { $0.offset.x < -20 } && early.contains { $0.offset.x > 20 })   // to both sides
        #expect(early.contains { $0.offset.y < 0 })                                             // tossed up first
        for p in petals {
            for age in stride(from: 0.0, through: ElfMeadow.burstLength, by: 0.05) {
                #expect(ElfMeadow.petal(p, age: age, drop: drop).offset.y <= drop)               // never below the ground
            }
            #expect(ElfMeadow.petal(p, age: ElfMeadow.burstLength, drop: drop).alpha == 0)
        }
    }

    @Test func clickFlicksTheWandAndRingsWithoutASwordMove() {
        Prefs.register()
        Prefs.d.set(Elf.id, forKey: Prefs.character)
        let brain = Brain()
        var heard: [SoundEffect] = []
        brain.onSound = { heard.append($0) }
        brain.clicked(at: 100)
        brain.update(at: 100.2)
        #expect(brain.current.cast >= 0)
        #expect(brain.actionKind != .flourish)
        #expect(heard.contains(.petals))
        Prefs.d.removeObject(forKey: Prefs.character)
    }
}
