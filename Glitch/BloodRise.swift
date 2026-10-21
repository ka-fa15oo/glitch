import SwiftUI

/// Arrival blood: a wide mound of blood heaves up out of the ground round the character, breaks at the crest
/// (the top lets go first), falls as heavy drops under gravity, splashes and spreads on the ground, and soaks away.
/// Every particle's position is a closed-form function of `age`, so nothing is stored between frames.
/// Particles are splatted into a pixel grid and shaded by depth under the surface, like the other blood.
enum BloodRise {
    private static let dark = Color(red: 0.24, green: 0.02, blue: 0.05)
    private static let body = Color(red: 0.42, green: 0.04, blue: 0.07)
    private static let mid = Color(red: 0.62, green: 0.08, blue: 0.09)
    private static let light = Color(red: 0.84, green: 0.16, blue: 0.14)

    private static let ground = 94.0
    private static let gravity = 300.0
    private static let crest = 1.0          // seconds until the mound reaches full height
    private static let peak = 64.0          // height of the mound (art px)

    private struct Particle {
        var x0 = 0.0, height = 0.0, release = 0.0, vx = 0.0, vy = 0.0, radius = 0.0, phase = 0.0
        var mass = true                     // false: a drop thrown up from the ground on its own
    }

    private static let particles: [Particle] = {
        var rng = SplitMix(seed: 0xB10D)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        var list: [Particle] = []
        let columns = 17
        for c in 0 ..< columns {
            let lane = Double(c) / Double(columns - 1) * 2 - 1                 // -1 ... 1
            let profile = peak * (1 - 0.72 * lane * lane)                      // dome, low at the edges
            var h = 2.0
            while h <= profile {
                var p = Particle()
                p.x0 = 38 + lane * 36 + (random() - 0.5) * 3
                p.height = h + (random() - 0.5) * 2
                p.release = crest + 0.16 * (1 - h / peak) + 0.05 * random()    // the top goes first
                p.vx = lane * (14 + 22 * random()) + (random() - 0.5) * 8      // pushed outwards
                p.vy = -8 - 26 * random()                                      // tossed up as it lets go
                p.radius = 4.4 + 1.2 * random()
                p.phase = random() * 6.28
                list.append(p)
                h += 4.0 + 1.2 * random()
            }
        }
        // heavy drops thrown up out of the ground while the mound climbs
        for _ in 0 ..< 34 {
            var p = Particle()
            p.mass = false
            p.x0 = 38 + (random() * 2 - 1) * 40
            p.release = 0.15 + 0.95 * random()
            p.vy = -(110 + 80 * random())
            p.vx = (p.x0 - 38) * 0.35 + (random() - 0.5) * 10
            p.radius = 1.7 + 1.3 * random()
            list.append(p)
        }
        return list
    }()

    /// The blood that jumps up when the knight lands: a spray fanned upwards plus drops thrown along the ground.
    private static let splashParticles: [Particle] = {
        var rng = SplitMix(seed: 0x5B1A)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        var list: [Particle] = []
        func add(angleDeg: Double, speed: Double, radius: Double) {
            var p = Particle()
            p.mass = false
            p.x0 = 38 + (random() - 0.5) * 8
            let a = angleDeg * .pi / 180                       // from straight up
            p.vy = -speed * cos(a)
            p.vx = speed * sin(a) * 1.15
            p.radius = radius
            list.append(p)
        }
        for _ in 0 ..< 90 { add(angleDeg: (random() * 2 - 1) * 70, speed: 70 + 150 * random(), radius: 1.6 + 1.6 * random()) }
        for _ in 0 ..< 22 { add(angleDeg: (random() * 2 - 1) * 24, speed: 150 + 90 * random(), radius: 2.8 + 1.4 * random()) }
        for _ in 0 ..< 36 {   // sprayed along the ground
            add(angleDeg: (random() < 0.5 ? -1 : 1) * (76 + 13 * random()), speed: 110 + 150 * random(), radius: 1.8 + 1.6 * random())
        }
        return list
    }()

    private static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    /// Where a particle is at `age` and how big it still is (0 = gone).
    private static func state(_ p: Particle, age: Double, t: Double) -> (x: Double, y: Double, scale: Double)? {
        let g = gravity
        if p.mass, age < p.release {
            let up = 1 - (1 - ease(age / crest)) * (1 - ease(age / crest))   // quick start, settles at the top
            let sway = sin(t * 2.2 + p.phase + p.height * 0.12) * 1.1 * up
            return (p.x0 + sway, ground - p.height * up, 1)
        }
        if !p.mass, age < p.release { return nil }
        let yb = p.mass ? ground - p.height : ground
        let xb = p.x0
        let s = age - p.release
        let drop = ground - yb
        let s1 = (-p.vy + (p.vy * p.vy + 2 * g * drop).squareRoot()) / g     // when it reaches the ground
        if s < s1 {
            return (xb + p.vx * s, yb + p.vy * s + 0.5 * g * s * s, 1)
        }
        let landX = xb + p.vx * s1
        let impact = p.vy + g * s1
        let bounce = -0.26 * impact
        let u = s - s1
        let flight = -2 * bounce / g
        // soaks away shortly after landing
        let scale = 1 - ease((u - 0.1) / 0.45)
        if scale <= 0 { return nil }
        if u < flight {
            return (landX + p.vx * 1.4 * u, ground + bounce * u + 0.5 * g * u * u, scale)
        }
        return (landX + p.vx * 1.4 * flight + p.vx * 0.3 * (u - flight), ground, scale)
    }

