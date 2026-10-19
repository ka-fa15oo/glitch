import SwiftUI

/// The crimson phoenix (Character 5). It shares the brain with Wizzy and Faelis (a caster: no sword, its own arrival,
/// goodbye and sentinel moves), draws itself from four wing-flap frames (sprites from Tools/make_phoenix.py) and
/// every fire effect as art-pixel particles inside its own window.
enum Phoenix {
    static let id = "phoenix"
    static var isSelected: Bool { Prefs.d.string(forKey: Prefs.character) == id }

    /// Each frame covers the whole window canvas, so it is drawn from the padding's corner, not the sprite grid's.
    private static let frames = (1 ... 4).map { Sprite.loadShared("phoenix_flap\($0)") }
    /// RobotView's padding and canvas, copied because RobotView is main-actor and these are read off it.
    private static let padLeft = 22, padTop = 14, canvas = CGSize(width: 112, height: 124)

    /// Click area: the rest frame inside the sprite grid.
    /// shortcut: wing tips out in the window padding don't take clicks; widen `Sprite.hit` if that ever matters.
    static let hitMask: [Bool] = {
        let grid = CGRect(x: padLeft, y: padTop, width: Sprite.width, height: Sprite.height)
        return Sprite.coverage(frames[1].cropping(to: grid).map { [($0, .zero)] } ?? [])
    }()
    static let hitBounds = Sprite.bounds(of: hitMask)

    /// Arrival: embers swirl out of the ash and it bursts out of the flames at `rebirthAt`; the brain lets go at `arrivalLength`.
    static let rebirthAt = 1.4, arrivalLength = 2.8
    /// Goodbye: it burns, then crumbles to ash from `burnAt`.
    static let farewellLength = 2.8, burnAt = 1.3
    /// Idle life: every `flareEvery` s (wall clock) it spreads its wings and blazes up for `flareLength` s.
    static let flareEvery = 28.0, flareLength = 1.6

    /// Seconds per frame: a slow, heavy beat at rest, a frantic one when carried or falling.
    static func frameTime(busy: Double) -> Double { 0.2 - 0.11 * busy }

    static func flareAge(t: Double) -> Double? {
        let a = (t + 9).truncatingRemainder(dividingBy: flareEvery)
        return a < flareLength ? a : nil
    }

    /// No knightly voice: cross, startled and sad come out as its cry, happy as a burst of flame.
    static func voice(_ effect: SoundEffect) -> SoundEffect {
        switch effect {
        case .angry, .surprised, .sad: .shriek
        case .happy: .whoosh
        default: effect
        }
    }

    // MARK: - anatomy (sprite-grid art px, rest frame) and palette

    private static let centre = CGPoint(x: 35.5, y: 50)
    private static let crest = CGPoint(x: 35, y: 7)
    private static let eyes = [CGPoint(x: 33, y: 24), CGPoint(x: 38, y: 24)]
    private static let ground = 93.0

    private static let pale = Color(red: 1, green: 0.96, blue: 0.72), yellow = Color(red: 1, green: 0.8, blue: 0.2)
    private static let orange = Color(red: 1, green: 0.47, blue: 0.08), red = Color(red: 0.82, green: 0.12, blue: 0.08)
    private static let gold = Color(red: 1, green: 0.84, blue: 0.3), outline = Color(red: 0.24, green: 0.04, blue: 0.04)
    private static let smoke = Color(red: 0.45, green: 0.42, blue: 0.44), ashGrey = Color(red: 0.27, green: 0.24, blue: 0.24)

    /// 0 = white-hot ... 1 = dying deep red.
    private static func fire(_ k: Double) -> Color { k < 0.2 ? pale : k < 0.45 ? yellow : k < 0.75 ? orange : red }

