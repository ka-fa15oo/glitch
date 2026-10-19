import SwiftUI

/// Faelis's two big scenes, drawn on a see-through, click-through window over the whole screen (like Wizzy's cosmos):
/// the arrival, where a big sun opens, its light falls on a patch of ground, flowers bloom there and she rises from
/// among them; and the goodbye, where she casts with her wand and turns into butterflies that fly off across the screen.
enum ElfMeadow {
    static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    // MARK: - timings (shared by the overlay and the brain)

    /// Arrival: the sun opens by `sunUp`, its beam reaches the ground at `bloomAt`, flowers shoot up tall until `riseAt`,
    /// she rises behind them over the next second, the flowers sink back down from `shrinkAt`, then light and flowers fade.
    static let sunUp = 0.9, beamAt = 0.6, bloomAt = 1.2, riseAt = 2.5, shrinkAt = 3.5, arrivalLength = 5.2
    /// Goodbye: the wand spell takes `spellLength`, then she becomes butterflies; the app may quit at `farewellLength`.
    static let spellLength = 1.2, farewellLength = 3.8

    /// How much of her shows while rising, and how far below her place she still is (art px).
    static func rise(_ e: Double) -> (reveal: Double, dy: Double) {
        let k = ease((e - riseAt) / 1.0)
        return (ease((e - riseAt) / 0.8), 16 * (1 - k))
    }

    // MARK: - the flowers

    static let petals: [Color] = [
        Color(red: 0.96, green: 0.65, blue: 0.75), Color(red: 1.0, green: 0.85, blue: 0.29), Color(red: 1.0, green: 0.98, blue: 0.94),
        Color(red: 0.71, green: 0.55, blue: 0.88), Color(red: 1.0, green: 0.60, blue: 0.35), Color(red: 0.54, green: 0.78, blue: 0.94),
        Color(red: 0.95, green: 0.42, blue: 0.42),
    ]
    static let heart = Color(red: 0.91, green: 0.69, blue: 0.19)
    static let stem = Color(red: 0.31, green: 0.60, blue: 0.27), leaf = Color(red: 0.47, green: 0.76, blue: 0.35)

    /// `dx`: pt from the landing spot, `dy`: pt above the ground line, `height`: stem cells at its tallest,
    /// `bloom`: seconds into the arrival when it sprouts, `lag`: how much later than `shrinkAt` it starts to sink.
    struct Flower { let dx: Double; let dy: Double; let height: Int; let color: Int; let big: Bool; let bloom: Double; let lag: Double }

    static let flowers: [Flower] = {
        var rng = SplitMix(seed: 0xF10A)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        return (0 ..< 96).map { i in
            let dx = (random() * 2 - 1) * 95
            // the middle sprouts first and it spreads outwards; the middle ones grow tallest, a thicket she hides behind
            let bloom = bloomAt + 0.4 * min(1, abs(dx) / 95) * (0.7 + 0.3 * random())
            let height = Int((30 + 18 * random()) * (1 - 0.35 * abs(dx) / 95))
            return Flower(dx: dx, dy: random() * 10 - 2, height: height, color: i % petals.count,
                          big: i % 3 == 0, bloom: bloom, lag: 0.3 * random())
        }
    }()

    /// Stem cells of flower `f` at `age`: it shoots up to its full height, then sinks back to a short sprig.
    static func stemCells(_ f: Flower, age: Double) -> Int {
        let grow = ease((age - f.bloom) / 0.9), sink = ease((age - shrinkAt - f.lag) / 0.9)
        guard age > f.bloom else { return 0 }
        return max(1, Int((2 + Double(f.height - 2) * grow * (1 - sink)).rounded()))
    }

    struct MeadowView: View {
        let landing: CGPoint          // view coordinates (y down) of the middle of the pet window
        let ground: Double            // y of the ground line there
        var fixedAge: Double?
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge { canvas(age: fixedAge) } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        private func canvas(age: Double) -> some View {
            Canvas { c, size in
                // the sun stands high on the inner side of the landing spot, so its light falls slantwise
                let sun = CGPoint(x: landing.x + (landing.x < size.width / 2 ? 240 : -240), y: max(110, ground - 560))
                let lightFade = 1 - ease((age - 3.8) / 1.0)
                drawSun(c, at: sun, age: age, fade: lightFade)
                drawBeam(c, from: sun, age: age, fade: lightFade)
                drawFlowers(c, age: age)
            }
        }

