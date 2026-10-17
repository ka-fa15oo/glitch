import SwiftUI

/// Character 2, the cosmic mage. It shares the brain (breathing, blinking, drag, gravity) with Glitch but has its own
/// drawing: no legs or sword rig, it hovers and holds a star-tipped staff (sprites from Tools/make_mage.py).
enum Mage {
    static let id = "mage"
    static var isSelected: Bool { Prefs.d.string(forKey: Prefs.character) == id }

    private static let set = SpriteSet(prefix: "mage_")
    private static let staff = load("mage_staff")
    private static let shadow = load("mage_shadow")
    private static let neck = CGPoint(x: 40, y: 36)
    /// The far hand that holds the staff; the staff turns about it.
    private static let hand = CGPoint(x: 21.5, y: 51)
    private static let starLight = Color(red: 0.91, green: 0.90, blue: 1.0)
    private static let starGlow = Color(red: 0.50, green: 0.53, blue: 0.77)
    /// The robe in 2 px rows so its hem can ripple while gliding.
    private static let robeRows: [CGImage] = stride(from: 0, to: Sprite.height, by: 2).compactMap {
        set.tunic.cropping(to: CGRect(x: 0, y: $0, width: Sprite.width, height: 2))
    }

    static func draw(_ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        var layer = outer
        layer.opacity = max(0, min(1, pose.reveal * dustReveal(pose.dust)))
        layer.drawLayer { inner in drawBody(inner, unit: unit, size: size, t: t, pose: pose) }
        if pose.dust >= 0 { drawDust(outer, unit: unit, e: pose.dust) }
    }

    private static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    /// Teleport: gone by 0.6 s, the window jumps at 0.7 s, back in full by 1.6 s.
    private static func dustReveal(_ e: Double) -> Double {
        guard e >= 0 else { return 1 }
        return e < 0.7 ? 1 - ease(e / 0.6) : ease((e - 1.0) / 0.6)
    }

    /// The body breaks into star dust that drifts up and out, then the same motes fall back together.
    private static func drawDust(_ c: GraphicsContext, unit: CGFloat, e: Double) {
        let palette: [Color] = [starLight, starGlow, Color(red: 0.75, green: 0.38, blue: 0.62),
                                Color(red: 0.94, green: 0.85, blue: 0.56)]
        var paths = Array(repeating: Path(), count: palette.count)
        var rng = SplitMix(seed: 0x51A2)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        let out = e < 0.7
        // how far each mote is from home (0 = in place) and how bright it is
        let away = out ? ease(e / 0.75) : 1 - ease((e - 0.7) / 0.85)
        let alpha = out ? 1 - ease((e - 0.2) / 0.5) : ease((e - 0.7) / 0.3) * (1 - ease((e - 1.4) / 0.25))
        for i in 0 ..< 46 {
            let home = CGPoint(x: 28 + random() * 26, y: 6 + random() * 80)
            let a = random() * 2 * .pi, dist = 10 + random() * 18
            let x = (home.x + cos(a) * dist * away).rounded()
            let y = (home.y + sin(a) * dist * away - 10 * away).rounded()
            paths[i % palette.count].addRect(CGRect(x: x * unit, y: y * unit, width: unit, height: unit))
        }
        var c = c
        c.opacity = alpha
        for (path, color) in zip(paths, palette) { c.fill(path, with: .color(color)) }
    }

