import SwiftUI

/// Faelis, the fairy elf queen (Character 3). It shares the brain (breathing, blinking, drag, gravity) with the others
/// and hovers on sheer wings, bare legs under a short dress, holding a small blossom wand (sprites from Tools/make_elf.py).
enum Elf {
    static let id = "elf"
    static var isSelected: Bool { Prefs.d.string(forKey: Prefs.character) == id }

    private static let set = SpriteSet(prefix: "elf_")
    private static let wings = Sprite.loadShared("elf_wings")
    private static let wand = Sprite.loadShared("elf_wand")
    private static let shadow = Sprite.loadShared("elf_shadow")
    /// Click area: every part at rest, raised by the 2 px she hovers on average.
    static let hitMask: [Bool] = Sprite.coverage(
        [set.cape, set.thighL, set.shinL, set.footL, set.thighR, set.shinR, set.footR, set.tunic, set.cloak, set.armFarUpper, set.armFarFore, set.armNearUpper, set.armNearFore,
         set.head, wings, wand].map { ($0, CGPoint(x: 0, y: -2)) })
    static let hitBounds = Sprite.bounds(of: hitMask)
    /// The far hand that holds the wand (after the lean); the wand turns about it when she casts.
    private static let hand = CGPoint(x: 23.5, y: 55)
    private static let neck = CGPoint(x: 36, y: 33)   // 4 px left of centre: the sprites lean forward (make_elf.py LEAN)
    /// The dress in 2 px rows so its hem can ripple while gliding.
    private static let dressRows: [CGImage] = stride(from: 0, to: Sprite.height, by: 2).compactMap {
        set.tunic.cropping(to: CGRect(x: 0, y: $0, width: Sprite.width, height: 2))
    }

    /// She is always happy: the cross, startled and sad sounds the shared brain asks for come out as a giggle.
    static func voice(_ effect: SoundEffect) -> SoundEffect {
        [.angry, .surprised, .sad].contains(effect) ? .happy : effect
    }

    /// The wand's blossom tip at rest (after the lean); a click turns the wand by `flick` about the hand.
    private static let tip = CGPoint(x: 15, y: 40)
    static let flick = 0.5

    /// Click: the flowers leave the wand tip, raised by the flick, on a screen-wide overlay so they can fly far.
    @MainActor static func scatterFlowers(windowOrigin: CGPoint, facingRight: Bool) {
        let r = CGPoint(x: tip.x - hand.x, y: tip.y - hand.y)
        let x = hand.x + r.x * cos(flick) - r.y * sin(flick)
        let y = hand.y + r.x * sin(flick) + r.y * cos(flick) - 2
        let scale = RobotView.scale
        let px = (Double(RobotView.padLeft) + x) * scale
        let local = CGPoint(x: facingRight ? RobotView.canvasSize.width - px : px, y: (Double(RobotView.padTop) + y) * scale)
        let ground = (Double(RobotView.padTop) + 92) * scale
        ElfMeadow.openBurst(at: CGPoint(x: windowOrigin.x + local.x, y: windowOrigin.y + RobotView.canvasSize.height - local.y),
                            drop: ground - local.y, unit: scale * 2)
    }

    /// How wide the wings are (1 = as drawn): a gentle beat, faster and deeper when `busy` (carried or falling, 0...1).
    static func wingSpread(t: Double, busy: Double) -> Double {
        1 - (0.05 + 0.08 * busy) * (0.5 + 0.5 * sin(t * 2 * .pi * (1.6 + 2.4 * busy)))
    }

    /// Every `greeneryPeriod` s (wall clock) grass and little flowers sprout under her for `greeneryLength` s.
    static let greeneryPeriod = 70.0, greeneryLength = 7.0
    static func greeneryAge(t: Double) -> Double? {
        let a = (t + 30).truncatingRemainder(dividingBy: greeneryPeriod)
        return a < greeneryLength ? a : nil
    }

    /// Where the wings meet her back (after the lean): they beat about this line.
    private static let wingRoot = 37.0

    static func draw(_ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        var layer = outer
        layer.opacity = max(0, min(1, pose.reveal))
        layer.drawLayer { inner in drawBody(inner, unit: unit, size: size, t: t, pose: pose) }
    }

