import SwiftUI

/// The crimson phoenix (Character 5). It shares the brain with Wizzy and Faelis (a caster: no sword, its own arrival,
/// goodbye and sentinel moves) but flies where the others walk: it hangs in the air beating its wings, sweeps over the
/// screen gliding on them, and now and then perches at the bottom. It draws itself from nine 3/4-view frames cut out of
/// a Canva AI pose sheet (Tools/make_phoenix.py) and every fire effect as art-pixel particles inside its own window.
enum Phoenix {
    static let id = "phoenix"
    static var isSelected: Bool { Prefs.d.string(forKey: Prefs.character) == id }

    /// Each frame covers the whole window canvas, so it is drawn from the padding's corner, not the sprite grid's.
    private static let flaps = (1 ... 6).map { Sprite.loadShared("phoenix_flap\($0)") }
    private static let glide = Sprite.loadShared("phoenix_glide"), hover = Sprite.loadShared("phoenix_hover")
    private static let perch = Sprite.loadShared("phoenix_perch")
    /// RobotView's padding and canvas, copied because RobotView is main-actor and these are read off it.
    private static let padLeft = 22, padTop = 14, canvas = CGSize(width: 112, height: 124)

    /// Click area: the flying, the wings-spread and the perched bird inside the sprite grid.
    /// shortcut: wing tips out in the window padding don't take clicks; widen `Sprite.hit` if that ever matters.
    static let hitMask: [Bool] = {
        let grid = CGRect(x: padLeft, y: padTop, width: Sprite.width, height: Sprite.height)
        return Sprite.coverage([flaps[0], hover, perch].compactMap { $0.cropping(to: grid).map { ($0, CGPoint.zero) } })
    }()
    static let hitBounds = Sprite.bounds(of: hitMask)

    /// Arrival (`pose.rebirth` = seconds in): it swoops down onto its spot, then rears up and breathes a torrent of fire
    /// from `breathAt` for `breathLength` s; the brain lets go at `arrivalLength`.
    static let swoopLength = 1.1, breathAt = 1.1, breathLength = 1.8, arrivalLength = 3.3
    /// Goodbye (`pose.ash` = seconds in): it folds its wings and gathers its fire, bursts at `burstAt`, and shoots
    /// straight up off the screen.
    static let burstAt = 0.9, farewellLength = 2.0
    /// A click: it breathes a short gout of fire.
    static let clickBreath = 0.9
    /// Idle life: every `flareEvery` s (wall clock) it blazes up for `flareLength` s.
    static let flareEvery = 28.0, flareLength = 1.6

    /// Seconds per frame of the six-frame beat: slow, heavy strokes in flight, frantic when carried.
    static func frameTime(busy: Double) -> Double { 0.11 - 0.06 * busy }
    /// The slower beat that holds it in the air while it hangs in one place.
    static let hoverFrameTime = 0.16

    /// Which frame it shows: a wing beat, the glide, the wings spread, or folded on the perch.
    private static func frame(t: Double, busy: Double, pose: Brain.Pose) -> CGImage {
        func beat(_ step: Double) -> CGImage { flaps[Int(t / step) % flaps.count] }
        if busy > 0.1 { return beat(frameTime(busy: busy)) }
        if pose.ash >= 0 { return perch }                       // wings folded tight for the burst and the climb
        if pose.rebirth >= 0 {                                  // swoops in beating hard, rears up to breathe fire, settles
            return pose.rebirth < swoopLength ? beat(0.06) : pose.rebirth < breathAt + breathLength ? hover : perch
        }
        let flying = pose.aloft > 0.5 && !pose.hovering
        if flying { return pose.beat > 0.5 ? beat(frameTime(busy: 0)) : glide }
        if pose.cast >= 0, pose.cast < clickBreath { return hover }   // rears up to breathe fire
        if pose.misfire >= 0 { return pose.aloft > 0.5 ? glide : perch }   // flames out: wings held still
        if pose.aloft > 0.5 { return beat(hoverFrameTime) }
        if pose.aloft > 0.15 { return flaps[3] }               // wings sweeping in to land or out to take off
        return perch
    }

