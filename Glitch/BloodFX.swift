import SwiftUI

/// Dark, heavy blood drawn as a pixel fluid (three tones plus a thin highlight), after the look of Fluid FX.
/// Arrival: a column of blood rises from the feet, crests at the head and sinks away.
/// Goodbye (`hold`): blood wells out of the ground and spreads into a pool the character sinks into.
enum BloodFX {
    private static let dark = Color(red: 0.24, green: 0.02, blue: 0.05)
    private static let body = Color(red: 0.42, green: 0.04, blue: 0.07)
    private static let mid = Color(red: 0.62, green: 0.08, blue: 0.09)
    private static let light = Color(red: 0.84, green: 0.16, blue: 0.14)

    private static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    /// Cheap smooth noise in about -1...1; slow in time so the surface looks heavy.
    private static func noise(_ x: Double, _ y: Double, _ t: Double) -> Double {
        0.5 * sin(x * 0.55 + t * 1.3 + sin(y * 0.4)) + 0.5 * sin(y * 0.8 - t * 1.0 + x * 0.25)
    }

    private struct Layers {
        var dark = Path(), body = Path(), mid = Path(), light = Path()
        mutating func add(_ tone: Int, _ x: Int, _ y: Int, unit: CGFloat) {
            let r = CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit)
            switch tone {
            case 0: dark.addRect(r)
            case 1: body.addRect(r)
            case 2: mid.addRect(r)
            default: light.addRect(r)
            }
        }
    }

    static func draw(_ ctx: inout GraphicsContext, unit: CGFloat, age: Double, hold: Bool, t: Double) {
        var layers = Layers()
        var opacity = 0.97
        if hold {
            pool(&layers, unit: unit, age: age, t: t)
        } else {
            opacity *= rise(&layers, unit: unit, age: age, t: t)
        }
        ctx.opacity = opacity
        ctx.fill(layers.dark, with: .color(dark))
        ctx.fill(layers.body, with: .color(body))
        ctx.fill(layers.mid, with: .color(mid))
        ctx.fill(layers.light, with: .color(light))
        ctx.opacity = 1
    }

    // MARK: - arrival

    /// Returns an opacity multiplier so the last bit of blood thins out instead of popping off.
    private static func rise(_ l: inout Layers, unit: CGFloat, age: Double, t: Double) -> Double {
        let ground = 94.0
        let up = ease(age / 1.5)                 // climbs
        let down = ease((age - 1.6) / 0.9)       // sinks back, leaving the character
        let height = 66 * up * (1 - down)
        if height < 0.5 { return age > 1.6 ? 0 : 1 }
        for y in Int(ground - height - 6) ... 97 {
            for x in 8 ... 70 {
                let fx = Double(x), fy = Double(y)
                let halfWidth = 21 + 3 * sin(fy * 0.22 + t * 1.6)
                let off = abs(fx - 38) / halfWidth
                if off > 1 { continue }
                // the crest is a heavy dome with a slow wobble
                let top = ground - height + off * off * 9 + 2.2 * noise(fx, fy, t)
                if fy < top || fy > 97 { continue }
                let depth = fy - top
                let rim = off > 0.88 || (age > 1.6 && fy > ground - 2)
                var tone = depth < 1.3 ? 3 : depth < 3.4 ? 2 : depth < 9 ? 1 : 0
                if noise(fx * 1.7, fy * 0.9, t * 0.8) > 0.82, tone > 0 { tone -= 1 }   // viscous streaks
                if rim, tone > 0 { tone -= 1 }
                l.add(tone, x, y, unit: unit)
            }
        }
        // heavy drops thrown up off the crest
        if up > 0.15, down < 0.6 {
            for i in 0 ..< 7 {
                let phase = (age * 0.9 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                let x = 38 + (Double(i) - 3) * 6.5 + 2 * sin(Double(i) * 2.3)
                let y = ground - height - 2 - 14 * sin(.pi * phase)
                l.add(3, Int(x), Int(y), unit: unit)
                l.add(2, Int(x), Int(y) + 1, unit: unit)
            }
        }
        return 1
    }

    // MARK: - goodbye

    private static func pool(_ l: inout Layers, unit: CGFloat, age: Double, t: Double) {
        let spread = ease(age / 1.8)
        if spread < 0.01 { return }
        let rx = 5 + 31 * spread, ry = 1.6 + 6.5 * spread
        let cx = 38.0, cy = 92.5
        // a short welling-up lump in the middle while it starts to spread
        let lump = 5 * (1 - ease((age - 0.2) / 0.9)) * ease(age / 0.3)
        for y in Int(cy - ry - lump - 3) ... 99 {
            for x in Int(cx - rx - 3) ... Int(cx + rx + 3) {
                let fx = Double(x), fy = Double(y)
                let dx = (fx - cx) / rx, dy = (fy - cy) / ry
                let edge = 1 + 0.16 * noise(fx, fy, t)
                let r2 = dx * dx + dy * dy
                var inside = r2 < edge
                var tone: Int
                if inside {
                    let r = r2.squareRoot()
                    let ripple = sin(r * 7 + noise(fx, fy, 0) * 1.6 - t * 1.4) > 0.93   // few, uneven ripples
                    tone = r > 0.8 ? 0 : r > 0.35 ? 1 : 2
                    if ripple, r < 0.8 { tone = min(3, tone + 1) }
                    if noise(fx * 1.3, fy * 2.1, t * 0.7) > 0.88 { tone = min(3, tone + 1) }   // glossy spots
                } else if lump > 0.5, abs(fx - cx) < 6 - (cy - fy) * 0.5, fy < cy, fy > cy - lump {
                    inside = true
                    tone = fy < cy - lump + 1.5 ? 3 : 1
                } else {
                    continue
                }
                l.add(tone, x, y, unit: unit)
            }
        }
    }
}