    private static func drawBody(_ base: GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        let breath = sin(t * 2 * .pi / 3.6)
        // glides a few pixels above the ground, bobbing slowly; carried or falling it just follows the brain
        let grounded = 1 - max(pose.carriedAmount, pose.fallAmount)
        let hover = (-2 + sin(t * 2 * .pi / 3.2) * 1.2) * grounded
        let bx = pose.bodyDX + pose.shakeX, by = pose.bodyDY + hover

        func put(_ image: CGImage, _ c: GraphicsContext, dx: Double = 0, dy: Double = 0,
                 angle: Double = 0, pivot: CGPoint = .zero) {
            var c = c
            c.translateBy(x: (bx + dx) * unit, y: (by + dy) * unit)
            if angle != 0 {
                c.translateBy(x: pivot.x * unit, y: pivot.y * unit)
                c.rotate(by: .radians(angle))
                c.translateBy(x: -pivot.x * unit, y: -pivot.y * unit)
            }
            c.draw(Image(decorative: image, scale: 1).interpolation(.none), in: CGRect(origin: .zero, size: size))
        }
        func rows(_ list: [CGImage], _ c: GraphicsContext, amount: Double, speed: Double) {
            for (i, row) in list.enumerated() {
                let y = Double(i * 2)
                let k = max(0, (y - 40) / 50)
                let dx = (sin(t * speed - k * 3 + Double(i) * 0.15) * amount * k * k).rounded()
                let rect = CGRect(x: (bx + dx) * unit, y: (y + by) * unit, width: size.width, height: 2 * unit + 0.6)
                c.draw(Image(decorative: row, scale: 1).interpolation(.none), in: rect)
            }
        }

        // the shadow stays on the ground and shrinks a little as the mage rises
        var ground = base
        ground.opacity = 0.7 + 0.3 * (hover + 3.2) / 2.4
        ground.draw(Image(decorative: shadow, scale: 1).interpolation(.none),
                    in: CGRect(x: bx * unit, y: 0, width: size.width, height: size.height))

        var ctx = base
        if pose.squash > 0.01 {
            let baseline = CGPoint(x: 40, y: 94)
            ctx.translateBy(x: baseline.x * unit, y: baseline.y * unit)
            ctx.scaleBy(x: 1 + 0.14 * pose.squash, y: 1 - 0.12 * pose.squash)
            ctx.translateBy(x: -baseline.x * unit, y: -baseline.y * unit)
        }
        if abs(pose.hang) > 0.0005 {
            ctx.translateBy(x: pose.hangPivot.x * unit, y: pose.hangPivot.y * unit)
            ctx.rotate(by: .radians(pose.hang))
            ctx.translateBy(x: -pose.hangPivot.x * unit, y: -pose.hangPivot.y * unit)
        }

        // now and then, while it floats still, it draws a constellation with the staff tip
        let calm = (1 - pose.stepAmount) * (1 - pose.carriedAmount) * (1 - pose.fallAmount)
        let sky = Constellation(t: t)
        let staffMove = sky?.staff ?? (angle: 0, lift: 0)
        if let sky, calm > 0.01 {
            var c = base
            c.opacity = calm
            sky.draw(c, unit: unit, dx: bx)
        }

        let flutter = 2.2 + 3 * pose.carriedAmount + 4 * pose.fallAmount
        rows(set.capeRows, ctx, amount: flutter, speed: 2 * .pi / 2.6)
        rows(robeRows, ctx, amount: 1.4 + flutter * 0.4, speed: 2 * .pi / 1.8)
        let staffLift = staffMove.lift * calm
        put(staff, ctx, dy: breath * 0.3 + staffLift, angle: staffMove.angle * calm, pivot: hand)
        put(set.armFarUpper, ctx, dy: breath * 0.5 + staffLift * 0.3)
        put(set.armFarFore, ctx, dy: breath * 0.4 + staffLift)
        put(set.cloak, ctx, dy: breath * 0.5)

        let headDY = breath * 0.8 + pose.headDY
        put(set.head, ctx, dy: headDY, angle: pose.headRot, pivot: neck)
        if let eyes = set.eyes[pose.eyes] {
            put(eyes, ctx, dx: Double(pose.eyeDX), dy: headDY, angle: pose.headRot, pivot: neck)
        }
        put(set.armNearUpper, ctx, dy: breath * 0.5)
        put(set.armNearFore, ctx, dy: breath * 0.5)
    }