    static func flareAge(t: Double) -> Double? {
        let a = (t + 9).truncatingRemainder(dividingBy: flareEvery)
        return a < flareLength ? a : nil
    }

    /// None of the knight's voice: cross and startled come out as its cry, sad as its flames sinking, every knightly
    /// chirp, tick or thud as fire.
    static func voice(_ effect: SoundEffect) -> SoundEffect {
        switch effect {
        case .angry, .surprised: .shriek
        case .sad: .smother
        case .happy, .thud, .tick, .glitch: .whoosh
        case .wake, .farewell: .ignite
        default: effect
        }
    }

    // MARK: - anatomy (sprite-grid art px, airborne frames) and palette

    private static let centre = CGPoint(x: 28, y: 46)
    private static let crest = CGPoint(x: 19, y: 14)
    private static let eyes = [CGPoint(x: 16, y: 23)]   // 3/4 view: one eye shows
    /// The perched frame's head sits this much lower than the airborne frames'.
    private static let perchDrop = 20.0
    private static let ground = 90.0

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
        let flying = pose.aloft > 0.5 && !pose.hovering
        let calm = busy < 0.1 && pose.misfire < 0 && pose.rebirth < 0 && pose.ash < 0 && !flying
        let flare = calm ? flareAge(t: t) : nil
        let sprite = frame(t: t, busy: busy, pose: pose)
        let head = Pixels(ctx: outer, unit: unit, dx: bx, dy: by + (sprite === perch ? perchDrop : 0))   // crest and eyes