    private static func drawBody(_ base: GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        let breath = sin(t * 2 * .pi / 3.6)
        // floats a few pixels above the ground, bobbing slowly; carried or falling she just follows the brain
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

        // the shadow stays on the ground and shrinks a little as she rises
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

        let calm = (1 - pose.stepAmount) * (1 - pose.carriedAmount) * (1 - pose.fallAmount)
        if let age = greeneryAge(t: t), calm > 0.01 {
            var c = base
            c.opacity = calm
            drawGreenery(c, unit: unit, age: age, dx: bx)
        }

        let flutter = 2.2 + 3 * pose.carriedAmount + 4 * pose.fallAmount
        let busy = max(pose.carriedAmount, pose.fallAmount)
        var wingCtx = ctx
        wingCtx.translateBy(x: (bx + wingRoot) * unit, y: 0)
        wingCtx.scaleBy(x: wingSpread(t: t, busy: busy), y: 1)
        wingCtx.translateBy(x: -(bx + wingRoot) * unit, y: 0)
        put(wings, wingCtx, dy: breath * 0.6)
        drawWingSparkles(ctx, unit: unit, t: t, dx: bx, dy: by + breath * 0.6)
        rows(set.capeRows, ctx, amount: flutter, speed: 2 * .pi / 2.6)   // green cape and the long hair over it
        // bare legs, knees bent and feet tucked back, under the short dress; the feet sway a pixel as she floats
        let sway = (sin(t * 2 * .pi / 3.2 + 0.8) * 0.6 * grounded).rounded()
        put(set.thighL, ctx); put(set.shinL, ctx, dy: sway); put(set.footL, ctx, dy: sway)
        put(set.thighR, ctx); put(set.shinR, ctx, dy: -sway); put(set.footR, ctx, dy: -sway)
        rows(dressRows, ctx, amount: 1.4 + flutter * 0.4, speed: 2 * .pi / 1.8)
        // goodbye spell: the wand comes up straight, then flicks out as the sparkles leave its tip
        let e = pose.spell
        let lift = e >= 0 ? ElfMeadow.ease(e / 0.3) : 0
        // click: a quick flick up and back down
        let click = pose.cast >= 0 ? sin(.pi * min(1, pose.cast / 0.6)) : 0
        let wandAngle = e >= 0 ? 0.5 * lift - 0.85 * ElfMeadow.ease((e - 0.5) / 0.18) : flick * click
        put(set.armFarUpper, ctx, dy: breath * 0.5)
        put(wand, ctx, dy: breath * 0.4 - 2 * (lift + click), angle: wandAngle, pivot: hand)
        put(set.armFarFore, ctx, dy: breath * 0.4 - 2 * (lift + click))
        put(set.cloak, ctx, dy: breath * 0.5)

        let headDY = breath * 0.8 + pose.headDY
        put(set.head, ctx, dy: headDY, angle: pose.headRot, pivot: neck)
        if let eyes = set.eyes[pose.eyes] {
            put(eyes, ctx, dx: Double(pose.eyeDX), dy: headDY, angle: pose.headRot, pivot: neck)
        }
        put(set.armNearUpper, ctx, dy: breath * 0.5)
        put(set.armNearFore, ctx, dy: breath * 0.5)
        if pose.spell >= 0 { drawSpell(ctx, unit: unit, e: pose.spell, dx: bx, dy: by) }
    }

    /// Now and then a few motes of light drift down from one wing tip and fade.
    private static func drawWingSparkles(_ c: GraphicsContext, unit: CGFloat, t: Double, dx: Double, dy: Double) {
        let period = 3.5, life = 1.6
        let age = t.truncatingRemainder(dividingBy: period)
        guard age < life else { return }
        let tips = [CGPoint(x: 61, y: 8), CGPoint(x: 8, y: 12), CGPoint(x: 64, y: 59), CGPoint(x: 16, y: 59)]
        let tip = tips[Int(t / period) % tips.count]
        var light = Path(), gold = Path()
        for i in 0 ..< 3 {
            let x = tip.x + Double(i - 1) * 2 + sin(age * 3 + Double(i)) * 1.2, y = tip.y + age * 9 + Double(i) * 3
            let rect = CGRect(x: (x + dx).rounded() * unit, y: (y + dy).rounded() * unit, width: unit, height: unit)
            if i == 1 { gold.addRect(rect) } else { light.addRect(rect) }
        }
        var c = c
        c.opacity = 0.9 * (1 - ElfMeadow.ease(age / life))
        c.fill(light, with: .color(Color(red: 0.69, green: 0.88, blue: 0.48)))
        c.fill(gold, with: .color(Color(red: 1.0, green: 0.85, blue: 0.29)))
    }

