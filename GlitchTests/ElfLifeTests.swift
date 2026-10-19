import Foundation
import Testing

/// Faelis's idle life: wings that flutter, greenery that sprouts under her now and then, and a soft fall.
@MainActor
struct ElfLifeTests {
    @Test func wingsFlutterGentlyAndHarderWhenHeld() {
        let calm = stride(from: 0.0, to: 2, by: 0.01).map { Elf.wingSpread(t: $0, busy: 0) }
        let held = stride(from: 0.0, to: 2, by: 0.01).map { Elf.wingSpread(t: $0, busy: 1) }
        #expect(calm.allSatisfy { $0 > 0.85 && $0 <= 1 })                    // a gentle beat, never folded
        #expect(calm.max()! - calm.min()! > 0.03)                             // but it does move
        #expect(held.max()! - held.min()! > calm.max()! - calm.min()!)        // harder when carried or falling
    }

    @Test func greenerySproutsNowAndThenAndPasses() {
        let ages = stride(from: 0.0, to: Elf.greeneryPeriod * 2, by: 0.5).map { Elf.greeneryAge(t: $0) }
        let active = ages.compactMap { $0 }
        #expect(!active.isEmpty)
        #expect(Double(active.count) / Double(ages.count) < 0.2)              // most of the time there is none
        #expect(active.allSatisfy { $0 >= 0 && $0 < Elf.greeneryLength })
    }

    @Test func sheFloatsDownInsteadOfDropping() {
        var elf = 0.0, knight = 0.0
        for _ in 0 ..< 90 {
            elf = Brain.fallSpeed(elf, dt: 1.0 / 30, gentle: true)
            knight = Brain.fallSpeed(knight, dt: 1.0 / 30, gentle: false)
        }
        #expect(elf <= 260)
        #expect(knight > 2000)
    }
}