        private func drawSun(_ c: GraphicsContext, at p: CGPoint, age: Double, fade: Double) {
            let open = ease(age / sunUp)
            guard open > 0, fade > 0 else { return }
            let unit = 4.0, r = 13 * open
            var c = c
            c.opacity = fade
            // a soft warm halo behind the pixels
            let halo = 150 * open
            c.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
                   with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.9, blue: 0.5).opacity(0.45), .clear]),
                                         center: p, startRadius: 0, endRadius: halo))
            var layers = Array(repeating: Path(), count: 4)     // rays, rim, body, core
            func cell(_ tone: Int, _ x: Double, _ y: Double) {
                layers[tone].addRect(CGRect(x: p.x + (x * unit).rounded(), y: p.y + (y * unit).rounded(), width: unit, height: unit))
            }
            let reach = Int(r.rounded(.up))
            if reach > 0 {
                for y in -reach ... reach {
                    for x in -reach ... reach {
                        let d = hypot(Double(x), Double(y)) / r
                        if d > 1 { continue }
                        cell(d > 0.85 ? 1 : d > 0.45 ? 2 : 3, Double(x), Double(y))
                    }
                }
            }
            // twelve rays that grow out as it opens and turn slowly
            for i in 0 ..< 12 {
                let a = Double(i) / 12 * 2 * .pi + age * 0.25
                let len = (i % 2 == 0 ? 7.0 : 4.5) * ease((age - 0.3) / 0.6)
                var s = r + 2
                while s < r + 2 + len { cell(0, cos(a) * s, sin(a) * s); s += 1 }
            }
            let palette = [Color(red: 1, green: 0.90, blue: 0.5), Color(red: 0.96, green: 0.65, blue: 0.14),
                           Color(red: 1, green: 0.85, blue: 0.29), Color(red: 1, green: 0.96, blue: 0.69)]
            for (path, color) in zip(layers, palette) { c.fill(path, with: .color(color)) }
        }

        /// A wide soft shaft of light from the sun down to the landing spot, and the glow where it lands.
        private func drawBeam(_ c: GraphicsContext, from sun: CGPoint, age: Double, fade: Double) {
            let reach = ease((age - beamAt) / (bloomAt - beamAt))
            guard reach > 0, fade > 0 else { return }
            let foot = CGPoint(x: landing.x, y: ground)
            let end = CGPoint(x: sun.x + (foot.x - sun.x) * reach, y: sun.y + (foot.y - sun.y) * reach)
            let spread = 20 + 90 * reach
            var beam = Path()
            beam.move(to: CGPoint(x: sun.x - 22, y: sun.y))
            beam.addLine(to: CGPoint(x: sun.x + 22, y: sun.y))
            beam.addLine(to: CGPoint(x: end.x + spread, y: end.y))
            beam.addLine(to: CGPoint(x: end.x - spread, y: end.y))
            beam.closeSubpath()
            var c = c
            c.opacity = fade
            c.fill(beam, with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.93, blue: 0.6).opacity(0.5),
                                                                 Color(red: 1, green: 0.95, blue: 0.7).opacity(0.22)]),
                                               startPoint: sun, endPoint: end))
            let glow = ease((age - bloomAt + 0.2) / 0.5)
            if glow > 0 {
                let w = 230.0, h = 46.0
                c.fill(Path(ellipseIn: CGRect(x: foot.x - w / 2, y: foot.y - h / 2, width: w, height: h)),
                       with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.7).opacity(0.6 * glow), .clear]),
                                             center: foot, startRadius: 0, endRadius: w / 2))
            }
        }

        /// Each flower shoots up its stem with leaves along it, opens a bud, then the full blossom; it sinks back, then all fade.
        private func drawFlowers(_ c: GraphicsContext, age: Double) {
            let fade = 1 - ease((age - (arrivalLength - 0.5)) / 0.5)
            guard fade > 0 else { return }
            let unit = 4.0
            var stems = Path(), leaves = Path(), hearts = Path()
            var blooms = Array(repeating: Path(), count: petals.count)
            func cell(_ path: inout Path, _ x: Double, _ y: Double) {
                path.addRect(CGRect(x: (x / unit).rounded() * unit, y: (y / unit).rounded() * unit, width: unit, height: unit))
            }
            for f in flowers {
                let e = age - f.bloom
                guard e > 0 else { continue }
                let x = landing.x + f.dx, base = ground - f.dy
                let grown = stemCells(f, age: age)
                for k in 0 ..< grown { cell(&stems, x, base - Double(k) * unit) }
                for k in stride(from: 3, to: grown - 1, by: 5) {                    // leaves on alternate sides
                    cell(&leaves, x + (k % 2 == 0 ? unit : -unit), base - Double(k) * unit)
                }
                for k in stride(from: 6, to: grown - 3, by: 6) {                    // side blossoms all the way up
                    let side = (k / 6) % 2 == 0 ? 2.0 : -2.0, y = base - Double(k) * unit
                    let tone = (f.color + k / 6) % petals.count
                    cell(&hearts, x + side * unit, y)
                    for (dx, dy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { cell(&blooms[tone], x + (side + dx) * unit, y + dy * unit) }
                }
                let top = base - Double(grown) * unit
                let open = e - 0.2
                if open > 0 {
                    cell(&hearts, x, top)
                    let r = open < 0.12 ? 0 : 1
                    if r == 0 { cell(&blooms[f.color], x, top - unit) } else {
                        for (dx, dy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { cell(&blooms[f.color], x + dx * unit, top + dy * unit) }
                        if f.big, open > 0.22 {
                            for (dx, dy) in [(-1.0, -1.0), (1, -1), (-1, 1), (1, 1), (-2, 0), (2, 0), (0, -2)] {
                                cell(&blooms[f.color], x + dx * unit, top + dy * unit)
                            }
                        }
                    }
                }
            }
            var c = c
            c.opacity = fade
            c.fill(stems, with: .color(stem))
            c.fill(leaves, with: .color(leaf))
            for (path, color) in zip(blooms, petals) { c.fill(path, with: .color(color)) }
            c.fill(hearts, with: .color(heart))
        }
    }

    // MARK: - the butterflies

    /// `dx`, `dy`: where on her body it starts (pt from the window middle); `angle`: where it heads (y down, so
    /// negative is up); `speed` pt/s; `phase`: wing beat and wobble offset.
    struct Butterfly { let dx: Double; let dy: Double; let angle: Double; let speed: Double; let color: Int; let phase: Double }

    static let butterflies: [Butterfly] = {
        var rng = SplitMix(seed: 0xB077)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        return (0 ..< 64).map { i in
            Butterfly(dx: (random() * 2 - 1) * 34, dy: (random() * 2 - 1) * 70,
                      angle: -.pi * (-0.1 + 1.2 * random()), speed: 150 + 170 * random(),
                      color: i % petals.count, phase: random() * 6.28)
        }
    }()

    /// Where butterfly `b` is `age` seconds into the goodbye, how visible, and how open its wings are (0...1).
    static func flight(_ b: Butterfly, age: Double, from center: CGPoint) -> (position: CGPoint, alpha: Double, flap: Double) {
        let t = age - spellLength
        guard t > 0 else { return (CGPoint(x: center.x + b.dx, y: center.y + b.dy), 0, 1) }
        let along = b.speed * t + 90 * t * t                              // a slow start, then off they go
        let wobble = sin(t * 5 + b.phase) * 14 * min(1, t * 2)
        let x = center.x + b.dx + cos(b.angle) * along - sin(b.angle) * wobble
        let y = center.y + b.dy + sin(b.angle) * along + cos(b.angle) * wobble
        let life = farewellLength - spellLength
        let alpha = ease(t / 0.25) * (1 - ease((t - (life - 0.5)) / 0.5))
        return (CGPoint(x: x, y: y), alpha, abs(cos(t * 16 + b.phase)))
    }

    struct ButterflyView: View {
        let center: CGPoint           // view coordinates, y down
        var fixedAge: Double?
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge { canvas(age: fixedAge) } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        private func canvas(age: Double) -> some View {
            Canvas { c, _ in
                let unit = 4.0
                for b in butterflies {
                    let f = flight(b, age: age, from: center)
                    guard f.alpha > 0.01 else { continue }
                    var wings = Path(), spots = Path(), body = Path()
                    func cell(_ path: inout Path, _ x: Double, _ y: Double) {
                        path.addRect(CGRect(x: (f.position.x / unit).rounded() * unit + x * unit,
                                            y: (f.position.y / unit).rounded() * unit + y * unit, width: unit, height: unit))
                    }
                    cell(&body, 0, -1); cell(&body, 0, 0); cell(&body, 0, 1)
                    let span = f.flap > 0.66 ? 3 : f.flap > 0.3 ? 2 : 1          // the wings beat: wide, half, edge-on
                    for side in [-1.0, 1.0] {
                        for k in 1 ... span {
                            let x = side * Double(k)
                            cell(&wings, x, -2); cell(&wings, x, -1)
                            if k < 3 { cell(&wings, x, 1) }
                            if k == 1 { cell(&wings, x, 0); cell(&wings, x, 2) }
                        }
                        if span == 3 { cell(&spots, side * 2, -1) }
                    }
                    var layer = c
                    layer.opacity = f.alpha
                    layer.fill(wings, with: .color(petals[b.color]))
                    layer.fill(spots, with: .color(.white.opacity(0.8)))
                    layer.fill(body, with: .color(Color(red: 0.25, green: 0.18, blue: 0.1)))
                }
            }
        }
    }

    // MARK: - overlay windows

    @MainActor private static var overlay: NSWindow?

    /// A window the size of the screen that holds `point`, click-through and see-through; closes itself after `life`.
    @MainActor private static func showOverlay(containing point: CGPoint, life: Double, content: (_ frame: CGRect) -> AnyView) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return }
        let frame = screen.frame
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content(frame))
        overlay?.close()
        overlay = window
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + life) {
            window.close()
            if overlay === window { overlay = nil }
        }
    }

    /// `center` is the middle of the pet window in screen coordinates (y up).
    @MainActor static func openMeadow(over center: CGPoint) {
        showOverlay(containing: center, life: arrivalLength) { frame in
            let ground = Double(frame.maxY - (center.y - 80))                      // the feet are 80 pt under the middle
            return AnyView(MeadowView(landing: CGPoint(x: center.x - frame.minX, y: frame.maxY - center.y), ground: ground))
        }
    }

    @MainActor static func openButterflies(from center: CGPoint) {
        showOverlay(containing: center, life: farewellLength) { frame in
            AnyView(ButterflyView(center: CGPoint(x: center.x - frame.minX, y: frame.maxY - center.y)))
        }
    }
}