    /// Grass blades and little flowers sprout on the ground round her, the middle first, then wither away.
    private static func drawGreenery(_ c: GraphicsContext, unit: CGFloat, age: Double, dx: Double) {
        let ground = 93.0
        var rng = SplitMix(seed: 0x6EED)
        func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
        var blades = Path(), tips = Path(), hearts = Path()
        var blooms = Array(repeating: Path(), count: ElfMeadow.petals.count)
        func cell(_ path: inout Path, _ x: Double, _ y: Double) {
            path.addRect(CGRect(x: (x + dx).rounded() * unit, y: y.rounded() * unit, width: unit, height: unit))
        }
        let wither = ElfMeadow.ease((age - (greeneryLength - 1.5)) / 1.5)
        for i in 0 ..< 46 {
            let x = -10 + random() * 92, tall = 2 + random() * 5
            let start = abs(x - 37) / 47 * 1.2 + random() * 0.3                 // spreads out from under her
            let h = Int((tall * ElfMeadow.ease((age - start) / 0.6) * (1 - wither)).rounded())
            guard h > 0 else { continue }
            for k in 0 ..< h { cell(&blades, x + (k == h - 1 && i % 2 == 0 ? 1 : 0), ground - Double(k)) }
            cell(&tips, x, ground - Double(h))
            if i % 4 == 0, age - start > 1.0, h >= 3 {                           // a few blossom on the tallest blades
                let top = ground - Double(h) - 1, tone = i % ElfMeadow.petals.count
                cell(&hearts, x, top)
                for (ox, oy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { cell(&blooms[tone], x + ox, top + oy) }
            }
        }
        c.fill(blades, with: .color(ElfMeadow.stem))
        c.fill(tips, with: .color(ElfMeadow.leaf))
        for (path, color) in zip(blooms, ElfMeadow.petals) { c.fill(path, with: .color(color)) }
        c.fill(hearts, with: .color(ElfMeadow.heart))
    }

    /// Sparkles stream from the wand tip and wind round her until she is wrapped in them, twinkling as they go.
    private static func drawSpell(_ c: GraphicsContext, unit: CGFloat, e: Double, dx: Double, dy: Double) {
        let palette: [Color] = [Color(red: 0.69, green: 0.88, blue: 0.48), Color(red: 1.0, green: 0.85, blue: 0.29), .white]
        var paths = Array(repeating: Path(), count: palette.count)
        func cell(_ tone: Int, _ x: Double, _ y: Double) {
            paths[tone].addRect(CGRect(x: (x + dx).rounded() * unit, y: (y + dy).rounded() * unit, width: unit, height: unit))
        }
        let fade = 1 - ElfMeadow.ease((e - 1.4) / 0.35)
        for i in 0 ..< 32 {
            let shown = e - (0.55 + Double(i) * 0.022)
            guard shown > 0 else { continue }
            // a spiral round her body, leaving from the flicked wand tip on her left
            let a = Double.pi + Double(i) * 0.38 + shown * 2.0
            let x = 34 + cos(a) * (18 + Double(i) * 0.4), y = 52 + sin(a) * (28 + Double(i) * 0.6)
            let tone = i % 3
            cell(tone, x, y)
            if (i + Int(e * 12)) % 2 == 0 {
                cell(tone, x - 1, y); cell(tone, x + 1, y); cell(tone, x, y - 1); cell(tone, x, y + 1)
            } else {
                cell(2, x - 1, y - 1); cell(2, x + 1, y + 1)
            }
        }
        var c = c
        c.opacity = fade
        for (path, color) in zip(paths, palette) { c.fill(path, with: .color(color)) }
    }
}
