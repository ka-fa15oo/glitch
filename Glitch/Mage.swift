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
    /// The robe in 2 px rows so its hem can ripple while gliding.
    private static let robeRows: [CGImage] = stride(from: 0, to: Sprite.height, by: 2).compactMap {
        set.tunic.cropping(to: CGRect(x: 0, y: $0, width: Sprite.width, height: 2))
    }

    static func draw(_ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        var layer = outer
        layer.opacity = max(0, min(1, pose.reveal))
        layer.drawLayer { inner in drawBody(inner, unit: unit, size: size, t: t, pose: pose) }
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

        let flutter = 2.2 + 3 * pose.carriedAmount + 4 * pose.fallAmount
        rows(set.capeRows, ctx, amount: flutter, speed: 2 * .pi / 2.6)
        rows(robeRows, ctx, amount: 1.4 + flutter * 0.4, speed: 2 * .pi / 1.8)
        put(staff, ctx, dy: breath * 0.3)
        put(set.armFarUpper, ctx, dy: breath * 0.5)
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

    private static func load(_ name: String) -> CGImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { fatalError("Missing sprite \(name).png") }
        return cg
    }
}
