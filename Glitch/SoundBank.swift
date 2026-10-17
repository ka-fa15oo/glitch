import AVFoundation

enum SoundEffect {
    case wake, farewell, sad, glitch, swish, angry, happy, surprised, tick, thud
}

/// Tiny synthesizer: every effect is generated in code, so there are no audio assets.
@MainActor
final class SoundBank {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    var isMuted = false

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
        guard !isMuted else { return }
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
