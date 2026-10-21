import SwiftUI

/// The crimson phoenix. It shares the brain with Wizzy and Faelis (a caster: no sword, its own arrival,
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

    /// Arrival (`pose.rebirth` = seconds in): a pile of ash glows on its spot and embers spiral up off it; at `riseAt` a
    /// column of flame bursts out and the bird rises out of it over `riseLength` s, black as charcoal and heating up from
    /// its feet; at `wingsAt` it throws its wings open and the ash blows away; the brain lets go at `arrivalLength`.
    static let riseAt = 1.6, riseLength = 0.65, wingsAt = 2.3, arrivalLength = 3.1
    /// Goodbye (`pose.ash` = seconds in): it flies off the screen in `exitLength` s, blazing white-gold, and from
    /// `exitBreathAt` roars like a dragon and pours a torrent of fire out ahead of it for `exitBreathLength` s.
    static let exitLength = 3.2, exitBreathAt = 0.35, exitBreathLength = 1.8
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
        if pose.rebirth >= 0 { return pose.rebirth < wingsAt ? perch : hover }   // rises with its wings folded, then spreads them
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
        case .wake, .farewell, .chime: .ignite
        case .nudge: .crackle
        case .rune: .roar
        case .orb: .whoosh
        case .fizzle: .smother
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
    private static func ease(_ v: Double) -> Double { let k = clamp(v); return k * k * (3 - 2 * k) }

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
        if pose.rebirth >= 0 { rebirthFire(floor, age: pose.rebirth) }
        // each downstroke pushes a faint breath of wind off the wings
        if sprite !== perch, sprite !== glide, sprite !== hover {
            wind(body, t: t, step: busy > 0.1 ? frameTime(busy: busy) : flying ? frameTime(busy: 0) : hoverFrameTime)
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
        if pose.rebirth >= 0, pose.rebirth < wingsAt {
            risingBird(ctx, image: image, rect: rect, unit: unit, age: pose.rebirth)
        } else { ctx.draw(image, in: rect) }

        // the bird blazing up: its own frame again, added on top
        var glow = 0.0
        if let f = flare { glow = 0.55 * sin(.pi * f / flareLength) }
        if pose.cast >= 0 { glow = max(glow, 0.45 * sin(.pi * clamp(pose.cast / clickBreath))) }
        if pose.feast >= 0 { glow = max(glow, 0.5 * (1 - clamp(pose.feast / 1.2))) }
        if pose.misfire > 0.75 { glow = max(glow, 0.45 * sin(.pi * clamp((pose.misfire - 0.75) / 0.6))) }
        if pose.rebirth >= wingsAt { glow = max(glow, 0.8 * (1 - clamp((pose.rebirth - wingsAt) / 0.6))) }   // still white-hot as its wings open
        if pose.ash >= 0 { glow = max(glow, (0.55 + 0.15 * sin(t * 13)) * ease(pose.ash / 0.4)) }   // leaving ablaze, flickering white-hot
        if glow > 0.02 {
            var g = ctx
            g.blendMode = .plusLighter
            g.opacity = glow * clamp(pose.reveal)
            g.draw(image, in: rect)
        }

        // in front of the bird
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: true) }
        if pose.rebirth >= 0 { ashPile(floor, age: pose.rebirth) }
        if pose.reveal > 0.5, pose.rebirth < 0 || pose.rebirth >= riseAt + riseLength {   // nothing to shed embers until it has risen
            let heat = pose.ash >= 0 ? 1 : max(busy, flying ? 0.6 : 0)
            if let origin = pose.origin {
                screenEmbers(t: t, origin: origin, unit: unit, facingRight: pose.facingRight,
                             body: CGPoint(x: bx, y: by), busy: heat, misfire: pose.misfire)
            } else { embers(body, t: t, busy: heat, fling: pose.fling, misfire: pose.misfire) }
        }
        if let f = flare { burst(body, age: f, length: flareLength, count: 18, colour: nil) }
        if pose.orb >= 0 { glowingEyes(head, t: t) }
        if pose.feast >= 0 {
            burst(body, age: pose.feast, length: 1.2, count: 24, colour: gold)
            risingSun(body, age: pose.feast, sprite: sprite, waiting: pose.redSparks, gold: pose.goldSparks)
        }
        if pose.misfire >= 0 { smokePuffs(body, age: pose.misfire) }
        if pose.rebirth < 0 || pose.rebirth >= wingsAt { counters(body, t: t, sprite: sprite, waiting: pose.redSparks, gold: pose.goldSparks) }
    }

    // MARK: - effects

    /// The arrival's ash pile sits under its feet (sprite grid).
    private static let pileX = 32.0

    /// Rising from the ashes: the folded bird comes up out of the pile, cut off at the ground, black as charcoal above a
    /// front of heat that climbs from its feet to its crest, with a white-hot rim along the front.
    private static func risingBird(_ ctx: GraphicsContext, image: Image, rect: CGRect, unit: CGFloat, age: Double) {
        guard age >= riseAt else { return }
        let rise = ease((age - riseAt) / riseLength), heat = ease((age - riseAt - 0.15) / 0.5)
        let r = rect.offsetBy(dx: 0, dy: (1 - rise) * 80 * unit)
        let front = r.minY + (122 - heat * 76) * unit                  // the perch frame spans canvas rows 46...121
        let far = 1e5
        func band(_ top: CGFloat, _ bottom: CGFloat) -> Path { Path(CGRect(x: -far, y: top, width: 2 * far, height: bottom - top)) }
        var c = ctx
        c.clip(to: band(-far, (ground + 2) * unit))   // below the ground: still in the ash (the perched tail stays in it until the wings open)
        var hot = c
        hot.clip(to: band(front, far))
        hot.draw(image, in: r)
        var coal = c
        coal.clip(to: band(-far, front))
        coal.addFilter(.colorMultiply(Color(red: 0.16, green: 0.12, blue: 0.12)))
        coal.draw(image, in: r)
        var rim = c
        rim.clip(to: band(front - 3 * unit, front + 3 * unit))
        rim.addFilter(.colorMultiply(yellow))
        rim.blendMode = .plusLighter
        rim.draw(image, in: r)
    }

    /// Behind the bird on its arrival: embers spiralling up off the glowing ash, then the column of flame it rises from.
    private static func rebirthFire(_ px: Pixels, age: Double) {
        if age >= 0.8, age < riseAt + 1 {
            let k = ease((age - 0.8) / 0.8) * (1 - ease((age - wingsAt) / 0.3))
            for i in 0 ..< 40 {
                let a = ((age - 0.8) * (0.8 + hash(i, 63)) + hash(i, 64)).truncatingRemainder(dividingBy: 1)
                let angle = hash(i, 65) * 2 * .pi + a * 9, r = (20 - 12 * a) * (1 - 0.3 * k)
                px.dot(pileX + cos(angle) * r, ground - 4 - a * 70 * (0.5 + k), fire(a), (1 - a) * k, size: hash(i, 66) > 0.7 ? 2 : 1)
            }
        }
        guard age >= riseAt, age < wingsAt + 0.5 else { return }
        let k = ease((age - riseAt) / 0.25) * (1 - ease((age - wingsAt) / 0.5))
        for i in 0 ..< 140 {
            let a = ((age - riseAt) * (1.6 + hash(i, 67)) + hash(i, 68)).truncatingRemainder(dividingBy: 1)
            let x = pileX + (hash(i, 69) - 0.5) * 18 * (1 - 0.5 * a) + sin(age * 9 + Double(i)) * 2
            px.dot(x, ground - a * 95, fire(0.3 + 0.7 * a), (1 - a) * k, size: a < 0.3 ? 2 : 1)
        }
    }

    /// In front of the bird on its arrival: the ash pile, its embers beating like a heart and glowing hotter as the fire
    /// gathers, thrown off to both sides by the first beat of its wings.
    /// shortcut: the flying ash is cut off at the window's edges; draw it in a screen overlay if that ever shows.
    private static func ashPile(_ px: Pixels, age: Double) {
        let heart = age < riseAt ? pow(max(0, sin(age * 2 * .pi * 1.4)), 6) : 0
        let glow = max(age < 0.8 ? 0.35 * heart : 0, age < wingsAt + 0.3 ? ease((age - 0.8) / 0.8) : 0)
        let fly = (age - wingsAt) / 0.9
        guard fly < 1 else { return }
        for i in 0 ..< 110 {
            let side = hash(i, 60) * 2 - 1, gy = hash(i, 61), s = 0.2 + 0.8 * hash(i, 62)
            var x = pileX + side * 22, y = ground - gy * 9 * (1 - side * side)
            if fly > 0 { x += side * fly * 45 * s; y += -22 * s * fly + 30 * fly * fly * hash(i, 63) }
            let fade = fly > 0 ? 1 - fly : 1
            px.dot(x, y, i % 3 == 0 ? smoke : ashGrey, fade, size: fly > 0 && i % 4 == 0 ? 2 : 1)
            px.dot(x, y, fire(0.55 + 0.4 * gy), glow * (1 - gy * 0.5) * fade)
        }
        guard age < wingsAt else { return }
        for i in 0 ..< 12 {   // the embers in the ash
            px.dot(pileX - 14 + hash(i, 70) * 28, ground - 2 - hash(i, 71) * 5, fire(0.5), 0.3 + 0.7 * heart + glow)
        }
    }

    /// Idle: a few embers rising off the plumage. Carried or falling: a trail of them streaming behind.
    /// Only for previews, which have no window on the screen; the pet itself uses `screenEmbers`.
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

    /// An ember loose on the screen: art pixels, y up, so it doesn't care where the window goes.
    private struct Ember { var x, y, vx, vy, age, life: Double; var big: Bool }
    nonisolated(unsafe) private static var loose: [Ember] = []
    nonisolated(unsafe) private static var lastStep = 0.0, lastOrigin: CGPoint?, owed = 0.0, dim = 1.0
    /// The see-through window over the screens the loose embers are drawn in, so the pet window never clips them.
    @MainActor private static var field: NSWindow?

    /// Embers that live on the screen, not in the window. Each is born on the plumage carrying part of the bird's own
    /// speed, then air drag slows it and the heat lifts it, so a dragged or flying bird leaves a trail of them behind it
    /// and they drift on where it let them go instead of being dragged along. `EmberField` draws them.
    private static func screenEmbers(t: Double, origin: CGPoint, unit: CGFloat, facingRight: Bool,
                                     body: CGPoint, busy: Double, misfire: Double) {
        let o = CGPoint(x: origin.x / unit, y: origin.y / unit)   // window origin in art pixels
        // art pixel on the bird <-> the screen (see RobotView.screenPoint)
        func world(_ x: Double, _ y: Double) -> CGPoint {
            let px = Double(padLeft) + x
            return CGPoint(x: o.x + (facingRight ? canvas.width - px : px), y: o.y + canvas.height - (Double(padTop) + y))
        }
        let dt = t - lastStep
        if dt > 0 {   // the ghost of a glitch frame draws again at the same moment: step once
            let step = min(dt, 0.05)
            lastStep = t
            var bird = CGPoint.zero   // the bird's speed, art px/s; a jump (a swoop starting off-screen) counts as none
            if let last = lastOrigin, hypot(o.x - last.x, o.y - last.y) < 120 { bird = CGPoint(x: (o.x - last.x) / step, y: (o.y - last.y) / step) }
            lastOrigin = o
            let drag = exp(-2.2 * step)
            for i in loose.indices {
                loose[i].vx *= drag; loose[i].vy = loose[i].vy * drag + 22 * step   // the heat lifts it
                loose[i].vx += Double.random(in: -1 ... 1) * 30 * step                // and the air jostles it
                loose[i].x += loose[i].vx * step; loose[i].y += loose[i].vy * step
                loose[i].age += step
            }
            loose.removeAll { $0.age >= $0.life }
            owed += step * (busy > 0.1 ? 14 + 26 * busy : 4)
            while owed >= 1, loose.count < 240 {
                owed -= 1
                let p = world(body.x + 4 + .random(in: 0 ... 62), body.y + 30 + .random(in: 0 ... 55))
                loose.append(Ember(x: p.x, y: p.y, vx: 0.35 * bird.x + .random(in: -6 ... 6), vy: 0.35 * bird.y + .random(in: 4 ... 14),
                                   age: 0, life: busy > 0.1 ? .random(in: 0.7 ... 1.5) : .random(in: 1.8 ... 3.4), big: busy > 0.1 && Bool.random()))
            }
            owed = min(owed, 1)
        }
        dim = misfire >= 0 ? clamp((misfire - 0.75) / 0.5) : 1
        DispatchQueue.main.async { openField() }
    }

    /// One click-through window spanning every screen, opened the first time the phoenix sheds an ember.
    /// shortcut: with "Displays have separate Spaces" on, macOS shows it on one display only; per-screen windows if that matters.
    @MainActor private static func openField() {
        guard field == nil else { return }
        let frame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: EmberField(frame: frame))
        window.orderFrontRegardless()
        field = window
    }

    /// Draws the loose embers where they are on the screen.
    private struct EmberField: View {
        let frame: CGRect
        var body: some View {
            TimelineView(.animation) { tl in
                Canvas { c, _ in
                    // the phoenix hasn't been drawn for a while (hidden, or another character): close, don't redraw an empty screen
                    if tl.date.timeIntervalSinceReferenceDate - lastStep > 5 { DispatchQueue.main.async { field?.close(); field = nil } }
                    let unit = RobotView.scale
                    let px = Pixels(ctx: c, unit: unit, dx: -frame.minX / unit, dy: frame.maxY / unit)   // screen art px, y up -> view
                    for e in loose {
                        let a = e.age / e.life
                        px.dot(e.x, -e.y, fire(a), (1 - a * a) * dim, size: e.big ? 2 : 1)
                    }
                }
            }
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

    /// Counter glyphs, one character per art pixel: o rim, K/R/r reds, Y/P/O/G golds, . clear.
    private static let eyeGlyph = ["..ooooo..", ".oKRRRKo.", "oRRYYYRRo", "oRYYoYYRo", "oRRYYYRRo", ".oKRRRKo.", "..ooooo.."]
    private static let sunGlyph = ["....Y....", ".Y..Y..Y.", "..oGGGo..", ".oGPPPGo.", "YYGPPPGYY", ".oGPPPGo.", "..oGGGo..", ".Y..Y..Y.", "....Y...."]
    private static let glyphColours: [Character: Color] = [
        "o": outline, "K": Color(red: 0.43, green: 0.03, blue: 0.04), "R": red, "Y": yellow, "P": pale, "G": gold, "O": orange,
    ]

    /// A glyph centred on (x, y) in a soft halo of its own colour.
    private static func glyph(_ px: Pixels, _ rows: [String], _ x: Double, _ y: Double, halo: Color, glow: Double, opacity: Double = 1) {
        let w = Double(rows[0].count), h = Double(rows.count), r = max(w, h) / 2 + 3
        for dx in stride(from: -r, through: r, by: 1) {
            for dy in stride(from: -r, through: r, by: 1) {
                let d = (dx * dx + dy * dy).squareRoot()
                if d <= r { px.dot(x + dx, y + dy, halo, glow * opacity * (1 - d / (r + 0.5))) }
            }
        }
        let x0 = x - (w / 2).rounded(.down), y0 = y - (h / 2).rounded(.down)
        for (j, row) in rows.enumerated() {
            for (i, ch) in row.enumerated() { if let c = glyphColours[ch] { px.dot(x0 + Double(i), y0 + Double(j), c, opacity) } }
        }
    }

    /// At most this many counters show in the row over its head.
    /// shortcut: anything past seven isn't shown (the window has no room above the flying frames); add a second row if that ever matters.
    static let maxMarks = 7

    /// Where the i-th of n counters sits: one row centred over its head, clear of the crest in whichever frame it shows.
    private static func mark(_ i: Int, of n: Int, sprite: CGImage) -> CGPoint {
        let y: Double = sprite === perch ? 26 : sprite === hover ? 9 : sprite === glide ? 3 : -1
        return CGPoint(x: 20 + (Double(i) - Double(n - 1) / 2) * 9, y: y)
    }

    /// Crimson eyes for sessions waiting on the user, then golden suns for finished ones, in a row over its head.
    private static func counters(_ px: Pixels, t: Double, sprite: CGImage, waiting: Int, gold: Int) {
        let red = min(waiting, maxMarks), n = min(waiting + gold, maxMarks)
        for i in 0 ..< n {
            let p = mark(i, of: n, sprite: sprite)
            if i < red {   // each eye's glow breathes on its own
                glyph(px, eyeGlyph, p.x, p.y, halo: Color(red: 0.9, green: 0.08, blue: 0.08), glow: 0.3 + 0.15 * sin(t * 3 + Double(i) * 1.3))
            } else {
                glyph(px, sunGlyph, p.x, p.y, halo: Self.gold, glow: 0.3)
            }
        }
    }

    /// A session finished: a golden sun rises off its crest and settles into the row as the newest counter.
    private static func risingSun(_ px: Pixels, age: Double, sprite: CGImage, waiting: Int, gold: Int) {
        guard age > 0.3, age < 2.0 else { return }
        let n = min(waiting + gold + 1, maxMarks), i = n - 1
        guard i >= min(waiting, maxMarks) else { return }
        let k = ease((age - 0.3) / 1.4)
        let to = mark(i, of: n, sprite: sprite), from = CGPoint(x: crest.x, y: crest.y + (sprite === perch ? perchDrop : 0))
        glyph(px, sunGlyph, from.x + (to.x - from.x) * k, from.y + (to.y - from.y) * k, halo: Self.gold, glow: 0.5, opacity: clamp((age - 0.3) / 0.3))
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

    // MARK: - fire past the window (screen overlays)

    /// Where its beak is in the airborne and wings-spread frames (sprite grid).
    private static let beak = CGPoint(x: 12, y: 26)

    /// Breathes fire from its beak for `length` s; `dense` is the arrival's torrent, otherwise a click's gout.
    /// On the arrival the window is still swooping from `windowOrigin` to `to`: the flame leaves the beak wherever it is
    /// along that swoop, `offset` s into a `travel` s ease-out.
    /// `live` reads the pet window's origin every frame: the flame leaves the beak wherever the bird is, swooping or dragged.
    @MainActor static func breathe(windowOrigin: CGPoint, live: @escaping () -> CGPoint, facingRight: Bool, length: Double, dense: Bool) {
        overlay(at: beak, windowOrigin: windowOrigin, facingRight: facingRight, for: length + FireBreath.life + 0.1) { start, beakNow in
            FireBreath(start: start, dir: facingRight ? 1 : -1, unit: RobotView.scale, length: length, dense: dense,
                       follow: { beakNow(live()) })
        }
    }

    /// A see-through, click-through window over the screen under sprite point `art`, for `duration` seconds; `make`
    /// gets that point in the overlay's view coordinates (y down).
    @MainActor private static func overlay<V: View>(at art: CGPoint, windowOrigin: CGPoint, facingRight: Bool,
                                                    for duration: Double, _ make: (CGPoint, @escaping (CGPoint) -> CGPoint) -> V) {
        let px = (CGFloat(padLeft) + art.x) * RobotView.scale, py = (CGFloat(padTop) + art.y) * RobotView.scale
        let at = { (o: CGPoint) in CGPoint(x: o.x + (facingRight ? RobotView.canvasSize.width - px : px),
                                           y: o.y + RobotView.canvasSize.height - py) }
        let p = at(windowOrigin)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main else { return }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: make(CGPoint(x: p.x - screen.frame.minX, y: screen.frame.maxY - p.y), { o in
            let q = at(o)
            return CGPoint(x: q.x - screen.frame.minX, y: screen.frame.maxY - q.y)
        }))
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
        var shift = CGPoint.zero   // how far the beak moves (view points) over the swoop
        var travel = 0.0, offset = 0.0
        var fixedAge: Double?
        /// The beak in view coordinates right now; set, each particle leaves from where the beak was when it was born.
        var follow: (() -> CGPoint)?
        private final class Track { var samples: [(t: Double, p: CGPoint)] = [] }
        private let track = Track()
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge {
                canvas(age: fixedAge)
            } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        /// The beak, `t` s after the breath began, in art px from `start` (the same ease-out as Brain's swoop).
        private func mouth(_ t: Double) -> CGPoint {
            guard travel > 0 else { return .zero }
            let k = 1 - pow(1 - min(1, (offset + t) / travel), 3), k0 = 1 - pow(1 - min(1, offset / travel), 3)
            let f = k0 >= 1 ? 1 : (k - k0) / (1 - k0)
            return CGPoint(x: shift.x * f / unit, y: shift.y * f / unit)
        }

        /// Where the beak was `t` s into the breath, in art px (relative to `start` unless following).
        private func origin(_ t: Double) -> CGPoint {
            guard follow != nil else { return mouth(t) }
            let s = track.samples.last(where: { $0.t <= t }) ?? track.samples.first
            return CGPoint(x: (s?.p.x ?? start.x) / unit, y: (s?.p.y ?? start.y) / unit)
        }

        private func canvas(age: Double) -> some View {
            if let follow, track.samples.last.map({ $0.t < age }) ?? true { track.samples.append((age, follow())) }
            return Canvas { c, _ in
                let px = Pixels(ctx: c, unit: unit, dx: follow == nil ? start.x / unit : 0, dy: follow == nil ? start.y / unit : 0)
                let rate = dense ? 1400.0 : 600.0, speed = dense ? 330.0 : 210.0
                let count = Int(length * rate)
                for i in 0 ..< count {
                    let te = Double(i) / rate, a = age - te
                    guard a >= 0, a < Self.life else { continue }
                    let k = a / Self.life
                    let from = origin(te)
                    let dist = speed * a * (1 - 0.4 * a) * (0.7 + 0.6 * hash(i, 50))
                    let spread = (hash(i, 51) - 0.5) * (0.22 + 0.95 * k) * dist
                    let x = from.x + dir * dist, y = from.y + 0.1 * dist + spread - 34 * a * a
                    let size = (dense ? 3 : 2) + (dense ? 8 : 5) * k
                    px.dot(x - size / 2, y - size / 2, fire(k * 0.95 + hash(i, 52) * 0.15), (1 - k * k) * 0.9, size: size.rounded())
                }
            }
        }
    }

}
