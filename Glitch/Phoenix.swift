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

    /// Arrival (`pose.rebirth` = seconds in): ash drifts down over a wide stretch of ground round its spot and lies
    /// smouldering (`spreadAshes`); from `gatherAt` it lifts and streams in, each flake to a pixel of the folded bird,
    /// building it out of grey ash from its feet up to its crest between `buildAt` and `buildAt + buildLength`, an ember
    /// line glowing where the ash fuses. At `hotAt` it catches fire: a white-hot flash and its own colours; at `wingsAt`
    /// its wings snap open in `snapLength` s (its own 3/4 frames): a white-gold flash, a warm glow, the last ash flung out,
    /// its cry. It holds that pose until `foldAt`, folds its wings over `foldLength` s and the brain lets go at `arrivalLength`.
    /// Nothing ever stands still: it breathes, its embers flicker and the glow pulses.
    static let gatherAt = 1.6, buildAt = 2.2, buildLength = 2.0, hotAt = 4.3, wingsAt = 4.8, snapLength = 0.18
    static let foldAt = 5.55, foldLength = 0.45, arrivalLength = 6.2
    /// Its sounds: the ash settling, a rush as it lifts, the flames catching, the cry on the frame its wings are open.
    static let arrivalCues: [(at: Double, sound: SoundEffect)] = [(0.9, .crackle), (gatherAt, .whoosh), (hotAt - 0.2, .ignite), (wingsAt + snapLength, .shriek)]

    /// The arrival's frames: perched until its wings snap open (easing out), held up, then beaten closed (easing in and
    /// out). Between two frames it cross-fades, `mix` of the way from `from` to `to`. The wing frames are drawn
    /// `perchDrop` lower than they are pinned, so the beak stays put while the wings move (flaps[2] dips its head: left out).
    private static let opening = [perch, flaps[3], flaps[4], flaps[5]], folding = [flaps[5], flaps[0], flaps[1], flaps[3], perch]
    private static func arrivalFrames(_ age: Double) -> (from: CGImage, to: CGImage, mix: Double) {
        func along(_ seq: [CGImage], _ k: Double) -> (CGImage, CGImage, Double) {
            let p = clamp(k) * Double(seq.count - 1), i = min(seq.count - 2, Int(p))
            return (seq[i], seq[i + 1], p - Double(i))
        }
        if age < wingsAt { return (perch, perch, 0) }
        if age < foldAt { return along(opening, 1 - pow(1 - clamp((age - wingsAt) / snapLength), 3)) }
        return along(folding, ease((age - foldAt) / foldLength))
    }

    /// A slow breath while it stands through its arrival, half an art pixel each way, eased in and out of it.
    private static func arrivalBreath(_ age: Double) -> Double {
        0.5 * sin(2 * .pi * age / 1.5) * ease((age - hotAt) / 0.5) * (1 - ease((age - arrivalLength + 0.4) / 0.4))
    }
    /// Goodbye (`pose.ash` = seconds in): it flies off the screen in `exitLength` s, blazing white-gold, and from
    /// `exitBreathAt` roars like a dragon and pours a torrent of fire out ahead of it for `exitBreathLength` s.
    static let exitLength = 3.2, exitBreathAt = 0.35, exitBreathLength = 1.8
    /// A click: it breathes a short gout of fire.
    static let clickBreath = 0.9
    /// Idle life: every `flareEvery` s (wall clock) it blazes up for `flareLength` s.
    static let flareEvery = 28.0, flareLength = 1.6

    /// Seconds per frame of the six-frame beat: slow, heavy strokes in flight, a little brisker when carried.
    /// A fixed step, not one that slides with `busy`: `t / step` jumps whole frames as the step changes.
    static func frameTime(busy: Double) -> Double { busy > 0.1 ? 0.085 : 0.11 }
    /// The slower beat that holds it in the air while it hangs in one place.
    static let hoverFrameTime = 0.16

    /// Which frame it shows: a wing beat, the glide, the wings spread, or folded on the perch.
    private static func frame(t: Double, busy: Double, pose: Brain.Pose) -> CGImage {
        func beat(_ step: Double) -> CGImage { flaps[Int(t / step) % flaps.count] }
        if busy > 0.1 { return beat(frameTime(busy: busy)) }
        if pose.rebirth >= 0 { let f = arrivalFrames(pose.rebirth); return f.mix < 0.5 ? f.from : f.to }
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
        let sprite = frame(t: t, busy: busy, pose: pose)
        let arrival = pose.rebirth >= 0 ? arrivalFrames(pose.rebirth) : nil
        // during the arrival the body follows the wing frames down in step with the cross-fade, and breathes
        let lift = arrival.map { a in perchDrop * ((a.from === perch ? 0 : 1 - a.mix) + (a.to === perch ? 0 : a.mix)) + arrivalBreath(pose.rebirth) } ?? 0
        let bx = pose.bodyDX + pose.shakeX, by = pose.bodyDY + lift
        let body = Pixels(ctx: outer, unit: unit, dx: bx, dy: by)      // follows the bird
        let floor = Pixels(ctx: outer, unit: unit, dx: bx, dy: 0)      // stays on the ground
        let flying = pose.aloft > 0.5 && !pose.hovering
        let calm = busy < 0.1 && pose.misfire < 0 && pose.rebirth < 0 && pose.ash < 0 && !flying
        let flare = calm ? flareAge(t: t) : nil
        let head = Pixels(ctx: outer, unit: unit, dx: bx, dy: by + (sprite === perch ? perchDrop : 0))   // crest and eyes

        // behind the bird
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: false) }
        if pose.orb >= 0 { beacon(head, t: t, age: pose.orb) }
        if pose.rebirth >= 0 { wakeGlow(outer, unit: unit, dx: bx, dy: by, age: pose.rebirth) }
        // each downstroke pushes a faint breath of wind off the wings
        if arrival == nil, sprite !== perch, sprite !== glide, sprite !== hover {
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
        if arrival != nil, pose.rebirth < wingsAt {
            ashBird(ctx, image: image, rect: rect, unit: unit, age: pose.rebirth)
        } else if let a = arrival {
            let base = lift - arrivalBreath(pose.rebirth)   // where `by` puts the frames, less the breath they keep
            // each frame stays solid through its half of the blend, so the body never turns see-through
            for (frame, k) in [(a.from, 1 - a.mix), (a.to, a.mix)] where k > 0.001 {
                var c = ctx
                c.opacity *= min(1, 2 * k)
                c.draw(Image(decorative: frame, scale: 1).interpolation(.none),
                       in: rect.offsetBy(dx: 0, dy: ((frame === perch ? 0 : perchDrop) - base) * unit))
            }
        } else { ctx.draw(image, in: rect) }

        // the bird blazing up: its own frame again, added on top
        var glow = 0.0
        if let f = flare { glow = 0.55 * sin(.pi * f / flareLength) }
        if pose.cast >= 0 { glow = max(glow, 0.45 * sin(.pi * clamp(pose.cast / clickBreath))) }
        if pose.feast >= 0 { glow = max(glow, 0.5 * (1 - clamp(pose.feast / 1.2))) }
        if pose.misfire > 0.75 { glow = max(glow, 0.45 * sin(.pi * clamp((pose.misfire - 0.75) / 0.6))) }
        if pose.ash >= 0 { glow = max(glow, (0.55 + 0.15 * sin(t * 13)) * ease(pose.ash / 0.4)) }   // leaving ablaze, flickering white-hot
        if glow > 0.02 {
            var g = ctx
            g.blendMode = .plusLighter
            g.opacity = glow * clamp(pose.reveal)
            g.draw(image, in: rect)
        }

        // in front of the bird
        if pose.rune >= 0 { fireWall(floor, t: t, age: pose.rune, nudge: pose.nudge, front: true) }
        if pose.rebirth >= 0 { flungAsh(body, age: pose.rebirth) }
        if pose.reveal > 0.5, pose.rebirth < 0 || pose.rebirth >= hotAt {   // ash sheds no embers
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

    /// The middle of the ash, under its feet (sprite grid).
    private static let spotX = 32.0
    private static let ashes = [Color(red: 0.59, green: 0.56, blue: 0.56), Color(red: 0.41, green: 0.38, blue: 0.38),
                                Color(red: 0.26, green: 0.24, blue: 0.24), Color(red: 0.15, green: 0.14, blue: 0.15)]

    /// The perched frame's opaque pixels (window canvas, art px, one per pixel): where the ash flies to.
    static let perchPixels: [CGPoint] = {
        let w = perch.width, h = perch.height
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(perch, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
        return (0 ..< w * h).filter { px[$0 * 4 + 3] > 20 }.map { CGPoint(x: $0 % w, y: $0 / w) }
    }()
    static let perchTop = perchPixels.map(\.y).min()!, perchBottom = perchPixels.map(\.y).max()!

    /// When the ash reaches the perched frame's row `y`: the bird is built from its bottom row up to its top.
    static func built(row y: Double) -> Double { buildAt + (perchBottom - y) / (perchBottom - perchTop) * buildLength }

    /// Built out of the gathering ash: grey below the line the ash has reached, an ember glow along it; at `hotAt` it
    /// catches fire, flashing white-hot into its own colours.
    private static func ashBird(_ ctx: GraphicsContext, image: Image, rect: CGRect, unit: CGFloat, age: Double) {
        guard age >= buildAt else { return }
        let far = 1e5
        func band(_ top: CGFloat, _ bottom: CGFloat) -> Path { Path(CGRect(x: -far, y: top, width: 2 * far, height: bottom - top)) }
        let rows = perchBottom + 1 - perchTop
        let front = rect.minY + (perchBottom + 1 - rows * clamp((age - buildAt) / buildLength)) * unit
        var c = ctx
        c.clip(to: band(front, far))
        let fire = ease((age - hotAt) / 0.35)
        if fire < 1 {
            var ash = c
            ash.addFilter(.saturation(0))
            ash.addFilter(.colorMultiply(ashes[0]))
            ash.draw(image, in: rect)
            var glow = c   // embers still alive in the ash
            glow.addFilter(.colorMultiply(orange))
            glow.blendMode = .plusLighter
            glow.opacity *= (0.12 + 0.08 * sin(age * 9) * sin(age * 5.3)) * (1 - fire)
            glow.draw(image, in: rect)
        }
        if fire > 0 {
            var lit = c
            lit.opacity *= fire
            lit.draw(image, in: rect)
        }
        let flash = sin(.pi * clamp((age - hotAt) / 0.6))
        let edge = age < buildAt + buildLength ? 1.0 : 0
        for (k, area) in [(flash, band(-far, far)), (edge, band(front - 2 * unit, front + 2 * unit))] where k > 0.02 {
            var hot = c
            hot.clip(to: area)
            hot.addFilter(.colorMultiply(pale))
            hot.blendMode = .plusLighter
            hot.opacity *= k
            hot.draw(image, in: rect)
            hot.draw(image, in: rect)
        }
    }

    /// Behind the bird as its wings snap open: a white-gold flash and a warm glow that holds through its pose, then cools.
    private static func wakeGlow(_ ctx: GraphicsContext, unit: CGFloat, dx: Double, dy: Double, age: Double) {
        let a = age - wingsAt - snapLength
        guard a >= -0.03, a < 1.3 else { return }
        let flash = a >= 0 ? exp(-a / 0.07) : 0.6, warm = (1 - ease((a - 0.45) / 0.8)) * (0.85 + 0.15 * sin(2 * .pi * a * 1.3))   // pulses as it cools
        var c = ctx
        c.blendMode = .plusLighter
        c.translateBy(x: (dx + 34) * unit, y: (dy + 26) * unit)
        c.scaleBy(x: 1.15, y: 1)
        let disc = Path(ellipseIn: CGRect(x: -44 * unit, y: -44 * unit, width: 88 * unit, height: 88 * unit))
        for (colour, k) in [(Color(red: 1, green: 0.92, blue: 0.67), flash), (Color(red: 1, green: 0.59, blue: 0.16), 0.6 * warm)] where k > 0.01 {
            let stops = [1, 0.56, 0.25, 0.06, 0].enumerated().map { Gradient.Stop(color: colour.opacity(k * $1), location: Double($0) / 4) }
            c.fill(disc, with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 44 * unit))
        }
    }

    /// The last of the ash, flung out by its wings as they snap open.
    /// shortcut: the flung ash is cut off at the window's edges; draw it in a screen overlay if that ever shows.
    private static func flungAsh(_ body: Pixels, age: Double) {
        let burst = age - wingsAt - snapLength
        guard burst >= 0, burst < 1.3 else { return }
        let fly = (1 - exp(-burst * 3.2)) / 3.2   // thrown out, air drag slows it
        for i in 0 ..< 140 {
            let angle = hash(i, 12) * 2 * .pi, d = (50 + hash(i, 13) * 90) * fly
            body.dot(24 + cos(angle) * (8 + d) * 1.25, 36 + sin(angle) * (6 + d) * 0.8 + 18 * burst * burst * hash(i, 14) - 6 * burst,
                     ashes[Int(hash(i, 15) * 4)], 1 - pow(burst / 1.3, 2))
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

    /// The arrival begins: the ash that builds the bird, over the screen round its spot.
    @MainActor static func spreadAshes(windowOrigin: CGPoint, facingRight: Bool) {
        overlay(at: CGPoint(x: spotX, y: ground), windowOrigin: windowOrigin, facingRight: facingRight, for: buildAt + buildLength + 0.1) { spot, _ in
            AshField(spot: spot, unit: RobotView.scale, facingRight: facingRight)
        }
    }

    /// Thousands of grey flakes of ash drifting down round its spot, a very rare one still red; then lifting and
    /// streaming in on arcs, each to its own pixel of the folded bird, the bottom rows first.
    struct AshField: View {
        /// Half the drift's width: it covers about two and a half times the perched bird's width.
        nonisolated static let greys = [0.78, 0.66, 0.55, 0.45, 0.36, 0.28, 0.2].map { Color(white: $0) }
        nonisolated static let reds = [red, Color(red: 0.43, green: 0.03, blue: 0.04)]
        nonisolated static let count = 2000, spread = 1.25 * Double(perchPixels.map(\.x).max()! - perchPixels.map(\.x).min()! + 1)
        let spot: CGPoint   // view coordinates, y down
        let unit: CGFloat
        let facingRight: Bool
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
                let px = Pixels(ctx: c, unit: unit, dx: spot.x / unit, dy: spot.y / unit)   // art px from the spot
                let n = perchPixels.count
                for i in 0 ..< Self.count {
                    // every pixel of the bird gets a flake, the rest fill in at random
                    let t = perchPixels[i < n ? i : Int(hash(i, 80) * Double(n))]
                    let arrive = built(row: t.y)
                    guard age < arrive else { continue }
                    let tx = (t.x + 0.5 - Double(padLeft) - spotX) * (facingRight ? -1 : 1), ty = t.y - Double(padTop) - ground
                    // where it lies: a wide drift, thickest round the spot
                    let sx = (hash(i, 81) + hash(i, 82) + hash(i, 98) - 1.5) / 1.5 * 1.3 * Self.spread   // thinning out to the sides, no edge
                    let sy = (hash(i, 83) - 0.6) * 12 * max(0, 1 - 0.6 * abs(sx) / Self.spread)
                    // falling freely like ash: each at its own slow, steady speed from its own height (some already on the
                    // way down when it starts), all carried the same way on the wind, swaying as they go
                    let height = 60 + 220 * hash(i, 89), fall = height / (110 + 70 * hash(i, 94)), lands = 0.4 + 1.1 * hash(i, 84)
                    let k = clamp((age - lands + fall) / fall), left = (1 - k) * fall   // seconds before it lands
                    let blown = -(28 + 14 * hash(i, 87)) * left + sin(age * (2 + 2 * hash(i, 95)) + 6 * hash(i, 96)) * (3 + 6 * hash(i, 97)) * min(1, left)
                    let dist = hypot(tx - sx, ty - sy)
                    let leave = max(gatherAt + hash(i, 85) * 0.4, arrive - (0.45 + dist / 260))
                    let u = clamp((age - leave) / (arrive - leave)), e = ease(u), arc = sin(.pi * u)
                    let x = sx + (tx - sx) * e + arc * (hash(i, 86) - 0.5) * 30 + blown
                    let y = sy + (ty - sy) * e - arc * (12 + 26 * hash(i, 88)) * min(1, dist / 120) - height * pow(1 - k, 1.15)
                    let glint = hash(i, 90) < 0.03   // shades of grey, a very rare one still red
                    let colour = glint ? Self.reds[Int(hash(i, 91) * 2)] : Self.greys[Int(hash(i, 92) * Double(Self.greys.count))]
                    let opacity = ease(age / 0.4) * (glint && u == 0 ? 0.6 + 0.4 * sin(age * 7 + Double(i)) : 1)
                    px.dot(x, y, colour, opacity, size: hash(i, 93) < 0.3 && u < 0.7 ? 2 : 1)
                }
            }
        }
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
