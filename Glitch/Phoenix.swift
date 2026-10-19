import SwiftUI

/// The crimson phoenix (Character 5). It shares the brain (drag, gravity, arrival and farewell timing) with the knight,
/// but draws itself from four wing-flap frames (sprites from Tools/make_phoenix.py) instead of the jointed rig.
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

    /// Seconds per frame: a slow, heavy beat at rest, a frantic one when carried or falling.
    static func frameTime(busy: Double) -> Double { 0.2 - 0.11 * busy }

    static func draw(_ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) {
        let busy = max(pose.carriedAmount, pose.fallAmount)
        let frame = frames[Int(t / frameTime(busy: busy)) % frames.count]
        let bx = pose.bodyDX + pose.shakeX, by = pose.bodyDY

        var ctx = outer
        ctx.opacity = max(0, min(1, pose.reveal))
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
        let rect = CGRect(x: (bx - Double(padLeft)) * unit, y: (by - Double(padTop)) * unit,
                          width: canvas.width * unit, height: canvas.height * unit)
        ctx.draw(Image(decorative: frame, scale: 1).interpolation(.none), in: rect)
    }
}