    /// One showing: the staff tip visits a few points in the air, leaving a star at each, then lines join them
    /// and the figure fades. Every showing has its own shape (seeded by which showing it is).
    private struct Constellation {
        static let period = 70.0, length = 9.0
        static let tip = CGPoint(x: 18, y: 2.5)     // the gold star on the staff sprite

        let e: Double
        let stars: [(angle: Double, lift: Double, at: CGPoint)]

        init?(t: Double) {
            let k = (t / Self.period).rounded(.down)
            e = t - k * Self.period
            guard e < Self.length else { return nil }
            var rng = SplitMix(seed: UInt64(truncatingIfNeeded: Int64(k)) &* 0x2545_F491)
            func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
            var angle = -0.8 + random() * 0.15
            var list: [(Double, Double, CGPoint)] = []
            for _ in 0 ..< 4 + Int(rng.next() % 3) {
                let lift = -10 + random() * 14
                let r = CGPoint(x: Self.tip.x - hand.x, y: Self.tip.y - hand.y)
                let p = CGPoint(x: hand.x + r.x * cos(angle) - r.y * sin(angle),
                                y: hand.y + r.x * sin(angle) + r.y * cos(angle) + lift)
                list.append((angle, lift, CGPoint(x: p.x.rounded(), y: p.y.rounded())))
                angle = min(0.35, angle + 0.15 + random() * 0.15)
            }
            stars = list
        }

        private func placed(_ i: Int) -> Double { 0.5 + Double(i) * 0.8 }
        private var linesStart: Double { placed(stars.count - 1) + 0.6 }
        private static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

        /// Where the staff points right now: through each star in turn, then back to rest.
        var staff: (angle: Double, lift: Double) {
            var keys = [(at: 0.0, angle: 0.0, lift: 0.0)]
            for (i, s) in stars.enumerated() { keys.append((placed(i), s.angle, s.lift)) }
            keys.append((placed(stars.count - 1) + 1.0, 0, 0))
            for (a, b) in zip(keys, keys.dropFirst()) where e < b.at {
                let k = Self.ease((e - a.at) / (b.at - a.at))
                return (a.angle + (b.angle - a.angle) * k, a.lift + (b.lift - a.lift) * k)
            }
            return (0, 0)
        }

        func draw(_ c: GraphicsContext, unit: CGFloat, dx: Double) {
            var c = c
            c.opacity *= 1 - Self.ease((e - 7.4) / 1.6)
            var line = Path(), core = Path(), glow = Path()
            func px(_ p: inout Path, _ x: Double, _ y: Double) {
                p.addRect(CGRect(x: (x + dx) * unit, y: y * unit, width: unit, height: unit))
            }
            // lines, one after another, every other pixel so they stay faint
            for i in 0 ..< max(0, stars.count - 1) {
                let k = Self.ease((e - linesStart - Double(i) * 0.35) / 0.35)
                guard k > 0 else { break }
                let a = stars[i].at, b = stars[i + 1].at
                let n = Int(max(abs(b.x - a.x), abs(b.y - a.y)) * k)
                for j in stride(from: 2, to: n - 1, by: 2) {
                    let u = Double(j) / max(abs(b.x - a.x), abs(b.y - a.y))
                    px(&line, (a.x + (b.x - a.x) * u).rounded(), (a.y + (b.y - a.y) * u).rounded())
                }
            }
            for (i, s) in stars.enumerated() where e >= placed(i) {
                px(&core, s.at.x, s.at.y)
                // a brief flash as the star is set, then a slow twinkle
                let flash = 1 - (e - placed(i)) / 0.4
                if flash > 0 || sin(e * 3 + Double(i) * 2.1) > 0.6 {
                    for (ox, oy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { px(&glow, s.at.x + ox, s.at.y + oy) }
                }
            }
            var faint = c
            faint.opacity *= 0.75
            faint.fill(line, with: .color(starGlow))
            c.fill(glow, with: .color(starGlow))
            c.fill(core, with: .color(starLight))
        }
    }

    private static func load(_ name: String) -> CGImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { fatalError("Missing sprite \(name).png") }
        return cg
    }
}
