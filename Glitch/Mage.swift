import SwiftUI

/// Wizzy, the cosmic mage (Character 2). It shares the brain (breathing, blinking, drag, gravity) with Glitch but has its own
/// drawing: no legs or sword rig, it hovers and holds a star-tipped staff (sprites from Tools/make_mage.py).
enum Mage {
    static let id = "mage"
    static var isSelected: Bool { Prefs.d.string(forKey: Prefs.character) == id }

    private static let set = SpriteSet(prefix: "mage_")
    private static let staff = load("mage_staff")
    /// Click area: every part at rest, raised by the 2 px it hovers on average.
    static let hitMask: [Bool] = Sprite.coverage(
        [set.cape, set.tunic, set.cloak, set.armFarUpper, set.armFarFore, set.armNearUpper, set.armNearFore,
         set.head, staff].map { ($0, CGPoint(x: 0, y: -2)) })
    static let hitBounds = Sprite.bounds(of: hitMask)
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
        layer.opacity = max(0, min(1, pose.reveal * dustReveal(pose.dust) * (1 - pow(pose.vortex, 3))))
        layer.drawLayer { inner in
            var inner = inner
            if pose.vortex > 0.001 {
                // being pulled into the black hole: it turns about its middle and shrinks to nothing
                let c = CGPoint(x: 40 * unit, y: 56 * unit)
                inner.translateBy(x: c.x, y: c.y)
                inner.rotate(by: .radians(pose.vortex * 4.5 * .pi))
                let s = 1 - 0.95 * pose.vortex * pose.vortex
                inner.scaleBy(x: s, y: s * (1 + 0.4 * pose.vortex))      // a little stretched as it goes in
                inner.translateBy(x: -c.x, y: -c.y)
            }
            drawBody(inner, unit: unit, size: size, t: t, pose: pose)
        }
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
        var staffMove = sky?.staff ?? (angle: 0, lift: 0)
        // clicked: the staff goes up and forward while the shooting star leaves its tip
        if pose.cast >= 0 {
            let k = ease(pose.cast / 0.3) * (1 - ease((pose.cast - 1.0) / 0.5))
            staffMove.angle += castAngle * k
            staffMove.lift += castLift * k
        }
        // finished: the staff goes up for the spell; error: it jerks back as the spell misfires
        if pose.feast >= 0 {
            let k = ease(pose.feast / 0.3) * (1 - ease((pose.feast - 1.6) / 0.5))
            staffMove.angle += castAngle * k
            staffMove.lift += castLift * k
        }
        if pose.misfire >= 0 {
            let k = ease(pose.misfire / 0.08) * (1 - ease((pose.misfire - 0.15) / 0.45))
            staffMove.angle += 0.22 * k
            staffMove.lift += 2 * k
        }
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

