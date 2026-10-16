import SwiftUI

/// Goodbye effect in the style of Blasphemous' Mea Culpa: eight thick ribbons of blood burst up from the ground,
/// coil round the kneeling knight in different directions with hooked, curling ends, swallow it, then drain back
/// down into the ground. The part of each coil nearer the viewer is drawn in front of the character.
enum BloodStorm {
    enum Side { case behind, inFront }

    private struct Ribbon {
        let angle0: Double      // where it starts round the body
        let turns: Double       // how far it coils (negative = the other way)
        let spin: Double        // how fast the whole coil turns (rad/s)
        let radius: Double      // average distance from the body
        let height: Double      // how high it climbs
        let width: Double       // thickness in art pixels
        let tilt: Double        // how strongly the coil is seen from above (perspective)
        let hook: Double        // curl at the tip
        let delay: Double       // bursts up a little after the others
    }

    private static let ribbons: [Ribbon] = [
        Ribbon(angle0: 0.3, turns: 1.15, spin: 6.5, radius: 20, height: 92, width: 10, tilt: 0.3, hook: 2.6, delay: 0.0),
        Ribbon(angle0: 2.4, turns: -0.95, spin: -5.5, radius: 24, height: 78, width: 8.5, tilt: 0.42, hook: -2.2, delay: 0.08),
        Ribbon(angle0: 4.2, turns: 1.35, spin: 7.5, radius: 17, height: 100, width: 7.5, tilt: 0.22, hook: 3.0, delay: 0.16),
        Ribbon(angle0: 5.4, turns: -0.7, spin: -6.8, radius: 28, height: 62, width: 6.5, tilt: 0.5, hook: -2.8, delay: 0.24),
        Ribbon(angle0: 1.2, turns: -1.25, spin: -7.2, radius: 22, height: 86, width: 9, tilt: 0.36, hook: -2.4, delay: 0.04),
        Ribbon(angle0: 3.3, turns: 0.85, spin: 6.0, radius: 30, height: 70, width: 7, tilt: 0.46, hook: 2.9, delay: 0.12),
        Ribbon(angle0: 4.8, turns: -1.05, spin: -8.0, radius: 15, height: 96, width: 8, tilt: 0.26, hook: -3.2, delay: 0.2),
        Ribbon(angle0: 0.0, turns: 1.5, spin: 7.0, radius: 26, height: 54, width: 6, tilt: 0.55, hook: 2.5, delay: 0.3),
    ]

    /// `age` is seconds since the storm started: bursts up 0–0.5 s, rages until 2.0 s, drains into the ground by 2.8 s.
    static func draw(_ ctx: inout GraphicsContext, unit: CGFloat, age: Double, t: Double, side: Side) {
        guard age >= 0 else { return }
        func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }
        func easeOut(_ x: Double) -> Double { let c = max(0, min(1, x)); return 1 - (1 - c) * (1 - c) }
        let drain = ease((age - 2.0) / 0.7)
        let fade = 1 - ease((age - 2.6) / 0.3)
        guard fade > 0.001 else { return }

        let cx = 38.0, ground = 92.0
        var dark = Path(), mid = Path(), bright = Path()
        func pixel(_ path: inout Path, _ x: Double, _ y: Double) {
            path.addRect(CGRect(x: floor(x) * unit, y: floor(y) * unit, width: unit, height: unit))
        }
        func blob(_ x: Double, _ y: Double, _ r: Double, front: Bool) {
            let n = Int(r.rounded(.up))
            for dy in -n ... n {
                for dx in -n ... n {
                    let d = hypot(Double(dx), Double(dy))
                    guard d <= r else { continue }
                    pixel(&dark, x + Double(dx), y + Double(dy))
                    if d <= r * 0.62 { pixel(&mid, x + Double(dx) - 0.5, y + Double(dy) - 0.5) }
                    if front, d <= r * 0.28 { pixel(&bright, x + Double(dx) - 1.2, y + Double(dy) - 1.2) }
                }
            }
        }

        for (index, rb) in ribbons.enumerated() {
            let grow = easeOut((age - rb.delay) / 0.5)
            guard grow > 0 else { continue }
            let top = grow * (1 - drain)                    // the visible part of the ribbon, from the ground up
            let samples = 110
            for s in 0 ... samples {
                let u = Double(s) / Double(samples)
                guard u <= top else { break }
                // coil round the body; the tip curls into a hook
                let curl = ease((u - 0.78) / 0.22)
                let a = rb.angle0 + rb.turns * 2 * .pi * u + rb.spin * t + rb.hook * curl
                    + sin(t * 3.1 + u * 7 + Double(index)) * 0.25
                if (sin(a) > 0) != (side == .inFront) { continue }
                let r = rb.radius * (0.55 + 0.6 * sin(.pi * min(1, u * 1.15))) * (1 - 0.6 * curl)
                    * (1 + 0.12 * sin(t * 5 + u * 9 + Double(index) * 2))
                let x = cx + r * cos(a)
                let y = ground - rb.height * u + rb.tilt * r * sin(a) + 18 * drain * u     // sags as it drains
                // thick body that thins to the base and the tip
                let taper = min(1, (top - u) * 9 + 0.2)
                let w = rb.width * (0.35 + 0.65 * sin(.pi * min(1, u * 1.1))) * taper
                blob(x, y, max(0.7, w / 2), front: sin(a) > 0)
            }
        }

        // drops tearing off the ribbons and falling
        var rng = SplitMix(seed: 0xD20)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        for _ in 0 ..< 70 {
            let rb = ribbons[Int(random() * Double(ribbons.count)) % ribbons.count]
            let u = 0.2 + random() * 0.7, period = 0.5 + random() * 0.6, offset = random() * period
            let life = ((age + offset).truncatingRemainder(dividingBy: period)) / period
            guard u <= easeOut(age / 0.5) * (1 - drain), age > 0.2 else { continue }
            let a = rb.angle0 + rb.turns * 2 * .pi * u + rb.spin * (t - life * period)
            if (sin(a) > 0) != (side == .inFront) { continue }
            let r = rb.radius * (0.55 + 0.6 * sin(.pi * u)) + 10 * life
            let x = cx + r * cos(a) * (1 + 0.4 * life)
            let y = ground - rb.height * u + rb.tilt * r * sin(a) + 30 * life * life
            pixel(&dark, x, y)
            if random() < 0.4 { pixel(&dark, x, y + 1) }
        }

        ctx.opacity = 0.97 * fade
        ctx.fill(dark, with: .color(Color(red: 0.3, green: 0.02, blue: 0.04)))
        ctx.fill(mid, with: .color(Color(red: 0.55, green: 0.05, blue: 0.07)))
        ctx.fill(bright, with: .color(Color(red: 0.86, green: 0.16, blue: 0.14)))
        ctx.opacity = 1
    }
}
