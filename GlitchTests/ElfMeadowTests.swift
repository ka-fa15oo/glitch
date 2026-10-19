import CoreGraphics
import Foundation
import Testing

/// Faelis's arrival (sun, light, flowers, she rises from them) and goodbye (wand spell, then butterflies).
@MainActor
@Suite(.serialized)
struct ElfMeadowTests {
    @Test func flowersBloomInTheLightBeforeSheRises() {
        let flowers = ElfMeadow.flowers
        #expect(flowers.count >= 16)
        #expect(Set(flowers.map(\.color)).count >= 4)                      // many colours
        for f in flowers {
            #expect(abs(f.dx) <= 160)                                       // inside the lit patch
            #expect(f.bloom >= ElfMeadow.bloomAt && f.bloom < ElfMeadow.riseAt)
        }
    }

    @Test func sheRisesFromTheFlowers() {
        #expect(ElfMeadow.rise(ElfMeadow.riseAt - 0.1).reveal == 0)
        let mid = ElfMeadow.rise(ElfMeadow.riseAt + 0.4)
        #expect(mid.reveal > 0 && mid.reveal < 1 && mid.dy > 0)            // half seen, still low among the flowers
        let done = ElfMeadow.rise(ElfMeadow.riseAt + 1.2)
        #expect(done.reveal == 1 && done.dy == 0)
        #expect(ElfMeadow.arrivalLength > ElfMeadow.riseAt + 1.2)
    }

    @Test func flowersShootUpTallThenSinkBack() {
        let middle = ElfMeadow.flowers.filter { abs($0.dx) < 40 }
        #expect(!middle.isEmpty)
        for f in middle {
            #expect(ElfMeadow.stemCells(f, age: ElfMeadow.riseAt) >= 25)                    // tall enough to hide her
            #expect(ElfMeadow.stemCells(f, age: ElfMeadow.arrivalLength - 0.4) <= 3)        // back down again
        }
    }

    @Test func butterfliesLeaveBeforeTheAppQuits() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let center = CGPoint(x: 720, y: 450)
        #expect(ElfMeadow.butterflies.count >= 50)
        for b in ElfMeadow.butterflies {
            #expect(ElfMeadow.flight(b, age: ElfMeadow.spellLength - 0.1, from: center).alpha == 0)   // none before the spell ends
            let gone = ElfMeadow.flight(b, age: ElfMeadow.farewellLength, from: center)
            #expect(gone.alpha == 0 || !screen.contains(gone.position))
        }
    }

    @Test func farewellCastsThenFadesWithoutBlood() {
        Prefs.register()
        Prefs.d.set(Elf.id, forKey: Prefs.character)
        let brain = Brain()
        #expect(brain.farewellLength == ElfMeadow.farewellLength)
        brain.start(.farewell, at: 100)
        var t = 100.0
        while t < 100.6 { brain.update(at: t); t += 1.0 / 30 }
        #expect(brain.current.spell > 0)
        #expect(brain.current.reveal > 0.95)
        while t < 100 + ElfMeadow.farewellLength { brain.update(at: t); t += 1.0 / 30 }
        #expect(brain.current.reveal < 0.05)
        #expect(brain.current.cocoonAge < 0)
        Prefs.d.removeObject(forKey: Prefs.character)
    }
}