        // sentinel overlays, all following the floating body
        var tip = Self.staffTip(angle: staffMove.angle * calm, lift: staffLift)
        tip.x += bx; tip.y += by + breath * 0.3
        let marks = Marks(unit: unit)
        if pose.rune >= 0 { marks.rune(ctx, at: CGPoint(x: bx + 6, y: by + 38 + sin(t * 2.2) * 1.2), age: pose.rune, nudge: pose.nudge, t: t) }
        if pose.orb >= 0 { marks.orb(ctx, at: CGPoint(x: bx + 52, y: by + 53 + breath * 0.5), age: pose.orb, t: t) }
        if pose.feast >= 0 { marks.feast(ctx, from: tip, e: pose.feast, landing: Self.sparkSlot(pose.redSparks + pose.goldSparks, tip: tip)) }
        if pose.misfire >= 0 { marks.misfire(ctx, from: tip, e: pose.misfire) }
        marks.counters(ctx, around: tip, red: pose.redSparks, gold: pose.goldSparks, t: t)
    }

    /// The finished spell runs this long; its gold star lands among the counters at `feastSettles`.
    static let feastLength = 3.2, feastSettles = 2.0, misfireLength = 1.4

    /// The staff's star tip for a staff turned by `angle` about the hand and raised by `lift` (sprite px).
    private static func staffTip(angle: Double, lift: Double) -> CGPoint {
        let r = CGPoint(x: Constellation.tip.x - hand.x, y: Constellation.tip.y - hand.y)
        return CGPoint(x: hand.x + r.x * cos(angle) - r.y * sin(angle), y: hand.y + r.x * sin(angle) + r.y * cos(angle) + lift)
    }

    /// Where the `i`-th waiting/finished star sits: a small arc above the staff tip, wrapping to a second row.
    private static func sparkSlot(_ i: Int, tip: CGPoint) -> CGPoint {
        let row = i / 7, k = Double(i % 7)
        let a = -.pi * (0.92 - k * 0.14), r = 7.0 + Double(row) * 4
        return CGPoint(x: (tip.x + cos(a) * r).rounded(), y: (tip.y + 1 + sin(a) * r).rounded())
    }

    /// Pixel drawings for the sentinel: the permission rune, the crystal ball, the finished star feast,
    /// the misfire puff and the red/gold counter stars.
    private struct Marks {
        let unit: CGFloat
        static let red = Color(red: 0.95, green: 0.28, blue: 0.27), redDim = Color(red: 0.42, green: 0.06, blue: 0.1)
        static let gold = Color(red: 0.96, green: 0.82, blue: 0.43), goldDim = Color(red: 0.52, green: 0.38, blue: 0.12)
        static let pink = Color(red: 0.92, green: 0.5, blue: 0.8), violet = Color(red: 0.46, green: 0.25, blue: 0.64)
        static let smoke = Color(red: 0.5, green: 0.5, blue: 0.56)
        /// A small rune, drawn as strings of pixels (# = lit).
        static let glyph = ["....#....", "...###...", "..#.#.#..", ".#..#..#.", "....#....",
                            "....#....", "...#.#...", "..#...#..", ".#.....#.", "#.......#"]

        func px(_ p: inout Path, _ x: Double, _ y: Double, _ size: Double = 1) {
            p.addRect(CGRect(x: x.rounded() * unit, y: y.rounded() * unit, width: size * unit, height: size * unit))
        }

        /// Permission: a red rune hangs in the air in front of Wizzy, pulsing slowly; a reminder flares it once.
        func rune(_ c: GraphicsContext, at center: CGPoint, age: Double, nudge: Double, t: Double) {
            var core = Path(), glow = Path()
            let x0 = center.x - 4, y0 = center.y - 5
            for (y, line) in Self.glyph.enumerated() {
                for (x, ch) in line.enumerated() where ch == "#" {
                    px(&core, x0 + Double(x), y0 + Double(y))
                    for (ox, oy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { px(&glow, x0 + Double(x) + ox, y0 + Double(y) + oy) }
                }
            }
            let flare = nudge >= 0 ? sin(.pi * min(1, nudge / 0.8)) : 0
            var c = c
            c.opacity *= ease(age / 0.6) * (0.75 + 0.25 * sin(t * 2.6)) + flare * 0.3
            var halo = c
            halo.opacity *= 0.55 + 0.45 * flare
            halo.fill(glow, with: .color(Self.redDim))
            c.fill(core, with: .color(Self.red))
            if flare > 0.05 {                                       // the reminder: a ring of sparks bursts out once
                var ring = Path()
                let r = 6 + 6 * min(1, nudge / 0.8)
                for i in 0 ..< 10 { let a = Double(i) / 10 * 2 * .pi; px(&ring, center.x + cos(a) * r, center.y + sin(a) * r) }
                var rc = c
                rc.opacity = flare
                rc.fill(ring, with: .color(Self.red))
            }
        }

        /// Question: a small crystal ball glows above the near hand, a spark circling inside it.
        func orb(_ c: GraphicsContext, at center: CGPoint, age: Double, t: Double) {
            var body = Path(), rim = Path(), halo = Path(), core = Path(), glint = Path()
            for y in -6 ... 6 { for x in -6 ... 6 {
                let d = Double(x * x + y * y), p = (center.x + Double(x), center.y + Double(y))
                if d <= 12 { px(&body, p.0, p.1) } else if d <= 20 { px(&rim, p.0, p.1) }
                else if d <= 30, (x + y) % 2 == 0 { px(&halo, p.0, p.1) }
            } }
            px(&core, center.x - 2, center.y - 2, 2)
            let a = t * 2.4
            px(&glint, center.x + cos(a) * 2.5, center.y + sin(a) * 1.5)
            var c = c
            c.opacity *= ease(age / 0.5)
            var glow = c
            glow.opacity *= 0.6 + 0.4 * sin(t * 3)
            glow.fill(halo, with: .color(Self.pink.opacity(0.7)))
            c.fill(rim, with: .color(Self.violet))
            c.fill(body, with: .color(Color(red: 0.74, green: 0.62, blue: 0.95)))
            c.fill(core, with: .color(Self.pink))
            c.fill(glint, with: .color(.white))
        }

        /// Finished: a burst of stars leaves the raised staff and drifts down twinkling; one gold star flies to its place.
        func feast(_ c: GraphicsContext, from tip: CGPoint, e: Double, landing: CGPoint) {
            let palette = [Color.white, Self.gold, Self.pink, Color(red: 0.75, green: 0.8, blue: 1)]
            var paths = Array(repeating: Path(), count: palette.count)
            var rng = SplitMix(seed: 0xFEA57)
            func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
            let b = e - 0.35                                        // the burst leaves once the staff is up
            if b >= 0 {
                for i in 0 ..< 70 {
                    let a = random() * 2 * .pi, speed = 40 + random() * 60, delay = random() * 0.3
                    let s = max(0, b - delay)
                    let out = speed * (1 - exp(-s * 3.5)) / 3.5      // bursts out and slows down
                    let x = tip.x + cos(a) * out, y = tip.y + sin(a) * out * 0.8 + 9 * s * s   // then rains down
                    let twinkle = sin(s * 11 + Double(i) * 1.3) > -0.4
                    if s > 0, s < 2.7 - random() * 0.7, twinkle { px(&paths[i % palette.count], x, y, i % 3 == 0 ? 2 : 1) }
                }
            }
            if e > 0.2, e < 0.7 {                                  // a flash on the tip as the spell is cast
                let r = 1 + 4 * ease((e - 0.2) / 0.3)
                for k in 0 ..< 8 {
                    let a = Double(k) / 8 * 2 * .pi
                    for j in 0 ... Int(r) { px(&paths[k % 2 == 0 ? 0 : 1], tip.x + cos(a) * Double(j), tip.y + sin(a) * Double(j)) }
                }
            }
            var c = c
            c.opacity *= 1 - ease((e - 2.6) / 0.6)
            for (path, color) in zip(paths, palette) { c.fill(path, with: .color(color)) }
            if e > 1.2, e < Mage.feastSettles {                      // the gold star of this session flies to the others
                let k = ease((e - 1.2) / (Mage.feastSettles - 1.2))
                var star = Path()
                px(&star, tip.x + (landing.x - tip.x) * k, tip.y + (landing.y - tip.y) * k - 4 * sin(.pi * k))
                c.opacity = 1
                c.fill(star, with: .color(Self.gold))
            }
        }

        /// Error: the spell sputters out of the staff as a grey puff with a few red sparks dropping out of it.
        func misfire(_ c: GraphicsContext, from tip: CGPoint, e: Double) {
            var puff = Path(), sparks = Path()
            var rng = SplitMix(seed: 0x0F12)
            func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
            let grow = ease(e / 0.3)
            for i in 0 ..< 46 {
                let a = random() * 2 * .pi, r = (1 + random() * 8) * grow
                px(&puff, tip.x + cos(a) * r, tip.y + sin(a) * r * 0.75 - 7 * e, i % 4 == 0 ? 2 : 1)
            }
            for i in 0 ..< 10 {
                let vx = (random() - 0.5) * 30, vy = -6 - random() * 10, s = e - 0.04
                if s > 0, Int(s * 20 + Double(i)) % 3 != 0 { px(&sparks, tip.x + vx * s, tip.y + vy * s + 30 * s * s) }
            }
            var c = c
            c.opacity *= 1 - ease((e - 0.7) / 0.7)
            var fog = c
            fog.opacity *= 0.8
            fog.fill(puff, with: .color(Self.smoke))
            c.fill(sparks, with: .color(Self.red))
        }

        /// The counts: red stars for sessions waiting on the user, then gold ones for finished sessions.
        func counters(_ c: GraphicsContext, around tip: CGPoint, red: Int, gold: Int, t: Double) {
            var redCore = Path(), redGlow = Path(), goldCore = Path(), goldGlow = Path()
            for i in 0 ..< min(red + gold, 14) {
                let p = Mage.sparkSlot(i, tip: tip)
                let isRed = i < red
                let bob = (sin(t * 2 + Double(i) * 0.9) * 0.6).rounded()
                if isRed { px(&redCore, p.x, p.y + bob) } else { px(&goldCore, p.x, p.y + bob) }
                if sin(t * 3.1 + Double(i) * 1.7) > 0.2 {           // each one twinkles on its own
                    for (ox, oy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] {
                        if isRed { px(&redGlow, p.x + ox, p.y + bob + oy) } else { px(&goldGlow, p.x + ox, p.y + bob + oy) }
                    }
                }
            }
            c.fill(redGlow, with: .color(Self.redDim))
            c.fill(goldGlow, with: .color(Self.goldDim))
            c.fill(redCore, with: .color(Self.red))
            c.fill(goldCore, with: .color(Self.gold))
        }
    }

    /// One showing: the staff tip visits a few points in the air, leaving a star at each, then lines join them
    /// and the figure fades. Every showing has its own shape (seeded by which showing it is).
    private struct Constellation {
        static let period = 70.0, length = 9.0
        static let tip = CGPoint(x: 18, y: 4)     // the gold star on the staff sprite

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

    private static let castAngle = -0.25, castLift = -9.0

    /// Where the raised staff's tip is, in points from the pet window's top-left.
    @MainActor private static func castTip(facingRight: Bool) -> CGPoint {
        let r = CGPoint(x: Constellation.tip.x - hand.x, y: Constellation.tip.y - hand.y)
        let x = hand.x + r.x * cos(castAngle) - r.y * sin(castAngle)
        let y = hand.y + r.x * sin(castAngle) + r.y * cos(castAngle) + castLift
        let px = (Double(RobotView.padLeft) + x) * RobotView.scale
        return CGPoint(x: facingRight ? RobotView.canvasSize.width - px : px,
                       y: (Double(RobotView.padTop) + y) * RobotView.scale)
    }

    /// When the current constellation's first star is set (wall clock, as the view draws it); nil when none is up.
    static func constellationStart(at t: Double = Date.timeIntervalSinceReferenceDate) -> Double? {
        let start = (t / Constellation.period).rounded(.down) * Constellation.period
        return t - start < Constellation.length ? start : nil
    }

    @MainActor private static var streak: NSWindow?

    /// A see-through, click-through window over the whole screen for the shooting star; it closes itself.
    @MainActor static func shootingStar(windowOrigin: CGPoint, facingRight: Bool) {
        let tip = castTip(facingRight: facingRight)
        let onScreen = CGPoint(x: windowOrigin.x + tip.x, y: windowOrigin.y + RobotView.canvasSize.height - tip.y)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(onScreen) }) ?? NSScreen.main else { return }
        let frame = screen.frame
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let start = CGPoint(x: onScreen.x - frame.minX, y: frame.maxY - onScreen.y)
        window.contentView = NSHostingView(rootView: ShootingStar(start: start, facingRight: facingRight,
                                                                  unit: RobotView.scale))
        streak?.close()
        streak = window
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + ShootingStar.length) {
            window.close()
            if streak === window { streak = nil }
        }
    }

    /// A small star that leaves the staff tip once it is raised and streaks up and forward, trailing light.
    struct ShootingStar: View {
        static let delay = 0.3, flight = 1.2
        static var length: Double { delay + flight + 0.1 }
        let start: CGPoint          // view coordinates, y down
        let facingRight: Bool
        let unit: CGFloat
        var fixedAge: Double?
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge {
                canvas(age: fixedAge)
            } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        private func canvas(age: Double) -> some View {
            Canvas { c, _ in
                let e = age - Self.delay
                guard e >= 0, e < Self.flight else { return }
                let dir = CGPoint(x: facingRight ? 0.94 : -0.94, y: -0.34)
                let travel = 1100 * e * (1 - 0.25 * e)                 // eases off a little as it goes
                var c = c
                c.opacity = 1 - ease((e - 0.75) / 0.45)
                for i in stride(from: 15, through: 0, by: -1) {
                    let back = Double(i) * 5 * unit / 2
                    let p = CGPoint(x: start.x + dir.x * (travel - back), y: start.y + dir.y * (travel - back))
                    let size = (i < 2 ? 2 : 1) * unit
                    let rect = CGRect(x: (p.x / unit).rounded() * unit, y: (p.y / unit).rounded() * unit,
                                      width: size, height: size)
                    let color = i == 0 ? Color(red: 1, green: 0.95, blue: 0.75) : (i < 5 ? starLight : starGlow)
                    var layer = c
                    layer.opacity *= 1 - Double(i) / 16
                    layer.fill(Path(rect), with: .color(color))
                }
            }
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
