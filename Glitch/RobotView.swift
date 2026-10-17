import SwiftUI

struct RobotView: View {
    static let scale: CGFloat = 2
    /// Transparent room around the sprite so the sword can swing and a carried body can dangle.
    static let padLeft = 22, padRight = 18, padTop = 14, padBottom = 14
    static let canvasSize = CGSize(
        width: CGFloat(Sprite.width + padLeft + padRight) * scale,
        height: CGFloat(Sprite.height + padTop + padBottom) * scale
    )

    /// The grave-cross revealed by a double-click, right above the head (view coordinates, origin top-left).
    static let quitRect = CGRect(x: canvasSize.width / 2 - 11, y: 18, width: 22, height: 22)

    var brain: Brain?
    var fixedTime: Double?
    var fixedPose = Brain.Pose()

    var body: some View {
        if let fixedTime {
            robot(at: fixedTime, pose: fixedPose)
        } else {
            TimelineView(.animation) { timeline in
                robot(at: timeline.date.timeIntervalSinceReferenceDate, pose: brain?.current ?? Brain.Pose())
            }
        }
    }

    private func robot(at t: Double, pose: Brain.Pose) -> some View {
        Canvas { context, size in
            let unit = Self.scale
            let sprite = CGSize(width: CGFloat(Sprite.width) * unit, height: CGFloat(Sprite.height) * unit)
            var root = context
            if pose.facingRight {
                root.translateBy(x: size.width, y: 0)
                root.scaleBy(x: -1, y: 1)
            }
            root.translateBy(x: CGFloat(Self.padLeft) * unit, y: CGFloat(Self.padTop) * unit)

            if pose.glitch > 0.01 {
                let frame = Int(t * 30)
                var rng = SplitMix(seed: UInt64(truncatingIfNeeded: frame) &* 0x9E37_79B9)
                let bands = 12
                let bandHeight = sprite.height / CGFloat(bands)
                for i in 0 ..< bands {
                    var ctx = root
                    ctx.clip(to: Path(CGRect(x: -sprite.width, y: CGFloat(i) * bandHeight,
                                             width: sprite.width * 3, height: bandHeight + 0.5)))
                    let shifted = rng.next() % 100 < UInt64(35 * pose.glitch + 10)
                    let offset = shifted ? Double(Int(rng.next() % 9) - 4) * pose.glitch : 0
                    ctx.translateBy(x: offset * unit, y: 0)
                    Self.drawCharacter(&ctx, unit: unit, size: sprite, t: t, pose: pose)
                }
                var ghost = root
                ghost.opacity = 0.28 * pose.glitch
                ghost.translateBy(x: 2 * unit, y: 0)
                Self.drawCharacter(&ghost, unit: unit, size: sprite, t: t, pose: pose)
            } else {
                var ctx = root
                Self.drawCharacter(&ctx, unit: unit, size: sprite, t: t, pose: pose)
            }
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .overlay(alignment: .topLeading) {
            if pose.showQuit {
                Text("†")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.93, green: 0.35, blue: 0.35))
                    .shadow(color: Color(red: 0.1, green: 0.0, blue: 0.02), radius: 0, x: 1, y: 1)
                    .frame(width: Self.quitRect.width, height: Self.quitRect.height)
                    .offset(x: Self.quitRect.minX, y: Self.quitRect.minY)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - drawing helpers

    /// Draws a full-size sprite after translating it (art px), then rotating about `pivot` (sprite coordinates).
    private static func draw(
        _ image: CGImage, _ ctx: GraphicsContext, unit: CGFloat, size: CGSize,
        translate: CGPoint = .zero, angle: Double = 0, pivot: CGPoint = .zero
    ) {
        var c = ctx
        c.translateBy(x: translate.x * unit, y: translate.y * unit)
        if angle != 0 {
            c.translateBy(x: pivot.x * unit, y: pivot.y * unit)
            c.rotate(by: .radians(angle))
            c.translateBy(x: -pivot.x * unit, y: -pivot.y * unit)
        }
        c.draw(Image(decorative: image, scale: 1).interpolation(.none), in: CGRect(origin: .zero, size: size))
    }

    private static func rotate(_ p: CGPoint, by a: Double, about c: CGPoint) -> CGPoint {
        let x = p.x - c.x, y = p.y - c.y
        return CGPoint(x: c.x + x * cos(a) - y * sin(a), y: c.y + x * sin(a) + y * cos(a))
    }

    private static func angle(from a: CGPoint, to b: CGPoint) -> Double {
        atan2(b.y - a.y, b.x - a.x)
    }

    /// Two-bone IK: returns the elbow position and the hand position actually reached.
    private static func solveArm(
        shoulder s: CGPoint, upperLength l1: Double, lowerLength l2: Double,
        target: CGPoint, outwardSign: Double
    ) -> (elbow: CGPoint, hand: CGPoint) {
        var dx = target.x - s.x, dy = target.y - s.y
        var d = hypot(dx, dy)
        let lo = abs(l1 - l2) + 0.3, hi = l1 + l2 - 0.2
        let clamped = min(hi, max(lo, d))
        if d > 0.001 { dx *= clamped / d; dy *= clamped / d }
        d = clamped
        let a = atan2(dy, dx)
        let cosA = max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))
        let bend = acos(cosA)
        func elbow(_ sign: Double) -> CGPoint {
            CGPoint(x: s.x + l1 * cos(a + sign * bend), y: s.y + l1 * sin(a + sign * bend))
        }
        let e1 = elbow(1), e2 = elbow(-1)
        func score(_ e: CGPoint) -> Double { outwardSign * e.x * 0.6 + e.y }
        let chosen = score(e1) >= score(e2) ? e1 : e2
        return (chosen, CGPoint(x: s.x + dx, y: s.y + dy))
    }

