import AVFoundation

enum SoundEffect {
    case wake, farewell, sad, glitch, swish, angry, happy, surprised, tick, thud, clang, scrape
    case chime, nudge, rune, orb, fizzle   // Wizzy's spells
    case starGlide, hole                   // Wizzy's arrival along the star road and its black hole goodbye
    case constellation, dustOut, dustIn, shootingStar   // Wizzy's idle and walking spells, and its click
    case petals                            // Faelis's click: a shower of flowers from her wand
    case call, wilt                        // Faelis's sentinel: calling out for a question, petals wilting on an error
}

/// Tiny synthesizer: every effect is generated in code, so there are no audio assets.
@MainActor
final class SoundBank {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    private enum Wave { case sine, square, noise }
    private struct Step {
        var from: Double
        var to: Double
        var duration: Double
        var wave: Wave = .sine
        var gain: Double = 0.5
        var crush = false
    }

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.5
        try? engine.start()
    }

    /// Before the Mac sleeps: stop the audio engine and drop anything still queued, so nothing plays on waking.
    func suspend() {
        player.stop()
        engine.pause()
    }

    func play(_ effect: SoundEffect) {
        let effect = Elf.isSelected ? Elf.voice(effect) : effect
        // Sound tab: mute, volume and per-group switches are read on every play, so changes apply at once
        guard !Prefs.d.bool(forKey: Prefs.muted), SoundGroup.allows(effect) else { return }
        // Wizzy carries no sword: the knight's metal sounds never play for it, whoever asks for them
        if Mage.isSelected || Elf.isSelected || Phoenix.isSelected, [.clang, .scrape, .swish].contains(effect) { return }
        engine.mainMixerNode.outputVolume = Float(Prefs.d.double(forKey: Prefs.volume))
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        let key = "\(effect)"
        let buffer = buffers[key] ?? makeBuffer(for: effect)
        buffers[key] = buffer
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func steps(for effect: SoundEffect) -> [Step] {
        switch effect {
        case .wake:
            [Step(from: 110, to: 110, duration: 0.12, wave: .square, gain: 0.25),
             Step(from: 165, to: 220, duration: 0.18, wave: .square, gain: 0.25),
             Step(from: 220, to: 440, duration: 0.5, gain: 0.45)]
        case .farewell:
            [Step(from: 440, to: 330, duration: 0.2, gain: 0.4),
             Step(from: 330, to: 220, duration: 0.25, gain: 0.4),
             Step(from: 220, to: 110, duration: 0.5, wave: .square, gain: 0.25)]
        case .sad:
            [Step(from: 330, to: 220, duration: 0.5, gain: 0.35),
             Step(from: 220, to: 140, duration: 0.8, gain: 0.3)]
        case .glitch:
            [Step(from: 0, to: 0, duration: 0.12, wave: .noise, gain: 0.5, crush: true),
             Step(from: 90, to: 60, duration: 0.1, wave: .square, gain: 0.3, crush: true),
             Step(from: 0, to: 0, duration: 0.08, wave: .noise, gain: 0.4, crush: true)]
        case .swish:
            [Step(from: 0, to: 0, duration: 0.45, wave: .noise, gain: 0.22)]
        case .angry:
            [Step(from: 90, to: 80, duration: 0.18, wave: .square, gain: 0.35),
             Step(from: 80, to: 70, duration: 0.25, wave: .square, gain: 0.35)]
        case .happy:
            [Step(from: 520, to: 520, duration: 0.09, gain: 0.35),
             Step(from: 780, to: 780, duration: 0.14, gain: 0.35)]
        case .surprised:
            [Step(from: 300, to: 900, duration: 0.14, wave: .square, gain: 0.25)]
        case .tick:
            [Step(from: 1400, to: 1000, duration: 0.03, gain: 0.25)]
        case .thud:
            [Step(from: 140, to: 45, duration: 0.2, gain: 0.8),
             Step(from: 0, to: 0, duration: 0.07, wave: .noise, gain: 0.35)]
        case .clang:   // short, dull metal
            [Step(from: 0, to: 0, duration: 0.025, wave: .noise, gain: 0.5),
             Step(from: 330, to: 300, duration: 0.16, gain: 0.4),
             Step(from: 690, to: 660, duration: 0.12, gain: 0.18)]
        case .scrape:  // metal dragged over stone
            [Step(from: 0, to: 0, duration: 1.0, wave: .noise, gain: 0.3, crush: true)]
        case .chime:   // finished: a soft rising arpeggio that rings out
            [Step(from: 1047, to: 1047, duration: 0.11, gain: 0.22),
             Step(from: 1319, to: 1319, duration: 0.11, gain: 0.22),
             Step(from: 1568, to: 1568, duration: 0.11, gain: 0.22),
             Step(from: 2093, to: 2093, duration: 0.7, gain: 0.24)]
        case .nudge:   // reminder: two quiet pings
            [Step(from: 880, to: 880, duration: 0.12, gain: 0.16),
             Step(from: 1175, to: 1175, duration: 0.3, gain: 0.16)]
        case .rune:    // the rune appears: a low hum rising into a faint tone
            [Step(from: 196, to: 233, duration: 0.4, gain: 0.22),
             Step(from: 392, to: 392, duration: 0.35, gain: 0.1)]
        case .orb:     // the ball lights up: a small upward shimmer
            [Step(from: 660, to: 990, duration: 0.3, gain: 0.14),
             Step(from: 1320, to: 1320, duration: 0.3, gain: 0.08)]
        case .starGlide:   // a shimmer sweeping up while the road is drawn, then a soft descending glide
            [Step(from: 520, to: 1900, duration: 0.8, gain: 0.1),
             Step(from: 1900, to: 700, duration: 1.1, gain: 0.08)]
        case .hole:        // a low swirl that sinks away
            [Step(from: 140, to: 70, duration: 1.2, gain: 0.22),
             Step(from: 0, to: 0, duration: 0.9, wave: .noise, gain: 0.09),
             Step(from: 70, to: 38, duration: 1.0, gain: 0.26)]
        case .constellation:   // stars set one by one: three faint, high plucks, the first as the first star lands
            [Step(from: 0, to: 0, duration: 0.5, gain: 0),
             Step(from: 1760, to: 1760, duration: 0.07, gain: 0.08),
             Step(from: 0, to: 0, duration: 0.73, gain: 0),
             Step(from: 2093, to: 2093, duration: 0.07, gain: 0.08),
             Step(from: 0, to: 0, duration: 0.73, gain: 0),
             Step(from: 2349, to: 2349, duration: 0.25, gain: 0.07)]
        case .dustOut:     // scattering into star dust: a soft hiss sweeping up
            [Step(from: 0, to: 0, duration: 0.55, wave: .noise, gain: 0.1),
             Step(from: 1400, to: 2600, duration: 0.15, gain: 0.05)]
        case .dustIn:      // gathering again: a shimmer coming down to rest
            [Step(from: 2600, to: 1300, duration: 0.5, gain: 0.07),
             Step(from: 1300, to: 1300, duration: 0.2, gain: 0.04)]
        case .call:   // "over here!": a bright two-note bell
            [Step(from: 1319, to: 1319, duration: 0.1, gain: 0.18),
             Step(from: 1760, to: 1760, duration: 0.25, gain: 0.16)]
        case .wilt:   // a soft falling sigh, never cross
            [Step(from: 880, to: 740, duration: 0.18, gain: 0.14),
             Step(from: 740, to: 587, duration: 0.3, gain: 0.1)]
        case .petals:   // a light tinkle, like little bells
            [Step(from: 1568, to: 1568, duration: 0.07, gain: 0.16),
             Step(from: 2093, to: 2093, duration: 0.07, gain: 0.15),
             Step(from: 2637, to: 2637, duration: 0.07, gain: 0.13),
             Step(from: 3136, to: 3136, duration: 0.35, gain: 0.1)]
        case .shootingStar:   // a quick bright streak that fades
            [Step(from: 1900, to: 3100, duration: 0.12, gain: 0.1),
             Step(from: 3100, to: 1500, duration: 0.6, gain: 0.07)]
        case .fizzle:  // the spell misfires: a sputter and a sinking buzz
            [Step(from: 0, to: 0, duration: 0.09, wave: .noise, gain: 0.3, crush: true),
             Step(from: 240, to: 90, duration: 0.25, wave: .square, gain: 0.14, crush: true),
             Step(from: 0, to: 0, duration: 0.14, wave: .noise, gain: 0.18)]
        }
    }

    private func makeBuffer(for effect: SoundEffect) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        var samples: [Float] = []
        var phase = 0.0
        var lowPass = 0.0
        for step in steps(for: effect) {
            let count = Int(step.duration * rate)
            for i in 0 ..< count {
                let p = Double(i) / Double(max(count - 1, 1))
                let freq = step.from + (step.to - step.from) * p
                phase += 2 * .pi * freq / rate
                var value: Double
                switch step.wave {
                case .sine: value = sin(phase)
                case .square: value = sin(phase) >= 0 ? 0.6 : -0.6
                case .noise:
                    let raw = Double.random(in: -1 ... 1)
                    lowPass += (raw - lowPass) * (0.15 + 0.6 * p)   // sweeps brighter over time
                    value = lowPass
                }
                if step.crush { value = (value * 4).rounded() / 4 }
                let attack = min(1, Double(i) / (0.006 * rate))
                let envelope = attack * pow(1 - p, 1.6)
                samples.append(Float(value * step.gain * envelope))
            }
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, v) in samples.enumerated() { buffer.floatChannelData![0][i] = v }
        return buffer
    }
}