        // behind the bird
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: false) }
        if pose.orb >= 0 { beacon(head, t: t, age: pose.orb) }
        if pose.ash >= burstAt { climbTrail(body, t: t, age: pose.ash - burstAt) }
        // each downstroke pushes a faint breath of wind off the wings
        if sprite !== perch, sprite !== glide, sprite !== hover, pose.ash < 0 {
            wind(body, t: t, step: busy > 0.1 ? frameTime(busy: busy) : pose.rebirth >= 0 ? 0.06 : flying ? frameTime(busy: 0) : hoverFrameTime)
        }

        // the bird
        var ctx = outer
        ctx.opacity = clamp(pose.reveal)
        if pose.squash > 0.01 {
            let baseline = CGPoint(x: 36, y: 94)
            ctx.translateBy(x: baseline.x * unit, y: baseline.y * unit)
            ctx.scaleBy(x: 1 + 0.14 * pose.squash, y: 1 - 0.12 * pose.squash)
            ctx.translateBy(x: -baseline.x * unit, y: -baseline.y * unit)
        }
        if abs(pose.bank) > 0.002 {   // leaning into the turn on its glide
            ctx.translateBy(x: (bx + centre.x) * unit, y: (by + centre.y) * unit)
            ctx.rotate(by: .radians(pose.bank))
            ctx.translateBy(x: -(bx + centre.x) * unit, y: -(by + centre.y) * unit)
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
        let rect = CGRect(x: (bx - Double(padLeft)) * unit, y: (by - Double(padTop)) * unit,
                          width: canvas.width * unit, height: canvas.height * unit)
        let image = Image(decorative: sprite, scale: 1).interpolation(.none)
        ctx.draw(image, in: rect)

        // the bird blazing up: its own frame again, added on top
        var glow = 0.0
        if let f = flare { glow = 0.55 * sin(.pi * f / flareLength) }
        if pose.cast >= 0 { glow = max(glow, 0.45 * sin(.pi * clamp(pose.cast / clickBreath))) }
        if pose.feast >= 0 { glow = max(glow, 0.5 * (1 - clamp(pose.feast / 1.2))) }
        if pose.misfire > 0.75 { glow = max(glow, 0.45 * sin(.pi * clamp((pose.misfire - 0.75) / 0.6))) }
        if pose.rebirth >= breathAt { glow = max(glow, 0.6 * sin(.pi * clamp((pose.rebirth - breathAt) / breathLength))) }
        if pose.ash >= 0 { glow = max(glow, pose.ash < burstAt ? 0.9 * clamp(pose.ash / burstAt) : 0.7) }   // gathering its fire
        if glow > 0.02 {
            var g = ctx
            g.blendMode = .plusLighter
            g.opacity = glow * clamp(pose.reveal)
            g.draw(image, in: rect)
        }

        // in front of the bird
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: true) }
        if pose.reveal > 0.5, pose.ash < 0 { embers(body, t: t, busy: max(busy, flying ? 0.6 : 0), fling: pose.fling, misfire: pose.misfire) }
        if let f = flare { burst(body, age: f, length: flareLength, count: 18, colour: nil) }
        if pose.orb >= 0 { glowingEyes(head, t: t) }
        if pose.feast >= 0 {
            burst(body, age: pose.feast, length: 1.2, count: 24, colour: gold)
            driftingFeather(body, t: t, age: pose.feast, slot: pose.goldSparks)
        }
        if pose.misfire >= 0 { smokePuffs(body, age: pose.misfire) }
        if pose.ash >= 0, pose.ash < burstAt { gather(body, age: pose.ash) }
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

    /// Each downstroke: a faint breath of air pushed down and back off the wings, gone within half a beat.
    private static func wind(_ px: Pixels, t: Double, step: Double) {
        let beat = step * Double(flaps.count)
        let u = ((t / beat) - 2.0 / 6).truncatingRemainder(dividingBy: 1)   // 0 as the wings start down (frame 3)
        guard u >= 0, u < 0.5 else { return }
        let k = u / 0.5
        for i in 0 ..< 10 {
            let x = centre.x - 14 + Double(i) * 4 + k * (6 + hash(i, 40) * 6)
            let y = centre.y + 6 + hash(i, 41) * 6 + k * (16 + hash(i, 42) * 10)
            px.dot(x, y, .white, 0.22 * (1 - k))
            if i % 2 == 0 { px.dot(x + 1, y + 1, .white, 0.14 * (1 - k)) }
        }
    }

    /// Goodbye, wings folded: sparks rushing in from all round as it gathers its power.
    private static func gather(_ px: Pixels, age: Double) {
        let k = clamp(age / burstAt)
        for i in 0 ..< 36 {
            let u = ((age * 1.6 + hash(i, 43)) ).truncatingRemainder(dividingBy: 1)
            let a = Double(i) / 36 * 2 * .pi
            let r = 46 * (1 - u) + 4
            px.dot(centre.x + cos(a) * r, centre.y + sin(a) * r * 0.85, i % 3 == 0 ? gold : fire(1 - u), k * u, size: u > 0.7 ? 2 : 1)
        }
    }

    /// Goodbye, after the burst: a column of fire streaming down off it as it shoots up.
    private static func climbTrail(_ px: Pixels, t: Double, age: Double) {
        for i in 0 ..< 40 {
            let u = ((t * 3 + hash(i, 44)) ).truncatingRemainder(dividingBy: 1)
            let x = centre.x + 4 + (hash(i, 45) - 0.5) * (8 + u * 14)
            let y = centre.y + 30 + u * 40
            px.dot(x, y, fire(u), (1 - u) * clamp(age / 0.1), size: u < 0.4 ? 3 : 2)
        }
    }

    // MARK: - fire past the window (screen overlays)

    /// Where its beak is in the airborne and wings-spread frames (sprite grid).
    private static let beak = CGPoint(x: 12, y: 26)

    /// Breathes fire from its beak for `length` s; `dense` is the arrival's torrent, otherwise a click's gout.
    @MainActor static func breathe(windowOrigin: CGPoint, facingRight: Bool, length: Double, dense: Bool) {
        overlay(at: beak, windowOrigin: windowOrigin, facingRight: facingRight, for: length + FireBreath.life + 0.1) {
            FireBreath(start: $0, dir: facingRight ? 1 : -1, unit: RobotView.scale, length: length, dense: dense)
        }
    }

    /// Goodbye: a blast of fire and light bursting out of it across the screen.
    @MainActor static func blast(windowOrigin: CGPoint, facingRight: Bool) {
        overlay(at: centre, windowOrigin: windowOrigin, facingRight: facingRight, for: Blast.life + 0.1) {
            Blast(start: $0, unit: RobotView.scale)
        }
    }

    /// A see-through, click-through window over the screen under sprite point `art`, for `duration` seconds; `make`
    /// gets that point in the overlay's view coordinates (y down).
    @MainActor private static func overlay<V: View>(at art: CGPoint, windowOrigin: CGPoint, facingRight: Bool,
                                                    for duration: Double, _ make: (CGPoint) -> V) {
        let px = (CGFloat(padLeft) + art.x) * RobotView.scale, py = (CGFloat(padTop) + art.y) * RobotView.scale
        let p = CGPoint(x: windowOrigin.x + (facingRight ? RobotView.canvasSize.width - px : px),
                        y: windowOrigin.y + RobotView.canvasSize.height - py)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main else { return }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: make(CGPoint(x: p.x - screen.frame.minX, y: screen.frame.maxY - p.y)))
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { window.close() }
    }

    /// A cone of flame tongues pouring out of the beak, widening, rising and dying from white-hot to deep red.
    struct FireBreath: View {
        static let life = 0.75
        let start: CGPoint   // view coordinates, y down
        let dir: Double      // -1 = to the left
        let unit: CGFloat
        let length: Double
        let dense: Bool
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
                let px = Pixels(ctx: c, unit: unit, dx: start.x / unit, dy: start.y / unit)
                let rate = dense ? 1400.0 : 600.0, speed = dense ? 330.0 : 210.0
                let count = Int(length * rate)
                for i in 0 ..< count {
                    let a = age - Double(i) / rate
                    guard a >= 0, a < Self.life else { continue }
                    let k = a / Self.life
                    let dist = speed * a * (1 - 0.4 * a) * (0.7 + 0.6 * hash(i, 50))
                    let spread = (hash(i, 51) - 0.5) * (0.22 + 0.95 * k) * dist
                    let x = dir * dist, y = 0.1 * dist + spread - 34 * a * a
                    let size = (dense ? 3 : 2) + (dense ? 8 : 5) * k
                    px.dot(x - size / 2, y - size / 2, fire(k * 0.95 + hash(i, 52) * 0.15), (1 - k * k) * 0.9, size: size.rounded())
                }
                // a white-hot core at the beak while it pours
                if age < length { for j in 0 ..< 10 { px.dot(dir * Double(j) * 2.5 - 1, -1, j < 4 ? .white : pale, 1, size: dense ? 3 : 2) } }
            }
        }
    }

    /// Fire and gold flying out in every direction behind a ring of light, from a white flash at its heart.
    struct Blast: View {
        static let life = 1.1
        let start: CGPoint
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
                guard age < Self.life else { return }
                let px = Pixels(ctx: c, unit: unit, dx: start.x / unit, dy: start.y / unit)
                let k = age / Self.life
                let out = 1 - pow(1 - k, 3)   // fast at first, slowing as it spreads
                // the flash: a solid white-hot ball that swells and fades in the first moment
                let flash = 1 - clamp(age / 0.3)
                if flash > 0 {
                    let r = 14 + 46 * age / 0.3
                    var y = -r
                    while y <= r {
                        let half = (r * r - y * y).squareRoot()
                        var x = -half
                        while x <= half { px.dot(x, y, hypot(x, y) < r * 0.5 ? .white : hypot(x, y) < r * 0.8 ? pale : yellow, flash, size: 4); x += 4 }
                        y += 4
                    }
                }
                // a storm of flames and gold flung out in every direction, densest at the heart, falling a little as they go
                for i in 0 ..< 1100 {
                    let a = Double(i) / 1100 * 2 * .pi + hash(i, 53) * 0.4
                    let r = (16 + 280 * pow(hash(i, 54), 0.8)) * out
                    let size = (9 - 6 * k) * (0.5 + 0.7 * hash(i, 56))
                    px.dot(cos(a) * r - size / 2, sin(a) * r * 0.85 + 40 * k * k - size / 2,
                           i % 6 == 0 ? gold : fire(k * 0.75 + hash(i, 55) * 0.3), (1 - k * k) * 0.95, size: max(1, size.rounded()))
                }
            }
        }
    }
}
