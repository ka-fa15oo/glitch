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
    private static let neck = CGPoint(x: 36, y: 33)   // 4 px left of centre: the sprites lean forward (make_elf.py LEAN)
    /// The dress in 2 px rows so its hem can ripple while gliding.
    private static let dressRows: [CGImage] = stride(from: 0, to: Sprite.height, by: 2).compactMap {
        set.tunic.cropping(to: CGRect(x: 0, y: $0, width: Sprite.width, height: 2))
    }

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

        let flutter = 2.2 + 3 * pose.carriedAmount + 4 * pose.fallAmount
        put(wings, ctx, dy: breath * 0.6)
        rows(set.capeRows, ctx, amount: flutter, speed: 2 * .pi / 2.6)   // green cape and the long hair over it
        // bare legs, knees bent and feet tucked back, under the short dress; the feet sway a pixel as she floats
        let sway = (sin(t * 2 * .pi / 3.2 + 0.8) * 0.6 * grounded).rounded()
        put(set.thighL, ctx); put(set.shinL, ctx, dy: sway); put(set.footL, ctx, dy: sway)
        put(set.thighR, ctx); put(set.shinR, ctx, dy: -sway); put(set.footR, ctx, dy: -sway)
        rows(dressRows, ctx, amount: 1.4 + flutter * 0.4, speed: 2 * .pi / 1.8)
        put(set.armFarUpper, ctx, dy: breath * 0.5)
        put(wand, ctx, dy: breath * 0.4)
        put(set.armFarFore, ctx, dy: breath * 0.4)
        put(set.cloak, ctx, dy: breath * 0.5)

        let headDY = breath * 0.8 + pose.headDY
        put(set.head, ctx, dy: headDY, angle: pose.headRot, pivot: neck)
        if let eyes = set.eyes[pose.eyes] {
            put(eyes, ctx, dx: Double(pose.eyeDX), dy: headDY, angle: pose.headRot, pivot: neck)
        }
        put(set.armNearUpper, ctx, dy: breath * 0.5)
        put(set.armNearFore, ctx, dy: breath * 0.5)
    }
}