    // MARK: - blood ribbon ("Mea Culpa" style): grows from the sword, curls over the head, then withers

    private struct Ribbon {
        let points: [CGPoint]
        let width: Double
        let delay: Double
    }

    private static let ribbons: [Ribbon] = [
        Ribbon(points: [(8, 72), (-1, 60), (-3, 46), (1, 34), (9, 25), (19, 21), (27, 26), (25, 34)].map { CGPoint(x: $0.0, y: $0.1) },
               width: 6.5, delay: 0),
        Ribbon(points: [(30, 7), (41, 1), (53, 6), (60, 17), (58, 30)].map { CGPoint(x: $0.0, y: $0.1) },
               width: 2.6, delay: 0.1),
        Ribbon(points: [(2, 66), (-8, 52), (-8, 36), (-2, 24)].map { CGPoint(x: $0.0, y: $0.1) },
               width: 3.6, delay: 0.05),
    ]

    private static func spline(_ p: [CGPoint], _ u: Double) -> CGPoint {
        let n = p.count - 1
        let f = min(Double(n) - 0.0001, max(0, u * Double(n)))
        let i = Int(f), t = f - Double(i)
        let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(n, i + 2)]
        func cr(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
        }
        return CGPoint(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y))
    }

    private static func drawBlood(_ ctx: inout GraphicsContext, unit: CGFloat, age: Double, t: Double) {
        func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }
        var body = Path(), mid = Path(), core = Path()
        func pixel(_ path: inout Path, _ x: Double, _ y: Double) {
            path.addRect(CGRect(x: floor(x) * unit, y: floor(y) * unit, width: unit, height: unit))
        }
        for (index, ribbon) in ribbons.enumerated() {
            let grow = ease((age - ribbon.delay) / 0.45)
            let wither = ease((age - 0.72 - ribbon.delay * 0.5) / 0.42)
            if grow <= 0 || wither >= 1 { continue }
            let samples = 44
            for i in 0 ... samples {
                let u = Double(i) / Double(samples)
                if u > grow || u < wither * grow { continue }
                var p = spline(ribbon.points, u)
                let wave = sin(t * 3.2 + u * 9 + Double(index)) * 0.9 * u
                p.x += wave
                p.y += cos(t * 2.4 + u * 7) * 0.5 * u
                let taper = min(1, (grow - u) * 7 + 0.25) * min(1, (u - wither * grow) * 9 + 0.25)
                let w = ribbon.width * (0.35 + 0.65 * sin(.pi * min(1, u * 1.05))) * taper * (1 - 0.35 * wither)
                let r = max(0.5, w / 2)
                var dy = -Int(r.rounded(.up))
                while dy <= Int(r.rounded(.up)) {
                    var dx = -Int(r.rounded(.up))
                    while dx <= Int(r.rounded(.up)) {
                        let d = hypot(Double(dx), Double(dy))
                        if d <= r {
                            pixel(&body, p.x + Double(dx), p.y + Double(dy))
                            if d <= r * 0.62 { pixel(&mid, p.x + Double(dx) - 0.5, p.y + Double(dy) - 0.5) }
                            if d <= r * 0.3 { pixel(&core, p.x + Double(dx) - 1, p.y + Double(dy) - 1) }
                        }
                        dx += 1
                    }
                    dy += 1
                }
            }
        }
        let fade = 1 - ease((age - 1.0) / 0.2)
        ctx.opacity = 0.95 * fade
        ctx.fill(body, with: .color(Color(red: 0.42, green: 0.05, blue: 0.07)))
        ctx.fill(mid, with: .color(Color(red: 0.69, green: 0.1, blue: 0.1)))
        ctx.fill(core, with: .color(Color(red: 0.93, green: 0.22, blue: 0.18)))
        ctx.opacity = 1
    }

    // MARK: - sparks

    private static let goldLight = Color(red: 0.96, green: 0.80, blue: 0.36)
    private static let goldDark = Color(red: 0.78, green: 0.55, blue: 0.16)

    /// Sparks thrown off the sword point while it scrapes the ground, then one rising to the shoulder.
    private static func drawSparks(_ ctx: GraphicsContext, unit: CGFloat, tip: CGPoint, pose: Brain.Pose) {
        var light = Path(), dark = Path()
        func pixel(_ path: inout Path, _ x: Double, _ y: Double) {
            path.addRect(CGRect(x: floor(x) * unit, y: floor(y) * unit, width: unit, height: unit))
        }
        if pose.scrapeAge >= 0 {
            var rng = SplitMix(seed: 0x5A9C)
            func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
            let rate = 70.0, life = 0.55
            for k in 0 ..< 90 {
                let born = Double(k) / rate * 0.9                      // streams out over the first second
                let vx = (random() * 2 - 1) * 45 - 14, l = life * (0.6 + 0.4 * random())
                let vy = -(30 + 80 * random()) - (k % 6 == 0 ? 70 : 0)         // a few leap higher
                let a = pose.scrapeAge - born
                if a < 0 || a > l { continue }
                let x = tip.x + vx * a, y = min(94.5, tip.y + vy * a + 0.5 * 260 * a * a)
                let fade = 1 - a / l
                if fade > 0.7 {                                      // just born: 2 px, bright
                    pixel(&light, x, y); pixel(&light, x + 1, y); pixel(&light, x, y + 1); pixel(&dark, x + 1, y + 1)
                } else if fade > 0.4 { pixel(&light, x, y); pixel(&dark, x + 1, y + 1) }
                else if fade > 0.1 { pixel(&dark, x, y) }
            }
        }
        if pose.sparkFlight >= 0 {
            let p = pose.sparkFlight, e = p * p * (3 - 2 * p)
            let goal = CGPoint(x: 56, y: 31)
            let x = tip.x + (goal.x - tip.x) * e
            let y = tip.y + (goal.y - tip.y) * e - 10 * sin(.pi * p)
            pixel(&light, x, y); pixel(&light, x + 1, y); pixel(&light, x, y + 1); pixel(&dark, x + 1, y + 1)
            pixel(&dark, x - 2 * (goal.x - tip.x) * 0.02, y + 2)   // a short tail
        }
        ctx.fill(light, with: .color(goldLight))
        ctx.fill(dark, with: .color(goldDark))
    }

    private static func drawCharacter(
        _ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose
    ) {
        if pose.cocoonAge >= 0, pose.cocoonHold {
            // goodbye: a blood storm whirls round the kneeling knight and takes it away
            BloodStorm.draw(&outer, unit: unit, age: pose.cocoonAge, t: t, side: .behind)
            var layer = outer
            layer.opacity = max(0, min(1, pose.reveal))
            layer.drawLayer { inner in
                var c = inner
                drawSide(&c, unit: unit, size: size, t: t, pose: pose, shadow: true)
            }
            BloodStorm.draw(&outer, unit: unit, age: pose.cocoonAge, t: t, side: .inFront)
        } else if pose.reveal < 0.999 || pose.cocoonAge >= 0 {
            // appearing inside the blood: the character fades in as the blood rises and falls away
            var layer = outer
            layer.opacity = max(0, min(1, pose.reveal))
            layer.drawLayer { inner in
                var c = inner
                drawSide(&c, unit: unit, size: size, t: t, pose: pose, shadow: true)
            }
            if pose.cocoonAge >= 0 {
                BloodRise.draw(&outer, unit: unit, age: pose.cocoonAge, t: t)
            }
        } else {
            drawSide(&outer, unit: unit, size: size, t: t, pose: pose, shadow: true)
            if pose.splashAge >= 0 { BloodRise.drawSplash(&outer, unit: unit, age: pose.splashAge, t: t) }
        }
    }

    private static func drawSide(
        _ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose, shadow: Bool
    ) {
        let breath = sin(t * 2 * .pi / 3.6)
        let set = Sprite.sets[pose.view]!
        let rig = Rig.of(pose.view)
        let ref = Skeleton.self           // the brain speaks in 3/4-view coordinates
        let bx = pose.bodyDX + pose.shakeX

        if shadow {
            draw(Sprite.shadow, outer, unit: unit, size: size)
            if pose.bloodAge >= 0 { drawBlood(&outer, unit: unit, age: pose.bloodAge, t: t) }
        }

        let turned = outer

        // legs first: forward kinematics, then drop the body so the lowest foot touches the ground
        struct LegAngles { var thigh: Double; var bend: Double }
        /// A leg's swing angle is measured from vertical (+ = foot forward, towards the sword side);
        /// walking is the difference from the rest pose the legs are drawn in.
        let restSwingL = atan2(rig.hipL.x - rig.ankleL.x, rig.ankleL.y - rig.hipL.y)
        let restSwingR = atan2(rig.hipR.x - rig.ankleR.x, rig.ankleR.y - rig.hipR.y)
        func angles(phase: Double, rest: Double, front: Bool) -> LegAngles {
            let phi = pose.stepPhase + phase
            let swing = 0.06 + 0.38 * sin(phi)
            var thigh = pose.stepAmount * (swing - rest)
            var bend = -pose.stepAmount * 0.9 * pow(max(0, cos(phi)), 2)
            if pose.kneel > 0 {
                // one knee down: the front leg's thigh swings forward with the shin upright, the back thigh stays
                // under the hip with the shin folded flat behind it
                thigh += pose.kneel * (front ? 1.2 : -0.34)
                bend += pose.kneel * (front ? -1.0 : -1.56)
            }
            if pose.crouch > 0 {
                thigh += pose.crouch * 0.5
                bend += -pose.crouch * 0.95
            }
            if pose.kick > 0 {
                thigh += pose.kick * 0.5 * sin(pose.kickPhase + phase)
                bend += -pose.kick * 0.6 * max(0, sin(pose.kickPhase + phase + 1.2))
            }
            return LegAngles(thigh: thigh, bend: bend)
        }
        let la = angles(phase: 0, rest: restSwingL, front: false), ra = angles(phase: .pi, rest: restSwingR, front: true)
        /// The ankle stays nearly flat: the foot only follows the shin a little.
        func footAngle(_ a: LegAngles) -> Double { (a.thigh + a.bend) * 0.25 * (1 - pose.kneel) }
        func footY(_ a: LegAngles, hip: CGPoint, knee: CGPoint, ankle: CGPoint) -> Double {
            let k = rotate(knee, by: a.thigh, about: hip)
            let anklePos = rotate(CGPoint(x: k.x + (ankle.x - knee.x), y: k.y + (ankle.y - knee.y)),
                                  by: a.thigh + a.bend, about: k)
            let f = rotate(CGPoint(x: anklePos.x + rig.footDX, y: anklePos.y + 6), by: footAngle(a), about: anklePos)
            return f.y
        }
        var groundShift = 0.0
        if pose.carriedAmount < 0.999 {
            let lowest = max(footY(la, hip: rig.hipL, knee: rig.kneeL, ankle: rig.ankleL),
                             footY(ra, hip: rig.hipR, knee: rig.kneeR, ankle: rig.ankleR))
            groundShift = max(0, 94 - lowest) * (1 - pose.carriedAmount)
        }
        let by = pose.bodyDY + groundShift

        // a carried character swings from the point it is held at; landing squashes it against the ground
        var ctx = turned
        if pose.squash > 0.01 {
            let baseline = CGPoint(x: 39, y: 94)
            ctx.translateBy(x: baseline.x * unit, y: baseline.y * unit)
            ctx.scaleBy(x: 1 + 0.14 * pose.squash, y: 1 - 0.12 * pose.squash)
            ctx.translateBy(x: -baseline.x * unit, y: -baseline.y * unit)
        }
        if abs(pose.hang) > 0.0005 {
            ctx.translateBy(x: pose.hangPivot.x * unit, y: pose.hangPivot.y * unit)
            ctx.rotate(by: .radians(pose.hang))
            ctx.translateBy(x: -pose.hangPivot.x * unit, y: -pose.hangPivot.y * unit)
        }

        func plain(_ image: CGImage, dy: Double = 0, in c: GraphicsContext) {
            draw(image, c, unit: unit, size: size, translate: CGPoint(x: 0, y: dy))
        }

        // cape: each 2px row sways on its own, more towards the hem, more when walking
        func drawCape() {
            let flutter = 1.8 + 1.4 * pose.stepAmount + 1.4 * pose.carriedAmount + 2.8 * pose.fallAmount
                + 3.8 * abs(pose.fling) + 3.6 * pose.wind
            let streamBase = pose.view == .threeQuarter ? 2.6 : 0.6
            for (i, row) in set.capeRows.enumerated() {
                let y = Double(i * 2)
                let k = max(0, (y - 28) / 60)
                let kk = k * k
                var wave = (sin(t * 2 * .pi / 3.4 - k * 2.4) * 2.4 + sin(t * 2 * .pi / 1.9 - k * 3.4) * 1.1) * flutter
                // fast ripples run down the cloth in a fall or a gale
                wave += sin(t * 16 - k * 6 + Double(i) * 0.25) * (0.5 + 3.2 * (pose.fallAmount + pose.wind + abs(pose.fling))) * k
                // dragged: trails behind the pull; falling: the hem is thrown up and flares out; gale: blown to one side
                let flingShift = -pose.fling * 22 * kk + pose.wind * 32 * kk
                let lift = (22 * pose.fallAmount + 12 * abs(pose.fling) + 9 * pose.wind) * kk
                let flare = 1 + 0.35 * pose.fallAmount * kk
                let dx = (wave * kk - bx * k - pose.torsoRot * 6 * (1 - k) + flingShift + streamBase * kk).rounded()
                let rect = CGRect(x: (dx + (1 - flare) * 38) * unit, y: (y + breath * 0.2 + by - lift) * unit,
                                  width: size.width * flare, height: 2 * unit + 0.6)
                ctx.draw(Image(decorative: row, scale: 1).interpolation(.none), in: rect)
            }
        }
        if !rig.capeInFront { drawCape() }

        func leg(thigh: CGImage, shin: CGImage, foot: CGImage, hip: CGPoint, knee: CGPoint, ankle: CGPoint, a: LegAngles) {
            let k = rotate(knee, by: a.thigh, about: hip)
            let tx = bx * -0.4
            draw(thigh, ctx, unit: unit, size: size, translate: CGPoint(x: tx, y: by), angle: a.thigh, pivot: hip)
            draw(shin, ctx, unit: unit, size: size,
                 translate: CGPoint(x: k.x - knee.x + tx, y: k.y - knee.y + by),
                 angle: a.thigh + a.bend, pivot: knee)
            let shinEnd = rotate(CGPoint(x: k.x + (ankle.x - knee.x), y: k.y + (ankle.y - knee.y)),
                                 by: a.thigh + a.bend, about: k)
            draw(foot, ctx, unit: unit, size: size,
                 translate: CGPoint(x: shinEnd.x - ankle.x + tx, y: shinEnd.y - ankle.y + by),
                 angle: footAngle(a), pivot: ankle)
        }
        leg(thigh: set.thighL, shin: set.shinL, foot: set.footL, hip: rig.hipL, knee: rig.kneeL, ankle: rig.ankleL, a: la)
        leg(thigh: set.thighR, shin: set.shinR, foot: set.footR, hip: rig.hipR, knee: rig.kneeR, ankle: rig.ankleR, a: ra)

        plain(set.sash, dy: by + breath * 0.2, in: ctx)

        // upper body hangs off the waist: torso lean carries pauldrons, arms and head with it
        var upper = ctx
        upper.translateBy(x: bx * unit, y: by * unit)
        upper.translateBy(x: rig.waist.x * unit, y: rig.waist.y * unit)
        upper.rotate(by: .radians(pose.torsoRot))
        upper.translateBy(x: -rig.waist.x * unit, y: -rig.waist.y * unit)

        let lift = -pose.shoulderLift       // up is negative y
        let shoulderNear = CGPoint(x: rig.shoulderNear.x, y: rig.shoulderNear.y + lift)
        let shoulderFar = CGPoint(x: rig.shoulderFar.x, y: rig.shoulderFar.y + lift)

        plain(set.tunic, dy: breath * 0.35, in: upper)
        plain(set.cloak, dy: breath * 0.5 + lift * 0.5, in: upper)
        draw(set.pauldronFar, upper, unit: unit, size: size, translate: CGPoint(x: 0, y: breath * 0.5 + lift))

        // the brain gives hand targets in 3/4 coordinates; move them with this view's shoulders
        func viewHand(_ p: CGPoint, near: Bool) -> CGPoint {
            if near, p == ref.relaxedNear { return rig.relaxedNear }
            let from = near ? ref.shoulderNear : ref.shoulderFar
            let to = near ? rig.shoulderNear : rig.shoulderFar
            return CGPoint(x: p.x + to.x - from.x, y: p.y + to.y - from.y)
        }

        // grip, sword and arms (IK so both hands stay on the hilt); targets live in world space
        let body = CGPoint(x: bx, y: by + breath * 0.25)
        let gripRest = CGPoint(x: rig.grip.x + pose.grip.x + body.x, y: rig.grip.y + pose.grip.y + body.y)
        let restRot = pose.swordRot + ref.swordRestRot
        let c = cos(restRot), s = sin(restRot)
        func gripPoint(_ o: CGPoint) -> CGPoint {
            CGPoint(x: gripRest.x + o.x * c - o.y * s, y: gripRest.y + o.x * s + o.y * c)
        }
        var nearTarget = gripPoint(ref.gripNearOffset)
        var farTarget = gripPoint(ref.gripFarOffset)
        var swordGrip = gripRest
        var swordRot = restRot
        func mix(_ a: CGPoint, _ b: CGPoint, _ w: Double) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * w, y: a.y + (b.y - a.y) * w)
        }
        if let n = pose.nearHand {
            let v = viewHand(n, near: true)
            nearTarget = mix(nearTarget, CGPoint(x: v.x + body.x, y: v.y + body.y), pose.nearWeight)
        }
        if let f = pose.farHand {
            let v = viewHand(f, near: false)
            farTarget = mix(farTarget, CGPoint(x: v.x + body.x, y: v.y + body.y), pose.farWeight)
        }
        // both hands free: the sword is let go and settles upright where it was
        let letGo = pose.nearWeight * pose.farWeight
        if letGo > 0.001 {
            swordGrip = mix(swordGrip, rig.grip, letGo)
            swordRot += (ref.swordRestRot - swordRot) * letGo
        }

        /// World-space point -> the torso's local frame (undo the body offset and the lean).
        func toTorso(_ p: CGPoint) -> CGPoint {
            rotate(CGPoint(x: p.x - bx, y: p.y - by), by: -pose.torsoRot, about: rig.waist)
        }

        func arm(
            upperImage: CGImage, fore: CGImage, shoulder: CGPoint, restShoulder: CGPoint,
            elbow0: CGPoint, hand0: CGPoint, target: CGPoint, outward: Double
        ) {
            let l1 = hypot(elbow0.x - restShoulder.x, elbow0.y - restShoulder.y)
            let l2 = hypot(hand0.x - elbow0.x, hand0.y - elbow0.y)
            let ik = solveArm(shoulder: shoulder, upperLength: l1, lowerLength: l2,
                              target: toTorso(target), outwardSign: outward)
            let shift = CGPoint(x: shoulder.x - restShoulder.x, y: shoulder.y - restShoulder.y)
            let d1 = angle(from: shoulder, to: ik.elbow) - angle(from: restShoulder, to: elbow0)
            draw(upperImage, upper, unit: unit, size: size, translate: shift, angle: d1, pivot: restShoulder)
            let d2 = angle(from: ik.elbow, to: ik.hand) - angle(from: elbow0, to: hand0)
            draw(fore, upper, unit: unit, size: size,
                 translate: CGPoint(x: ik.elbow.x - elbow0.x, y: ik.elbow.y - elbow0.y), angle: d2, pivot: elbow0)
        }

        arm(upperImage: set.armFarUpper, fore: set.armFarFore, shoulder: shoulderFar, restShoulder: rig.shoulderFar,
            elbow0: rig.elbowFar, hand0: rig.handFar, target: farTarget, outward: -1)
        if rig.capeInFront { drawCape() }
        draw(set.pauldronNear, upper, unit: unit, size: size, translate: CGPoint(x: 0, y: breath * 0.5 + lift))

        let headDY = breath * 0.8 + pose.headDY
        draw(set.head, upper, unit: unit, size: size, translate: CGPoint(x: 0, y: headDY + lift * 0.4),
             angle: pose.headRot, pivot: rig.neck)
        let eyeShift = CGPoint(x: Double(pose.eyeDX), y: headDY + lift * 0.4)
        if pose.eyeFade < 0.999, let old = set.eyes[pose.eyesPrev] {
            draw(old, upper, unit: unit, size: size, translate: eyeShift, angle: pose.headRot, pivot: rig.neck)
        }
        if let eyes = set.eyes[pose.eyes] {
            var layer = upper
            layer.opacity = max(0.05, pose.eyeFade)
            draw(eyes, layer, unit: unit, size: size, translate: eyeShift, angle: pose.headRot, pivot: rig.neck)
        }

        // the sword lives in world space; the near arm is drawn over it
        draw(Sprite.sword, ctx, unit: unit, size: size,
             translate: CGPoint(x: swordGrip.x - ref.spriteGrip.x, y: swordGrip.y - ref.spriteGrip.y),
             angle: swordRot, pivot: ref.spriteGrip)

        // gold sparks where the point scrapes the ground, and the last one flying to the shoulder
        if pose.scrapeAge >= 0 || pose.sparkFlight >= 0 {
            let off = CGPoint(x: 5 - ref.spriteGrip.x, y: 95 - ref.spriteGrip.y)     // blade point relative to the hilt
            let c = cos(swordRot), s = sin(swordRot)
            let tip = CGPoint(x: swordGrip.x + off.x * c - off.y * s, y: swordGrip.y + off.x * s + off.y * c)
            drawSparks(ctx, unit: unit, tip: tip, pose: pose)
        }

        arm(upperImage: set.armNearUpper, fore: set.armNearFore, shoulder: shoulderNear, restShoulder: rig.shoulderNear,
            elbow0: rig.elbowNear, hand0: rig.handNear, target: nearTarget, outward: 1)

    }
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x1234_5678 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