    static func draw(_ ctx: inout GraphicsContext, unit: CGFloat, age: Double, t: Double) {
        render(&ctx, unit: unit, list: particles, age: age, t: t)
    }

    /// The landing splash; `age` is the time since the knight hit the ground.
    static func drawSplash(_ ctx: inout GraphicsContext, unit: CGFloat, age: Double, t: Double) {
        render(&ctx, unit: unit, list: splashParticles, age: age, t: t)
    }

    /// Plays the landing splash over the whole screen, with the knight's feet where it landed, so the blood can fly past the pet.
    @MainActor static func launchSplash(windowOrigin: CGPoint, facingRight: Bool) {
        let feet = RobotView.screenPoint(art: CGPoint(x: 38, y: ground), windowOrigin: windowOrigin, facingRight: facingRight)
        guard let screen = RobotView.screen(containing: feet) else { return }
        let origin = CGPoint(x: feet.x - screen.frame.minX, y: screen.frame.maxY - feet.y)
        RobotView.presentOverlay(on: screen, for: 3.0, SplashOverlay(origin: origin, facingRight: facingRight, unit: RobotView.scale))
    }

    /// The splash drawn in screen coordinates, with `origin` (view coordinates, y down) under the knight's feet.
    struct SplashOverlay: View {
        let origin: CGPoint
        let facingRight: Bool
        let unit: CGFloat
        private let began = Date()

        var body: some View {
            TimelineView(.animation) { timeline in
                Canvas { ctx, _ in
                    var c = ctx
                    c.translateBy(x: origin.x, y: origin.y)
                    if facingRight { c.scaleBy(x: -1, y: 1) }
                    c.translateBy(x: -38 * unit, y: -ground * unit)
                    BloodRise.drawSplash(&c, unit: unit, age: timeline.date.timeIntervalSince(began), t: 0)
                }
            }
        }
    }

    private static func render(_ ctx: inout GraphicsContext, unit: CGFloat, list: [Particle], age: Double, t: Double) {
        // every particle still around, as (centre, radius) in art pixels
        let shapes: [(x: Double, y: Double, r: Double)] = list.compactMap { p in
            guard let s = state(p, age: age, t: t), s.scale > 0.02 else { return nil }
            return (s.x, min(s.y, ground + 1.5), p.radius * s.scale)
        }
        guard !shapes.isEmpty else { return }
        // the pixel grid covers all of it, so the blood is never cut off at an arbitrary edge
        var lo = (x: Double.infinity, y: Double.infinity), hi = (x: -Double.infinity, y: -Double.infinity)
        for s in shapes {
            lo = (min(lo.x, s.x - s.r), min(lo.y, s.y - s.r))
            hi = (max(hi.x, s.x + s.r), max(hi.y, s.y + s.r))
        }
        let x0 = Int(lo.x.rounded(.down)), y0 = Int(lo.y.rounded(.down))
        let w = Int(hi.x.rounded(.up)) - x0 + 1, h = Int(hi.y.rounded(.up)) - y0 + 1
        var density = [Float](repeating: 0, count: w * h)
        for s in shapes {
            let r = s.r, cx = s.x - Double(x0), cy = s.y - Double(y0)
            let ix0 = max(0, Int((cx - r).rounded(.down))), ix1 = min(w - 1, Int((cx + r).rounded(.up)))
            let iy0 = max(0, Int((cy - r).rounded(.down))), iy1 = min(h - 1, Int((cy + r).rounded(.up)))
            if ix0 > ix1 || iy0 > iy1 { continue }
            for yy in iy0 ... iy1 {
                for xx in ix0 ... ix1 {
                    let dx = Double(xx) + 0.5 - cx, dy = Double(yy) + 0.5 - cy
                    let f = 1 - (dx * dx + dy * dy) / (r * r)
                    if f > 0 { density[yy * w + xx] += Float(f * f) }
                }
            }
        }

        var layers = [Path(), Path(), Path(), Path()]   // dark, body, mid, light
        let threshold: Float = 0.3
        func solid(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < w && y >= 0 && y < h && density[y * w + x] >= threshold
        }
        for x in 0 ..< w {
            var depth = 0                                // cells below the surface of this run
            for y in 0 ..< h {
                guard solid(x, y) else { depth = 0; continue }
                var tone = depth < 1 ? 3 : depth < 3 ? 2 : depth < 9 ? 1 : 0
                if !solid(x - 1, y) || !solid(x + 1, y) { tone = max(0, tone - 1) }   // dark rim at the sides
                depth += 1
                let rect = CGRect(x: CGFloat(x + x0) * unit, y: CGFloat(y + y0) * unit, width: unit, height: unit)
                layers[tone].addRect(rect)
            }
        }
        ctx.opacity = 0.97
        ctx.fill(layers[0], with: .color(dark))
        ctx.fill(layers[1], with: .color(body))
        ctx.fill(layers[2], with: .color(mid))
        ctx.fill(layers[3], with: .color(light))
        ctx.opacity = 1
    }
}