    /// A steady pseudo-random 0..<1 per particle, so particles keep their paths from frame to frame.
    private static func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
        return v - floor(v)
    }

    private static func clamp(_ v: Double) -> Double { max(0, min(1, v)) }

    /// Square art pixels, snapped to the grid like the sprite.
    private struct Pixels {
        let ctx: GraphicsContext
        let unit: CGFloat
        let dx: Double, dy: Double

        func dot(_ x: Double, _ y: Double, _ color: Color, _ opacity: Double = 1, size: Double = 1) {
            guard opacity > 0.03 else { return }
            let rect = CGRect(x: (x + dx).rounded() * unit, y: (y + dy).rounded() * unit, width: size * unit, height: size * unit)
            ctx.fill(Path(rect), with: .color(color.opacity(min(1, opacity))))
        }
    }

    // MARK: - drawing

    static func draw(_ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        let busy = max(pose.carriedAmount, pose.fallAmount)
        let bx = pose.bodyDX + pose.shakeX, by = pose.bodyDY
        let body = Pixels(ctx: outer, unit: unit, dx: bx, dy: by)      // follows the bird
        let floor = Pixels(ctx: outer, unit: unit, dx: bx, dy: 0)      // stays on the ground
        let calm = busy < 0.1 && pose.misfire < 0 && pose.rebirth < 0 && pose.ash < 0
        let flare = calm ? flareAge(t: t) : nil

        var index = Int(t / frameTime(busy: busy)) % frames.count
        if let f = flare, f < 1.2 { index = 0 }                       // wings held high while it blazes
        if pose.cast >= 0, pose.cast < 0.7 { index = 0 }
        if pose.misfire >= 0, pose.misfire < 1.0 { index = 2 }       // wings sag while the flames are out

        // behind the bird
        if pose.rebirth >= 0 { ashPile(floor, t: t, amount: clamp(pose.rebirth / 0.3) * (1 - clamp((pose.rebirth - 1.8) / 0.4)), glints: pose.rebirth < rebirthAt) }
        if pose.ash >= burnAt {
            let a = pose.ash - burnAt
            ashPile(Pixels(ctx: outer, unit: unit, dx: bx + max(0, a - 1.0) * 24, dy: 0), t: t,
                    amount: clamp(a / 0.4) * (1 - clamp((a - 1.0) / 0.5)), glints: true)
        }
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: false) }
        if pose.orb >= 0 { beacon(body, t: t, age: pose.orb) }
        if pose.quake >= 0 { shockwave(floor, age: pose.quake) }

        // the bird
        var ctx = outer
        ctx.opacity = clamp(pose.reveal)
        if pose.squash > 0.01 {
            let baseline = CGPoint(x: 36, y: 94)
            ctx.translateBy(x: baseline.x * unit, y: baseline.y * unit)
            ctx.scaleBy(x: 1 + 0.14 * pose.squash, y: 1 - 0.12 * pose.squash)
            ctx.translateBy(x: -baseline.x * unit, y: -baseline.y * unit)
        }
        if abs(pose.hang) > 0.0005 {
            ctx.translateBy(x: pose.hangPivot.x * unit, y: pose.hangPivot.y * unit)
            ctx.rotate(by: .radians(pose.hang))
            ctx.translateBy(x: -pose.hangPivot.x * unit, y: -pose.hangPivot.y * unit)
        }
        if pose.misfire >= 0 {   // the flames go out: grey and dim, then it reignites
            let m = pose.misfire
            let out = m < 0.25 ? m / 0.25 : 1 - clamp((m - 0.75) / 0.5)
            ctx.addFilter(.saturation(1 - 0.95 * out))
            ctx.addFilter(.brightness(0.08 * out))
        }
        if pose.ash >= 0 {       // charring as it burns
            let c = clamp((pose.ash - 0.5) / 0.8)
            ctx.addFilter(.saturation(1 - 0.8 * c))
            ctx.addFilter(.brightness(-0.35 * c))
        }
        let rect = CGRect(x: (bx - Double(padLeft)) * unit, y: (by - Double(padTop)) * unit,
                          width: canvas.width * unit, height: canvas.height * unit)
        let image = Image(decorative: frames[index], scale: 1).interpolation(.none)
        ctx.draw(image, in: rect)

        // the bird blazing up: its own frame again, added on top
        var glow = 0.0
        if let f = flare { glow = 0.55 * sin(.pi * f / flareLength) }
        if pose.cast >= 0 { glow = max(glow, 0.6 * (1 - clamp(pose.cast / 0.8))) }
        if pose.feast >= 0 { glow = max(glow, 0.5 * (1 - clamp(pose.feast / 1.2))) }
        if pose.misfire > 0.75 { glow = max(glow, 0.45 * sin(.pi * clamp((pose.misfire - 0.75) / 0.6))) }
        if pose.rebirth >= rebirthAt { glow = max(glow, 0.8 * (1 - clamp((pose.rebirth - rebirthAt) / 0.9))) }
        if pose.ash >= 0, pose.ash < burnAt { glow = max(glow, 0.45 * clamp(pose.ash / 0.6)) }
        if glow > 0.02 {
            var g = ctx
            g.blendMode = .plusLighter
            g.opacity = glow * clamp(pose.reveal)
            g.draw(image, in: rect)
        }

        // in front of the bird
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: true) }
        if pose.reveal > 0.5, pose.ash < 0 { embers(body, t: t, busy: busy, fling: pose.fling, misfire: pose.misfire) }
        if let f = flare { burst(body, age: f, length: flareLength, count: 18, colour: nil) }
        if pose.cast >= 0 { flameRing(body, age: pose.cast) }
        if pose.orb >= 0 { glowingEyes(body, t: t) }
        if pose.feast >= 0 {
            burst(body, age: pose.feast, length: 1.2, count: 24, colour: gold)
            driftingFeather(body, t: t, age: pose.feast, slot: pose.goldSparks)
        }
        if pose.misfire >= 0 { smokePuffs(body, age: pose.misfire) }
        if pose.rebirth >= 0 { rebirth(floor, age: pose.rebirth) }
        if pose.ash >= 0 { burning(body, age: pose.ash) }
        counters(floor, t: t, gold: pose.goldSparks, waiting: pose.redSparks)
    }

    // MARK: - effects

    /// Idle: a few embers rising off the plumage. Carried or falling: a trail of them streaming behind.
    private static func embers(_ px: Pixels, t: Double, busy: Double, fling: Double, misfire: Double) {
        let count = busy > 0.1 ? 32 : 10
        let dim = misfire >= 0 ? clamp((misfire - 0.75) / 0.5) : 1
        for i in 0 ..< count {
            let period = 1.8 + hash(i, 1) * 1.6
            let a = ((t + hash(i, 2) * period) / period).truncatingRemainder(dividingBy: 1)
            let x0 = 4 + hash(i, 3) * 62, y0 = 30 + hash(i, 4) * 55
            let x = busy > 0.1 ? x0 - fling * a * 30 : x0 + sin(a * 7 + Double(i)) * 2.5
            let y = busy > 0.1 ? y0 + a * 26 : y0 - a * 38
            px.dot(x, y, fire(a), (1 - a * a) * dim, size: busy > 0.1 && i % 2 == 0 ? 2 : 1)
        }
    }

    /// Sparks flying out from the body in every direction.
    private static func burst(_ px: Pixels, age: Double, length: Double, count: Int, colour: Color?) {
        guard age < length else { return }
        let k = age / length
        for i in 0 ..< count {
            let angle = Double(i) / Double(count) * 2 * .pi + hash(i, 5) * 0.4
            let r = 14 + k * (44 + hash(i, 6) * 16)
            px.dot(centre.x + cos(angle) * r, centre.y + sin(angle) * r * 0.8, colour.map { i % 2 == 0 ? $0 : pale } ?? fire(k), 1 - k, size: 2)
            px.dot(centre.x + cos(angle) * (r - 3), centre.y + sin(angle) * (r - 3) * 0.8, colour ?? fire(k + 0.3), (1 - k) * 0.6)
        }
    }

    /// Click: a ring of fire bursting out round it.
    private static func flameRing(_ px: Pixels, age: Double) {
        guard age < 1.1 else { return }
        let k = age / 1.1
        let rx = 12 + age * 55
        for i in 0 ..< 84 {
            let a = Double(i) / 84 * 2 * .pi
            let x = centre.x + cos(a) * rx, y = centre.y + sin(a) * rx * 0.5
            px.dot(x, y, fire(k), 1 - k, size: 2)
            px.dot(centre.x + cos(a) * (rx - 3), centre.y + sin(a) * (rx - 3) * 0.5, red, (1 - k) * 0.8, size: 2)
            let h = Int(2 + hash(i, 8) * 4 * (1 - k))            // flame tongues licking up off the ring
            for j in 1 ... h { px.dot(x + (j > 2 ? 1 : 0), y - Double(j), fire(Double(j) / 6), 1 - k) }
        }
    }

    /// Landing after a drop: a ring of fire racing out over the ground.
    private static func shockwave(_ px: Pixels, age: Double) {
        let k = age / 0.9
        let rx = 6 + age * 62
        for i in 0 ..< 72 {
            let a = Double(i) / 72 * 2 * .pi
            let x = centre.x + cos(a) * rx, y = ground + sin(a) * rx * 0.16
            px.dot(x, y, fire(k), 1 - k, size: 2)
            let h = Int(2 + hash(i, 9) * 5 * (1 - k))
            for j in 1 ... max(1, h) { px.dot(x, y - Double(j), fire(Double(j) / 4), (1 - k) * 0.8) }
        }
    }

    /// A permission is waiting: a low wall of fire round its feet, flaring up on each reminder.
    private static func fireWall(_ px: Pixels, t: Double, age: Double, nudge: Double, front: Bool) {
        let grow = clamp(age / 0.5)
        let flare = nudge >= 0 ? 1 + 0.9 * sin(.pi * clamp(nudge / 0.8)) : 1
        for i in 0 ..< 48 {
            let a = Double(i) / 48 * 2 * .pi
            guard (sin(a) > 0) == front else { continue }
            let x = centre.x + cos(a) * 38, y = ground - 1 + sin(a) * 6
            px.dot(x, y, red, 0.9 * grow, size: 2)                                   // the burning ground
            let h = (5 + hash(i, 10) * 5 + 3 * sin(t * 9 + Double(i) * 1.7)) * grow * flare
            for j in 0 ..< max(1, Int(h)) {
                let k = Double(j) / max(1, h)
                px.dot(x + (k > 0.6 ? sin(t * 12 + Double(i)) : 0), y - Double(j), fire(1 - k), 0.95, size: k < 0.5 ? 2 : 1)
            }
        }
    }

    /// Claude asked a question: a beacon of flame rising from the crest.
    private static func beacon(_ px: Pixels, t: Double, age: Double) {
        let height = 30 * clamp(age / 0.4) * (0.9 + 0.1 * sin(t * 7))
        guard height >= 1 else { return }
        for j in 0 ..< Int(height) {
            let k = Double(j) / height
            let w = Int((5 - 3.6 * k + 1.0 * sin(t * 14 + Double(j) * 0.7)).rounded())
            let x = crest.x + sin(t * 6 + Double(j) * 0.3)
            for dx in 0 ..< max(1, w) { px.dot(x - Double(w) / 2 + Double(dx), crest.y - Double(j), fire(k * 0.9), 1) }
        }
        let s = (t * 1.3).truncatingRemainder(dividingBy: 1)   // a spark leaving the tip
        px.dot(crest.x + sin(t * 3) * 2, crest.y - height - s * 10, yellow, 1 - s)
    }

    private static func glowingEyes(_ px: Pixels, t: Double) {
        let pulse = 0.6 + 0.4 * sin(t * 5)
        for e in eyes {
            for dx in -1 ... 2 { for dy in -1 ... 1 where !(dy == 0 && (dx == 0 || dx == 1)) { px.dot(e.x + Double(dx), e.y + Double(dy), yellow, 0.35 * pulse) } }
            px.dot(e.x, e.y, pale); px.dot(e.x + 1, e.y, pale)
        }
    }

    /// One small golden feather (5 art px tall at scale 1).
    private static func feather(_ px: Pixels, _ x: Double, _ y: Double, _ opacity: Double = 1, scale s: Double = 1) {
        let shape: [(Double, Double, Color)] = [(0, 0, pale), (0, 1, gold), (-1, 1, yellow), (0, 2, gold), (-1, 2, orange), (0, 3, gold), (0, 4, orange)]
        for (dx, dy, _) in shape {   // a dark rim, so the gold reads against the red plumage
            for (ox, oy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { px.dot(x + (dx + ox) * s, y + (dy + oy) * s, outline, opacity, size: s) }
        }
        for (dx, dy, c) in shape { px.dot(x + dx * s, y + dy * s, c, opacity, size: s) }
    }

    /// Where the n-th finished session's golden feather rests: a column beside it, filling up from the ground.
    private static func slot(_ n: Int) -> CGPoint { CGPoint(x: 86 - Double(n / 8) * 4, y: ground - 6 - Double(n % 8) * 7) }

    /// A session finished: a golden feather drifts down from above its head into the column.
    private static func driftingFeather(_ px: Pixels, t: Double, age: Double, slot n: Int) {
        guard age > 0.3, age < 2.0 else { return }
        let k = clamp((age - 0.3) / 1.7)
        let to = slot(n), from = CGPoint(x: crest.x, y: crest.y - 8)
        let x = from.x + (to.x - from.x) * sqrt(k) + sin(k * 9) * 3 * (1 - k)
        let y = from.y - 6 * sin(.pi * min(1, k * 2)) + (to.y - from.y) * k * k
        feather(px, x, y, scale: k < 0.85 ? 2 : 1)
    }

    /// Golden feathers for finished sessions (right), little red flames for sessions waiting on the user (left).
    private static func counters(_ px: Pixels, t: Double, gold: Int, waiting: Int) {
        for n in 0 ..< min(gold, 24) {
            let p = slot(n)
            feather(px, p.x + (sin(t * 1.4 + Double(n)) * 0.6).rounded(), p.y)
        }
        for n in 0 ..< min(waiting, 16) {
            let x = -8 + Double(n / 8) * 4, y = ground - 4 - Double(n % 8) * 6
            let flick = sin(t * 11 + Double(n) * 2) > 0
            px.dot(x, y, red, size: 2); px.dot(x, y - 1, orange); px.dot(x + 1, y - (flick ? 2 : 1), yellow)
        }
    }

    /// An error: smoke rising off the extinguished plumage.
    private static func smokePuffs(_ px: Pixels, age: Double) {
        let k = age / 1.4
        for i in 0 ..< 14 {
            let x0 = 5 + hash(i, 11) * 60, y0 = 10 + hash(i, 12) * 30
            let rise = age * (14 + hash(i, 13) * 10)
            px.dot(x0 + sin(age * 3 + Double(i)) * 2, y0 - rise, i % 3 == 0 ? ashGrey : smoke, (1 - k) * 0.85, size: age > 0.6 ? 3 : 2)
        }
    }

    /// A low mound of ash on the ground, with embers glinting in it.
    private static func ashPile(_ px: Pixels, t: Double, amount: Double, glints: Bool) {
        guard amount > 0.03 else { return }
        for dx in -14 ... 14 {
            let h = Int((4.5 * (1 - pow(Double(dx) / 14, 2))).rounded())
            for dy in 0 ..< max(1, h) { px.dot(centre.x + Double(dx), ground - Double(dy), (dx + dy) % 3 == 0 ? smoke : ashGrey, amount) }
        }
        guard glints else { return }
        for i in 0 ..< 6 where sin(t * 8 + Double(i) * 2.3) > 0.2 {
            px.dot(centre.x - 10 + hash(i, 14) * 20, ground - 1 - hash(i, 15) * 2, i % 2 == 0 ? orange : yellow, amount)
        }
    }

    /// Arrival: embers spiral up out of the ash, then a pillar of flame and it bursts out.
    private static func rebirth(_ px: Pixels, age: Double) {
        if age > 0.3, age < 1.6 {
            let s = (age - 0.3) / 1.2
            for i in 0 ..< 40 {
                let u = clamp(s * 1.3 - hash(i, 16) * 0.3)
                guard u > 0, u < 1 else { continue }
                let a = u * 10 + Double(i) / 40 * 2 * .pi
                let r = 16 * (1 - u) + 3
                px.dot(centre.x + cos(a) * r, ground - 2 - u * 70, fire(1 - u), 1, size: i % 3 == 0 ? 2 : 1)
            }
        }
        if age > 1.3, age < 1.9 {
            let b = (age - 1.3) / 0.6
            for i in 0 ..< 40 {                          // a column of flame tongues shooting up out of the ash
                let u = clamp(b * 1.6 - hash(i, 23) * 0.6)
                guard u > 0, u < 1 else { continue }
                let x = centre.x + (hash(i, 24) - 0.5) * 22 * (1 - u * 0.5)
                let y = ground - 4 - u * (60 + hash(i, 25) * 30)
                px.dot(x, y, fire(u), 1 - u * u, size: u < 0.5 ? 3 : 2)
                px.dot(x, y + 3, fire(u + 0.3), (1 - u) * 0.7, size: 2)
            }
            burst(px, age: age - 1.3, length: 0.6, count: 28, colour: nil)
        }
    }

    /// Goodbye: flames climb all over it, then it crumbles and the ash falls and blows away.
    private static func burning(_ px: Pixels, age: Double) {
        let fade = age < burnAt ? clamp(age / 0.6) : 1 - clamp((age - burnAt) / 0.5)
        for i in 0 ..< 46 {
            let u = ((age + hash(i, 17) * 0.5) / 0.5).truncatingRemainder(dividingBy: 1)
            let x = 4 + hash(i, 18) * 62, y = 18 + hash(i, 19) * 70 - u * 12
            px.dot(x, y, fire(u), fade * (1 - u), size: 2)
            px.dot(x, y + 2, orange, fade * (1 - u) * 0.6, size: 2)
        }
        guard age > burnAt else { return }
        let f = age - burnAt
        for i in 0 ..< 44 {
            let x0 = 4 + hash(i, 20) * 62, y0 = 10 + hash(i, 21) * 80
            let y = min(ground, y0 + f * f * 40 + f * 12)
            px.dot(x0 + f * 20 * hash(i, 22), y, i % 3 == 0 ? smoke : ashGrey, 1 - f / 1.5)
        }
    }
}
