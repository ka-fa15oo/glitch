import Foundation
import Testing

/// Faelis reacts to Claude Code in her own way: a glowing bud for a permission, calling out for a question,
/// a bloom when a session finishes and wilting petals on an error. She never freezes and never sounds cross.
@MainActor
@Suite(.serialized)
struct ElfSentinelTests {
    private static let notHers: Set<SoundEffect> = [.clang, .scrape, .swish, .rune, .orb, .fizzle]

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

    @Test func questionMakesHerCallOutUntilAnswered() {
        let (elf, heard) = brain()
        elf.setSentinel(hold: .attend, redSparks: 0, goldSparks: 0, at: 100)
        #expect(elf.idleLifeRuns)
        run(elf, from: 100, seconds: 7)
        #expect(elf.current.orb >= 0)                                   // the call is on
        #expect(heard().filter { $0 == .call }.count >= 3)              // and keeps ringing every few seconds
        elf.setSentinel(hold: .none, redSparks: 0, goldSparks: 0, at: 107)
        let rang = heard().filter { $0 == .call }.count
        run(elf, from: 107, seconds: 4)
        #expect(elf.current.orb < 0)
        #expect(heard().filter { $0 == .call }.count == rang)          // quiet once answered
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    @Test func permissionShowsABudAndRemindsSoftly() {
        let (elf, heard) = brain()
        elf.setSentinel(hold: .barrier, redSparks: 1, goldSparks: 0, at: 100)
        run(elf, from: 100, seconds: 1)
        #expect(elf.current.rune >= 0)
        elf.remindPermission(at: 101)
        run(elf, from: 101, seconds: 0.5)
        #expect(elf.current.nudge >= 0)
        #expect(heard().filter { $0 == .nudge }.count == 2)
        #expect(Set(heard()).isDisjoint(with: Self.notHers))
        Prefs.d.removeObject(forKey: Prefs.character)
    }

    @Test func finishedBloomsAndErrorWiltsThenSheSmilesAgain() {
        let (elf, heard) = brain()
        elf.playFinished(at: 100)
        #expect(elf.actionKind == nil)
        run(elf, from: 100, seconds: 1)
        #expect(elf.current.feast >= 0)
        #expect(heard().contains(.chime))
        elf.playError(at: 104)
        #expect(elf.actionKind == nil)
        run(elf, from: 104, seconds: 0.2)
        #expect(elf.current.misfire >= 0)
        run(elf, from: 104.2, seconds: 0.8)
        #expect(elf.current.eyes == .happy)
        #expect(heard().contains(.wilt))
        #expect(Set(heard()).isDisjoint(with: Self.notHers))
        Prefs.d.removeObject(forKey: Prefs.character)
    }
}
