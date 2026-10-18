import AppKit

/// Everything the character does over time: idle life, reactions, wandering, being carried and dropped.
@MainActor
final class Brain {
    enum EyeKind { case open, half, closed, wide, angry, happy }
    enum Action { case wake, farewell, sad, surprised, angry, happy, swing, look, glitch, guard_, finished, fumble, flourish }

    /// How the sword is held while idle; switches rarely and at random.
    enum Stance: CaseIterable { case oneHand, twoHand, planted }
    /// Longsword ready positions (Liechtenauer): Pflug (plough), Ochs (ox), Vom Tag (from the roof).
    enum Guard: CaseIterable { case pflug, ochs, vomTag }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Sword hold. Angles are tuned to the sword sprite: the blade rests ~0.7 rad clockwise of straight down.
    static func applyStance(_ stance: Stance, to pose: inout Pose) {
        switch stance {
        case .oneHand:
            break   // default Pose: far hand on the hilt, near hand on the hip
        case .twoHand:
            // both hands on the hilt, point forward and down
            pose.nearHand = nil
            pose.grip = CGPoint(x: 2, y: -3)
            pose.swordRot = -1.52
            pose.torsoRot = 0.0
        case .planted:
            // point on the ground in front, both hands resting on the pommel
            pose.nearHand = nil
            pose.grip = CGPoint(x: 1.5, y: -15)
            pose.swordRot = -0.62
            pose.torsoRot = 0.0
            pose.shoulderLift = 0.4
        }
    }

    /// Permission wait: the sword held upright in front of the body, point up, both fists stacked on the hilt at chest
    /// height, the blade passing in front of the face (a knight keeping vigil). `k` 0...1.
    static func applyBarrier(k: Double, to pose: inout Pose) {
        pose.nearHand = nil                                    // both hands stay on the hilt
        pose.grip = lerp(pose.grip, CGPoint(x: -1.5, y: -9), k)
        pose.swordRot += (2.32 - pose.swordRot) * k            // blade straight up
        pose.torsoRot += (0.0 - pose.torsoRot) * k
        pose.shoulderLift += (0.4 - pose.shoulderLift) * k
        pose.headDY += 0.4 * k
    }

    /// Waiting for an answer: the knight turns its head and eyes towards the viewer, the sword rests low in the hand
    /// nearest the viewer and the other hand hangs free. Calm, nothing moves. `k` 0...1.
    static func applyAttend(k: Double, to pose: inout Pose) {
        pose.nearHand = nil                                   // the near hand keeps the hilt
        pose.farHand = lerp(Skeleton.handFar, CGPoint(x: 31, y: 60), k)   // the far hand drops to the hip
        pose.headRot += 0.2 * k
        pose.headDY -= 1.0 * k
        pose.eyeDX = Int((2 * k).rounded())
        pose.torsoRot += (-0.1 - pose.torsoRot) * k              // the body leans a little towards the viewer
        pose.bodyDX += 1.2 * k
        pose.shoulderLift += (0.5 - pose.shoulderLift) * k
    }

    private static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    // MARK: - click flourish

    /// Keyframes of the click flourish (one-handed): wind up, spin the sword like a baton, cock it back, cut down
    /// through the front in one fast stroke, hold the lunge, recover.
    private static let flourishKeys: [(t: Double, grip: CGPoint, rot: Double, torso: Double, dx: Double, crouch: Double, lift: Double)] = [
        (0.00, CGPoint(x: 0, y: 0), 0.0, 0.04, 0, 0, 0),
        (0.25, CGPoint(x: 0, y: -3), -0.5, 0.12, 1, 0.12, 1.2),
        (0.75, CGPoint(x: 6, y: -10), -0.5, 0.10, 1, 0.10, 1.5),
        (0.95, CGPoint(x: 8, y: -14), 2.4, 0.20, 2, 0.12, 2.0),
        (1.10, CGPoint(x: -2, y: -2), 0.05, -0.14, -3.5, 0.28, -1.0),
        (1.40, CGPoint(x: -2, y: -2), 0.05, -0.14, -3.5, 0.28, -1.0),
        (1.85, CGPoint(x: 0, y: 0), 0.0, 0.04, 0, 0, 0),
    ]

    /// The sword and body at `e` seconds into the flourish; the view also uses it for the afterimages.
    static func flourishState(e: Double) -> (grip: CGPoint, rot: Double, torso: Double, dx: Double, crouch: Double, lift: Double) {
        let keys = flourishKeys
        let t = max(0, min(keys.last!.t, e))
        var i = 0
        while i < keys.count - 2, t > keys[i + 1].t { i += 1 }
        let a = keys[i], b = keys[i + 1]
        var u = (t - a.t) / (b.t - a.t)
        u = i == 3 ? u * u : ease(u)                                  // the cut accelerates; the rest eases
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
        // two full turns about the hand between 0.3 and 0.75 s; they end where they began, so nothing unwinds
        let spin = (e > 0.3 && e < 0.75) ? 4 * Double.pi * ease((e - 0.3) / 0.45) : 0
        return (CGPoint(x: mix(a.grip.x, b.grip.x), y: mix(a.grip.y, b.grip.y)), mix(a.rot, b.rot) + spin,
                mix(a.torso, b.torso), mix(a.dx, b.dx), mix(a.crouch, b.crouch), mix(a.lift, b.lift))
    }

    /// Click flourish: `e` 0...1.9 s.
    static func applyFlourish(e: Double, to pose: inout Pose) {
        let st = flourishState(e: e)
        pose.nearHand = Skeleton.relaxedNear
        pose.grip = st.grip
        pose.swordRot = st.rot
        pose.torsoRot = st.torso
        pose.bodyDX = st.dx
        pose.crouch = st.crouch
        pose.shoulderLift = st.lift
        pose.flourishAge = e
        if e >= 1.0, e < 1.6 { pose.waveAge = e - 1.0 }                    // the slash wave leaves the blade
        if e >= 1.1, e < 2.0 { pose.scrapeAge = e - 1.1 }                  // sparks where the point lands
        if e >= 1.1 { pose.shakeX = sin(e * 90) * 1.2 * exp(-(e - 1.1) * 12) }
    }

    /// Session error: the sword slips out of the far hand, tips and drops, and is caught again. `e` 0...1.3 s.
    static func applyFumble(e: Double, to pose: inout Pose) {
        let slip = ease((e - 0.2) / 0.35), catchUp = ease((e - 0.58) / 0.12), settle = ease((e - 0.75) / 0.5)
        let loose = slip * (1 - catchUp)                       // how far the sword has left the hands
        // the hands stay where they were; only the sword drops through them
        pose.slip = CGPoint(x: 0, y: -10 * loose)
        pose.slipRot = -0.35 * loose                           // the point drops, the blade swings towards vertical (never below the ground)
        pose.shoulderLift = -1.2 * loose + 1.0 * catchUp * (1 - settle)
        pose.headDY += 1.0 * loose
        pose.torsoRot = 0.04 * loose
        pose.bodyDY = 1.6 * sin(.pi * max(0, min(1, (e - 0.2) / 0.25)))     // a jolt as it slips: down and back
    }

    /// Session finished: the wrist flicks the blood off the blade (0 to 0.8 s), then the point is dragged along the
    /// ground in a shower of gold sparks (0.8 to 1.6 s), and the sword settles (to 2.1 s). The last spark flies to the
    /// shoulder (1.6 to 2.05 s).
    static func applyFinished(e: Double, to pose: inout Pose) {
        pose.nearHand = Skeleton.relaxedNear                  // one-handed: the free hand stays on the hip
        // blade angle measured the same way as the rest angle (0.12 rad); the point's height follows from it
        func pointY(_ r: Double) -> Double { -34.2 * sin(r) + 40.5 * cos(r) }
        var rot = 0.0, lift = 0.0
        var grip = CGPoint.zero
        if e < 0.8 {
            let cock = ease(e / 0.22), snap = ease((e - 0.22) / 0.1), back = ease((e - 0.4) / 0.4)
            // cock the wrist back, whip the blade out level, let it swing back to rest
            if e < 0.22 { rot = -0.6 * cock }
            else if e < 0.32 { rot = -0.6 + 0.9 * snap }
            else { rot = 0.3 * (1 - back) + 0.1 * sin((e - 0.32) * 30) * (1 - back) }
            grip = CGPoint(x: -3 * rot, y: -2 * snap * (1 - back) + min(0, 94 - 58 - pointY(rot + 0.12)))   // point stays off the ground
            lift = 1.4 * snap * (1 - back)
            pose.swordRot = rot
            pose.torsoRot = -0.05 * snap * (1 - back)
        } else {
            // drag the point along the ground: sweep the blade, lowering or raising the hand so the point stays down
            let sweep = ease((e - 0.8) / 0.8), settle = ease((e - 1.6) / 0.5)
            let r = (0.5 + (-0.2 - 0.5) * sweep) * (1 - settle) + 0.12 * settle     // total angle
            grip = CGPoint(x: 0, y: 94 - 58 - pointY(r))
            pose.swordRot = r - 0.12
            pose.torsoRot = -0.07 * sweep * (1 - settle)
            lift = 0.8 * sweep * (1 - settle)
            if e < 1.9 { pose.scrapeAge = e - 0.8 }
            if e >= 1.6, e < 2.05 { pose.sparkFlight = (e - 1.6) / 0.45 }
        }
        pose.grip = grip
        pose.shoulderLift = lift
    }

    /// `k` 0...1 is how far into the guard it is.
    static func applyGuard(_ guardKind: Guard, k: Double, to pose: inout Pose) {
        let goal: (grip: CGPoint, rot: Double, torso: Double, lift: Double)
        switch guardKind {
        case .pflug: goal = (CGPoint(x: 2, y: -2), -2.72, 0.0, 0.5)     // hilt at the hip, point forward at the face
        case .ochs: goal = (CGPoint(x: -1, y: -21), -1.42, -0.04, 1.6)  // hilt by the head, point forward and down
        case .vomTag: goal = (CGPoint(x: -1, y: -17), 2.0, 0.06, 1.8)   // hilt by the head, blade up over the shoulder
        }
        pose.nearHand = nil
        pose.grip = lerp(pose.grip, goal.grip, k)
        pose.swordRot += (goal.rot - pose.swordRot) * k
        pose.torsoRot += (goal.torso - pose.torsoRot) * k
        pose.shoulderLift += (goal.lift - pose.shoulderLift) * k
    }

    /// Fist to the chest and a bow of the head. `k` 0...1.
    static func applySalute(k: Double, to pose: inout Pose) {
        pose.nearHand = lerp(Skeleton.relaxedNear, CGPoint(x: 42, y: 45), k)
        pose.headDY += 2.2 * k
        pose.headRot += 0.08 * k
        pose.torsoRot = pose.torsoRot + (-0.1 - pose.torsoRot) * k
        pose.crouch = 0.18 * k
    }

    private enum Drop {
        case none
        case falling(vy: Double)
        case impact(start: Double, strength: Double)
        case stagger(start: Double)
        case dust(start: Double, sulks: Bool)
        case sulk(start: Double)
    }

    struct Pose {
        var eyes: EyeKind = .open
        var eyeDX = 0
        var headRot = 0.0       // radians, about the neck
        var headDY = 0.0        // art pixels
        var bodyDX = 0.0
        var bodyDY = 0.0
        var grip = CGPoint.zero // offset of the two-handed sword grip from its rest position
        var swordRot = 0.0      // radians, about the grip
        var nearHand: CGPoint? = Skeleton.relaxedNear  // absolute hand target; nil = both hands on the hilt
        var farHand: CGPoint?
        var nearWeight = 1.0    // how much of the hand is free of the hilt (smoothed in `smooth`)
        var farWeight = 0.0
        var shakeX = 0.0        // fast shaking, added on top of the smoothed body offset
        var glitch = 0.0        // 0...1
        var facingRight = false
        var stepPhase = 0.0
        var stepAmount = 0.0    // 0 = standing, 1 = full walk cycle
        var torsoRot = 0.04     // radians about the waist: + leans back, - leans forward
        var shoulderLift = 0.0  // art px, both shoulders
        var kick = 0.0          // 0...1 frantic legs (carried / falling / stamping)
        var kickPhase = 0.0
        var view: ViewKind = .threeQuarter
        var eyesPrev: EyeKind = .open       // cross-fading expressions
        var eyeFade = 1.0
        var carriedAmount = 0.0             // smoothed 0...1 versions of the flags below
        var fallAmount = 0.0
        var crouch = 0.0        // 0...1 knees bent (landing)
        var kneel = 0.0         // 0...1 down on one knee (goodbye)
        var slip = CGPoint.zero // the sword slides through the hands by this much (art px), hands stay put
        var slipRot = 0.0       // and turns by this much (radians)
        var flourishAge = -1.0  // seconds into the click flourish (drives the sword's afterimages); < 0 = none
        var waveAge = -1.0      // seconds since the slash wave left the blade; < 0 = none
        var scrapeAge = -1.0    // seconds since the sword point began to scrape the ground; < 0 = none
        var sparkFlight = -1.0  // 0...1 the last gold spark flying from the sword point to the shoulder; < 0 = none
        var redSparks = 0       // shoulder sparks: waiting for the user
        var goldSparks = 0      // shoulder sparks: finished sessions
        var splashAge = -1.0    // seconds since the landing splash began; < 0 = none
        var wind = 0.0          // 0...1 gale blowing the cape to one side (arrival and goodbye)
        var squash = 0.0        // 0...1 impact squash
        var falling = false
        var fling = 0.0         // -1...1 how hard it is being dragged sideways (sprite space)
        var carried = false
        var showQuit = false    // double-click reveals a close button
        var cocoonAge = -1.0    // seconds since blood started swirling round the whole body; < 0 = none
        var cocoonHold = false  // true: the blood stays (goodbye) instead of withering
        var reveal = 1.0        // 0...1 how visible the character is (fades in/out inside the blood)
        var dust = -1.0         // mage teleport: seconds since it scattered into star dust; < 0 = none
        var cast = -1.0         // mage click: seconds since it raised the staff for a shooting star; < 0 = none
        var rune = -1.0         // mage sentinel: seconds the permission rune has hung in the air; < 0 = none
        var orb = -1.0          // mage sentinel: seconds the crystal ball has glowed in the hand; < 0 = none
        var nudge = -1.0        // mage sentinel: seconds since the rune pulsed as a reminder; < 0 = none
        var feast = -1.0        // mage sentinel: seconds into the finished spell and its star feast; < 0 = none
        var misfire = -1.0      // mage sentinel: seconds since the spell misfired (error); < 0 = none
        var hang = 0.0          // swing angle while carried (radians)
        var hangPivot = CGPoint(x: 39, y: 20)   // sprite point under the cursor
    }

    private(set) var current = Pose()
    /// Sprite-space point the user grabbed (set on mouse down), so the body hangs from the cursor.
    var grabPoint = CGPoint(x: 39, y: 20)
    var gravityEnabled = true
    /// Customize › Activity: stretches (calm) or shortens (lively) the gaps between idle moves.
    var restScale = 1.0
    var onSound: ((SoundEffect) -> Void)?
    var mouseTarget: () -> (mouse: CGPoint, center: CGPoint)? = { nil }
    var windowOrigin: () -> CGPoint = { .zero }
    var setWindowOrigin: (CGPoint) -> Void = { _ in }
    var walkBounds: () -> CGRect = { .zero }
    var groundY: () -> CGFloat = { 0 }
    /// The text box the user is typing in (screen coordinates), which the knight must not walk into.
    var keepOut: () -> CGRect? = { nil }
    /// Where the knight's body is on screen for a given window origin.
    var bodyFrame: (CGPoint) -> CGRect = { CGRect(origin: $0, size: .zero) }

    private var action: (kind: Action, start: Double)?
    private var quitUntil = 0.0
    private var appearStart: Double?
    private struct Landing { var impact: Double?; var vy = 0.0; var x: Double }
    var sentinelHold = SentinelHold.none      // set by the sentinel (Brain+Sentinel API below)
    private var holdSince = 0.0
    private var remindStart = -10.0
    private var finishedStage = 0       // which sounds of the finished move have played
    private var flareUntil = 0.0
    private(set) var redSparks = 0, goldSparks = 0
    private var landing: Landing?        // arrival: drops from the top of the screen in a hero landing
    private var smoothed = Pose()
    private var nearW = 1.0, farW = 0.0
    private var eyeShown: EyeKind = .open
    private var eyePrev: EyeKind = .open
    private var eyeFade = 1.0
    private var nearPos = Skeleton.relaxedNear, farPos = Skeleton.handFar
    private var drop: Drop = .none
    private var lastUpdate = CACurrentMediaTime()
    private var nextBlink = 3.0
    private var blinkUntil = 0.0
    private var nextDrift = 2.0
    private var driftUntil = 0.0
    private var driftDX = 0
    private var nextTic = 5.0
    private var ticUntil = 0.0
    private var ticSign = 1.0
    private var nextGlitch = 14.0
    private var nextAuto = CACurrentMediaTime() + 8
    private var nextWander = CACurrentMediaTime() + 10
    private var tilt = 0.0
    private var lastMove = -10.0
    private var lastMouseX: Double?
    private var dragVX = 0.0
    private var hang = 0.0
    private var carriedSince = 0.0
    private var wasCarried = false
    private var gaveUp = false
    private var feared = false
    private var walkTarget: CGPoint?
    /// The mage sometimes stops partway through a walk, scatters into star dust and gathers again at the walk's end.
    private var teleportAt: Double?
    private var teleport: (start: Double, to: CGPoint, moved: Bool)?
    private var castStart: Double?
    private var feastStart: Double?, misfireStart: Double?
    private var walkPhase = 0.0
    private var walkAmount = 0.0
    private var facingRight = false
    private var mouseNear = false
    private var stance = Stance.oneHand
    private var nextStance = CACurrentMediaTime() + .random(in: 40 ... 90)
    private var guardKind = Guard.pflug

    private static let walkSpeed = 55.0   // points per second

    private func duration(_ kind: Action) -> Double {
        switch kind {
        case .wake: 3.0
        case .farewell: 6.4
        case .sad: 2.8
        case .surprised: 0.9
        case .angry: 1.2
        case .happy: 1.2
        case .swing: 1.9
        case .look: 2.2
        case .glitch: 0.4
        case .guard_: 6.6
        case .finished: 2.1
        case .fumble: 1.3
        case .flourish: 1.9
        }
    }

    private func sound(for kind: Action) -> SoundEffect? {
        switch kind {
        case .wake: .wake
        case .farewell: .farewell
        case .sad: .sad
        case .surprised: .surprised
        case .angry: .angry
        case .happy: .happy
        case .swing: .swish
        case .look: nil
        case .glitch: .glitch
        case .guard_: nil
        case .finished: nil      // its own sounds play at the flick and the scrape
        case .fumble: nil
        case .flourish: nil      // its own sounds play at the spin, the strike and the plant
        }
    }

    func start(_ kind: Action, at now: Double = CACurrentMediaTime(), silent: Bool = false) {
        action = (kind, now)
        if kind == .wake, !beginLanding() { appearStart = now; action = (.wake, now + 2.4) }   // no room to fall: arrive inside the blood
        if kind == .finished || kind == .fumble || kind == .flourish { finishedStage = 0 }
        if kind == .guard_ { guardKind = Guard.allCases.randomElement()! }
        walkTarget = nil
        if !silent, let effect = sound(for: kind) { onSound?(effect) }
    }

    /// Puts the window above the screen, over the middle third of its width; `update` drops it from there.
    private func beginLanding() -> Bool {
        let bounds = walkBounds()
        guard gravityEnabled, bounds.width > 10, bounds.height > 10 else { return false }
        let x = bounds.minX + bounds.width * .random(in: 1.0 / 3 ... 2.0 / 3)
        setWindowOrigin(CGPoint(x: x, y: bounds.maxY + 270))   // 270 pt = more than the window height
        landing = Landing(x: x)
        action = nil
        drop = .none
        return true
    }

    private func stepLanding(dt: Double, now: Double) {
        guard var l = landing else { return }
        if let impact = l.impact {
            if now - impact > 2.7 { landing = nil; nextAuto = now + .random(in: 6 ... 12); return }
        } else {
            l.vy += 6000 * dt
            let y = windowOrigin().y - l.vy * dt
            if y <= groundY() {
                setWindowOrigin(CGPoint(x: l.x, y: groundY()))
                l.impact = now
                onSound?(.thud)
            } else {
                setWindowOrigin(CGPoint(x: l.x, y: y))
            }
        }
        landing = l
    }

    private func applySentinel(_ now: Double, to pose: inout Pose) {
        let k = ease((now - holdSince) / 0.5)
        switch sentinelHold {
        case .none: break
        case .barrier:
            Self.applyBarrier(k: k, to: &pose)
            if now < flareUntil { pose.eyes = .wide }      // the eyes flare once as the sword comes up
            let r = now - remindStart                      // reminder: one short shake of the sword
            if r >= 0, r < 0.5 { pose.swordRot += 0.07 * sin(r * 55) * (1 - r / 0.5); pose.grip.x += 0.8 * sin(r * 70) * (1 - r / 0.5) }
        case .attend:
            Self.applyAttend(k: k, to: &pose)
            let lift = (now - holdSince) / 0.4                  // a small lift of the head as it snaps to attention
            if lift < 1 { pose.headDY -= 1.4 * sin(.pi * lift) }
        }
    }

    private func applyLanding(_ l: Landing, now: Double, to pose: inout Pose) {
        Self.applyStance(.planted, to: &pose)       // diving sword-first
        guard let impact = l.impact else { pose.falling = true; return }
        let e = now - impact
        // slams onto one knee with the sword driven into the ground, holds, then stands up slowly
        let k = ease(e / 0.12) * (1 - ease((e - 1.4) / 1.2))
        pose.kneel = k
        pose.grip = lerp(pose.grip, CGPoint(x: -7, y: -27), k)
        pose.swordRot += (-0.82 - pose.swordRot) * k
        pose.torsoRot += (-0.08 - pose.torsoRot) * k
        pose.headDY += 2.4 * k
        pose.headRot += 0.1 * k
        let hit = max(0, 1 - e / 0.35)
        pose.squash = 0.7 * hit
        pose.shakeX = sin(e * 80) * 0.9 * hit
        pose.splashAge = e
    }

    /// The user is carrying the window. `mouseX` is in screen points.
    func carried(mouseX: Double, at now: Double = CACurrentMediaTime()) {
        if let last = lastMouseX, now - lastMove > 0.0005 {
            let v = (mouseX - last) / max(now - lastMove, 0.004)
            dragVX += (v - dragVX) * 0.3
        }
        if !(now - lastMove < 0.25) {
            carriedSince = now
            action = nil
            landing = nil
            drop = .none
            dragVX = 0
            gaveUp = false
            feared = false
            onSound?(.surprised)
        }
        lastMouseX = mouseX
        lastMove = now
        walkTarget = nil
    }

    /// Double-click: show the close cross for a few seconds; another double-click hides it again.
    func revealQuitButton(at now: Double = CACurrentMediaTime()) {
        quitUntil = now < quitUntil ? 0 : now + 5
    }

    var quitButtonVisible: Bool { CACurrentMediaTime() < quitUntil }

    /// A click: a silent sword swing.
    func clicked(at now: Double = CACurrentMediaTime()) {
        if Mage.isSelected {
            guard castStart == nil else { return }
            castStart = now
            Mage.shootingStar(windowOrigin: windowOrigin(), facingRight: facingRight)
            return
        }
        // only when it is idle: no action, no sentinel pose, not landing, falling or being carried
        guard action == nil, landing == nil, sentinelHold == .none, now - lastMove > 1.0 else { return }
        if case .none = drop { start(.flourish, at: now, silent: true) }
    }

    // MARK: - per frame

    func update(at now: Double) {
        let dt = min(0.05, max(0.001, now - lastUpdate))
        lastUpdate = now
        var pose = Pose()
        pose.hangPivot = grabPoint
        pose.hang = hang * (facingRight ? -1 : 1)
        let carried = now - lastMove < 0.25

        if wasCarried, !carried { released(at: now) }
        wasCarried = carried

        // idle sword hold (walking always uses the one-handed carry)
        Self.applyStance(walkTarget != nil ? .oneHand : stance, to: &pose)

        let dropping: Bool
        if case .none = drop { dropping = false } else { dropping = true }
        if !dropping, landing == nil, teleport == nil { schedule(now) }
        stepFall(dt: dt, now: now)
        stepLanding(dt: dt, now: now)

        if walkTarget == nil { teleportAt = nil }
        if let at = teleportAt, now >= at, let target = walkTarget {
            teleport = (now, target, false)
            walkTarget = nil
            teleportAt = nil
        }
        // wandering
        if let target = walkTarget {
            let origin = windowOrigin()
            let dx = target.x - origin.x, dy = target.y - origin.y
            let dist = hypot(dx, dy)
            let step = Self.walkSpeed * dt
            if dist <= step {
                setWindowOrigin(target)
                walkTarget = nil
                nextWander = now + .random(in: 12 ... 35) * restScale
            } else {
                let next = CGPoint(x: origin.x + dx / dist * step, y: origin.y + dy / dist * step)
                if blocked(next), !blocked(origin) {
                    walkTarget = nil                      // the way leads into the text box: stop at its edge
                    nextWander = now + 3
                } else {
                    setWindowOrigin(next)
                    facingRight = dx > 0
                    walkPhase += dt * 5.5
                }
            }
        }
        // standing in the text box someone is typing in: step out of it
        if walkTarget == nil, !carried, !dropping, landing == nil, blocked(windowOrigin()) { stepOutOfTheWay() }
        walkAmount += ((walkTarget != nil ? 1.0 : 0.0) - walkAmount) * min(1, dt * 9)
        if walkAmount < 0.01, walkTarget == nil { walkAmount = 0 }
        pose.facingRight = facingRight
        pose.stepPhase = walkPhase
        pose.stepAmount = walkAmount

        // mouse proximity: tilt head toward the cursor and look at it
        var targetTilt = 0.0
        var mouseDX: Int?
        mouseNear = false
        if let (mouse, center) = mouseTarget() {
            let dx = Double(mouse.x - center.x), dy = Double(mouse.y - center.y)
            if hypot(dx, dy) < 240 {
                mouseNear = true
                let flip = facingRight ? -1.0 : 1.0
                targetTilt = (dx >= 0 ? 1 : -1) * 0.09 * flip
                mouseDX = max(-2, min(2, Int((dx / 45).rounded() * flip)))
            }
        }
        tilt += (targetTilt - tilt) * 0.12
        pose.headRot = tilt
        if let mouseDX { pose.eyeDX = mouseDX } else if now < driftUntil { pose.eyeDX = driftDX }
        if now < ticUntil {
            pose.headDY -= 0.7
            pose.headRot += 0.05 * ticSign
        }
        if now < blinkUntil { pose.eyes = .closed }

        if !carried { dragVX *= 0.85 }
        let targetHang = carried ? max(-0.16, min(0.16, -dragVX * 0.0004)) : 0
        hang += (targetHang - hang) * min(1, dt * 8)

        if carried {
            applyCarried(now, to: &pose)
        } else if let l = landing {
            applyLanding(l, now: now, to: &pose)
        } else if dropping {
            applyDrop(now, to: &pose)
        } else if let current = action {
            let elapsed = now - current.start
            if elapsed < 0 {
                // waiting for the blood to clear before it moves
            } else if elapsed > duration(current.kind) {
                action = nil
            } else {
                apply(current.kind, elapsed: elapsed, to: &pose)
            }
        } else if sentinelHold != .none, !Mage.isSelected {
            applySentinel(now, to: &pose)
        }
        if Mage.isSelected { applyMageSentinel(now, carried: carried, to: &pose) }
        if let a = appearStart {
            let appeared = now - a
            if appeared < 2.5 { pose.cocoonAge = appeared; pose.reveal = ease((appeared - 0.55) / 0.9) } else { appearStart = nil }
        }
        // goodbye: after the kneel a blood storm whirls round it, swallows it and dies down where it stands
        if let a = action, a.kind == .farewell, now - a.start > 1.8 {
            let e = now - a.start
            pose.cocoonAge = e - 1.8                       // the blood storm rises the moment the knee touches down
            pose.cocoonHold = true
            // barely visible inside the storm almost at once, gone by the time it dies down
            pose.reveal = 1 - 0.8 * ease((e - 1.8) / 0.5) - 0.2 * ease((e - 3.0) / 0.8)
            pose.shakeX += sin(now * 70) * 0.6 * min(1, (e - 1.8) / 0.8) * pose.reveal
        }
        // a gale while the blood is around (arrival: first 2 s; goodbye: as long as it stays)
        pose.wind = pose.cocoonAge >= 0 && (pose.cocoonHold || pose.cocoonAge < 2.0) ? 1 : 0
        // shoulder sparks; the one the finished move is still flying in is not counted yet
        pose.redSparks = redSparks
        var arriving = 0
        if let a = action, a.kind == .finished, now - a.start < 2.05 { arriving = 1 }
        if let f = feastStart, now - f < Mage.feastSettles { arriving = 1 }
        pose.goldSparks = max(0, goldSparks - arriving)
        if let c = castStart {
            if now - c > 1.6 { castStart = nil } else { pose.cast = now - c }
        }
        if let tp = teleport {
            let e = now - tp.start
            if carried || e > 1.7 {
                teleport = nil
                nextWander = now + .random(in: 12 ... 35) * restScale
            } else {
                if e >= 0.7, !tp.moved { setWindowOrigin(tp.to); teleport?.moved = true }
                pose.dust = e
            }
        }
        pose.view = .threeQuarter

        pose.showQuit = now < quitUntil
        current = smooth(pose, dt: dt)
    }

    private func schedule(_ now: Double) {
        if now > nextBlink {
            blinkUntil = now + 0.17
            nextBlink = now + .random(in: 2.5 ... 6)
        }
        let idle = idleLifeRuns
        if idle, now > nextDrift {
            driftDX = [-2, -1, 1, 2].randomElement()!
            driftUntil = now + .random(in: 0.8 ... 2.0)
            nextDrift = driftUntil + .random(in: 1 ... 4)
        }
        if idle, now > nextTic {
            ticUntil = now + 0.14
            ticSign = Bool.random() ? 1 : -1
            nextTic = now + .random(in: 3 ... 8)
        }
        guard action == nil, now - lastMove > 1.0, idle else { return }
        if now > nextStance {
            stance = Stance.allCases.filter { $0 != stance }.randomElement()!
            nextStance = now + .random(in: 45 ... 100)
        }
        if now > nextGlitch {
            start(.glitch, at: now)
            nextGlitch = now + .random(in: 15 ... 40) * restScale
        } else if walkTarget == nil, now > nextAuto {
            start([.look, .look, .happy, .guard_].randomElement()!, at: now)   // no sword swing on its own for now
            nextAuto = now + .random(in: 10 ... 25) * restScale
        } else if walkTarget == nil, !mouseNear, now > nextWander {
            beginWalk(at: now)
        }
    }

    /// True when the knight at `origin` would come within ~30 pt of the text box being typed in.
    private func blocked(_ origin: CGPoint) -> Bool {
        guard let box = keepOut() else { return false }
        return bodyFrame(origin).intersects(box.insetBy(dx: -30, dy: -24))
    }

    /// Walks to the nearer side of the text box; with no room beside it, climbs onto its top edge.
    private func stepOutOfTheWay() {
        guard let box = keepOut() else { return }
        let origin = windowOrigin(), body = bodyFrame(origin), bounds = walkBounds()
        let left = CGPoint(x: origin.x - (body.maxX - (box.minX - 36)), y: origin.y)
        let right = CGPoint(x: origin.x + ((box.maxX + 36) - body.minX), y: origin.y)
        let free = [left, right].filter { $0.x >= bounds.minX && $0.x <= bounds.maxX && !blocked($0) }
        if let nearest = free.min(by: { abs($0.x - origin.x) < abs($1.x - origin.x) }) {
            walkTarget = nearest
        } else {
            let ledge = CGPoint(x: origin.x, y: origin.y + ((box.maxY + 28) - body.minY))
            if ledge.y <= bounds.maxY { walkTarget = ledge }
        }
        action = nil
    }

    private func beginWalk(at now: Double) {
        let bounds = walkBounds()
        guard bounds.width > 10, bounds.height > 10 else { nextWander = now + 30; return }
        let origin = windowOrigin()
        for _ in 0 ..< 8 {
            let x = CGFloat.random(in: bounds.minX ... bounds.maxX)
            let y = gravityEnabled
                ? groundY()
                : min(bounds.maxY, max(bounds.minY, origin.y + .random(in: -80 ... 80)))
            if abs(x - origin.x) > 180, !blocked(CGPoint(x: x, y: y)) {
                walkTarget = CGPoint(x: x, y: y)
                if Mage.isSelected, Double.random(in: 0 ... 1) < 0.4 { teleportAt = now + .random(in: 0.8 ... 2.5) }
                return
            }
        }
        nextWander = now + 20
    }

    private func walkAway(at now: Double) {
        let bounds = walkBounds()
        let origin = windowOrigin()
        let goRight = origin.x < bounds.midX
        let x = max(bounds.minX, min(bounds.maxX, origin.x + (goRight ? 1 : -1) * 380))
        walkTarget = CGPoint(x: x, y: gravityEnabled ? groundY() : origin.y)
        nextWander = now + 25
    }

    private func ease(_ x: Double) -> Double {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }

    // MARK: - smoothing

    /// Every continuous value eases towards its target instead of jumping, so switching between
    /// actions blends rather than snapping; the hands blend between "on the hilt" and "free".
    private func smooth(_ target: Pose, dt: Double) -> Pose {
        func k(_ rate: Double) -> Double { 1 - exp(-rate * dt) }
        let slow = k(9), fast = k(24)
        var s = smoothed
        s.headRot += (target.headRot - s.headRot) * slow
        s.headDY += (target.headDY - s.headDY) * slow
        s.bodyDX += (target.bodyDX - s.bodyDX) * slow
        s.bodyDY += (target.bodyDY - s.bodyDY) * slow
        s.grip.x += (target.grip.x - s.grip.x) * slow
        s.grip.y += (target.grip.y - s.grip.y) * slow
        s.swordRot += (target.swordRot - s.swordRot) * slow
        s.torsoRot += (target.torsoRot - s.torsoRot) * slow
        s.shoulderLift += (target.shoulderLift - s.shoulderLift) * slow
        s.stepAmount += (target.stepAmount - s.stepAmount) * slow
        s.kick += (target.kick - s.kick) * slow
        s.crouch += (target.crouch - s.crouch) * fast
        s.kneel += (target.kneel - s.kneel) * k(6)
        s.wind += (target.wind - s.wind) * k(3)
        s.squash += (target.squash - s.squash) * fast
        s.fling += (target.fling - s.fling) * slow
        // hands: smooth where they are going, and how free of the hilt they are
        nearW += ((target.nearHand != nil ? 1 : 0) - nearW) * slow
        farW += ((target.farHand != nil ? 1 : 0) - farW) * slow
        if let n = target.nearHand { nearPos = nearW < 0.06 ? n : CGPoint(x: nearPos.x + (n.x - nearPos.x) * slow, y: nearPos.y + (n.y - nearPos.y) * slow) }
        if let f = target.farHand { farPos = farW < 0.06 ? f : CGPoint(x: farPos.x + (f.x - farPos.x) * slow, y: farPos.y + (f.y - farPos.y) * slow) }
        s.carriedAmount += ((target.carried ? 1 : 0) - s.carriedAmount) * slow
        s.fallAmount += ((target.falling ? 1 : 0) - s.fallAmount) * slow
        if target.eyes != eyeShown {
            eyePrev = eyeShown
            eyeShown = target.eyes
            eyeFade = 0
        }
        eyeFade = min(1, eyeFade + dt / 0.09)
        if target.flourishAge >= 0 { s.swordRot = target.swordRot; s.grip = target.grip }   // fast spins must not lag behind
        smoothed = s

        var out = target
        out.eyes = eyeShown
        out.eyesPrev = eyePrev
        out.eyeFade = eyeFade
        out.carriedAmount = s.carriedAmount
        out.fallAmount = s.fallAmount
        out.headRot = s.headRot; out.headDY = s.headDY
        out.bodyDX = s.bodyDX; out.bodyDY = s.bodyDY
        out.grip = s.grip; out.swordRot = s.swordRot
        out.torsoRot = s.torsoRot; out.shoulderLift = s.shoulderLift
        out.stepAmount = s.stepAmount; out.kick = s.kick
        out.crouch = s.crouch; out.squash = s.squash; out.fling = s.fling
        out.kneel = s.kneel
        out.wind = s.wind
        out.nearHand = nearW > 0.01 ? nearPos : nil
        out.farHand = farW > 0.01 ? farPos : nil
        out.nearWeight = nearW
        out.farWeight = farW
        return out
    }

    // MARK: - falling after a drop

    private func released(at now: Double) {
        guard gravityEnabled else { drop = .dust(start: now, sulks: false); return }
        if windowOrigin().y > groundY() + 4 {
            drop = .falling(vy: 0)
        } else {
            drop = .stagger(start: now)
        }
    }

    private func stepFall(dt: Double, now: Double) {
        switch drop {
        case .falling(var vy):
            vy += 2400 * dt
            let origin = windowOrigin()
            let y = origin.y - vy * dt
            if y <= groundY() {
                setWindowOrigin(CGPoint(x: origin.x, y: groundY()))
                drop = .impact(start: now, strength: min(1, max(0.35, vy / 1500)))
                onSound?(.thud)
            } else {
                setWindowOrigin(CGPoint(x: origin.x, y: y))
                drop = .falling(vy: vy)
            }
        case let .impact(start, _) where now - start > 0.45:
            drop = .stagger(start: now)
        case let .stagger(start) where now - start > 1.0:
            drop = .dust(start: now, sulks: Double.random(in: 0 ... 1) < 0.6)
        case let .dust(start, sulks) where now - start > 1.7:
            if sulks { drop = .sulk(start: now); onSound?(.sad) } else { drop = .none }
        case let .sulk(start) where now - start > 1.3:
            drop = .none
            walkAway(at: now)
        default:
            break
        }
    }

    private func applyDrop(_ now: Double, to pose: inout Pose) {
        let near = Skeleton.shoulderNear, far = Skeleton.shoulderFar
        switch drop {
        case .none:
            break
        case .falling:
            pose.falling = true
            pose.eyes = .wide
            pose.nearHand = CGPoint(x: near.x + 12, y: near.y - 15)
            pose.farHand = CGPoint(x: far.x - 11, y: far.y - 15)
            pose.kick = 0.5
            pose.kickPhase = now * 16
            pose.headRot = -0.08
        case let .impact(start, strength):
            let e = now - start
            let hit = e < 0.1 ? e / 0.1 : max(0, 1 - (e - 0.1) / 0.35)
            pose.squash = strength * hit
            pose.crouch = strength * hit
            pose.eyes = e < 0.3 ? .closed : .wide
            pose.nearHand = CGPoint(x: near.x + 9, y: near.y - 4 - 4 * (1 - hit))
            pose.torsoRot = -0.1 * hit
            pose.headDY = 1.5 * hit
        case let .stagger(start):
            // lose balance, arms out, shuffle the feet, settle
            let e = now - start
            let k = 1 - ease(e / 1.0)
            pose.nearHand = nil
            pose.eyes = e < 0.5 ? .wide : .open
            pose.bodyDX = 2.2 * sin(e * 11) * k
            pose.torsoRot = 0.14 * sin(e * 9 + 1) * k
            pose.swordRot = 0.5 * sin(e * 9) * k
            pose.grip = CGPoint(x: 0, y: -2 * k)
            pose.shoulderLift = 1.5 * k
            pose.stepPhase = e * 10
            pose.stepAmount = 0.55 * k
        case let .dust(start, _):
            // brush the cape with the free hand, then shrug and roll the eyes
            let e = now - start
            pose.eyes = .half
            if e < 0.95 {
                let sweep = sin(e * 14)
                pose.nearHand = CGPoint(x: 47 + 7 * sweep, y: 64 + 4 * sin(e * 7))
                pose.torsoRot = 0.04 * sweep
                pose.headDY = 0.6
            } else {
                let p = (e - 0.95) / 0.75
                pose.shoulderLift = 3 * sin(.pi * min(1, p))
                pose.eyeDX = [-2, 0, 2, 0][min(3, Int(p * 4))]
                pose.headRot = 0.05 * sin(.pi * min(1, p))
            }
        case let .sulk(start):
            // turn away, head down, glare
            let e = now - start
            let k = ease(e / 0.4)
            pose.eyes = .half
            pose.headDY = 1.8 * k
            pose.headRot = 0.12 * k
            pose.shoulderLift = -1 * k
            pose.bodyDX = 0.8 * k
        }
    }

    // MARK: - poses

    /// Held up by the scruff like a cat: dangles and resists in bursts, gives up eventually,
    /// is flung around by fast drags, and is scared of being held high.
    private func applyCarried(_ now: Double, to pose: inout Pose) {
        let t = now
        let e = now - carriedSince
        let side = facingRight ? -1.0 : 1.0

        // gives up after a while
        let giveUp = ease((e - 6) / 3)
        if giveUp > 0.6, !gaveUp { gaveUp = true; onSound?(.sad) }
        let wave = max(0, sin(t * 1.7))
        let struggle = wave * wave * (1 - giveUp)

        // scared when held high
        let bounds = walkBounds()
        let heightFactor = bounds.height > 1 ? (windowOrigin().y - bounds.minY) / bounds.height : 0
        let fear = ease((Double(heightFactor) - 0.5) / 0.25)
        if fear > 0.6, !feared { feared = true; onSound?(.surprised) }

        // fast drag flings the loose parts behind it
        let fling = max(-1, min(1, dragVX / 900))

        pose.carried = true
        pose.nearHand = nil
        pose.hang = (hang + 0.025 * sin(t * 4.5) * struggle) * side
        pose.fling = fling * side
        pose.kick = (0.06 + 0.4 * struggle) * (1 - fear) * (1 - 0.7 * giveUp)
        pose.kickPhase = t * 9
        pose.stepAmount = 0
        pose.bodyDY = 1.0 + 1.5 * giveUp
        pose.eyes = struggle > 0.25 ? .angry : .half
        pose.headRot = 0.05 * sin(t * 12) * struggle + 0.12 * giveUp
        pose.headDY = -0.5 + 2.5 * giveUp
        pose.grip = CGPoint(x: 2 * sin(t * 6.5) * struggle, y: 2 * cos(t * 7.3) * struggle - 1 + 3 * giveUp)
        pose.swordRot = 0.2 * sin(t * 5.5) * struggle + 0.08 + 0.5 * fling * side

        // every few seconds it takes a swing at the hand holding it
        let period = 3.4
        let swatT = (t - carriedSince).truncatingRemainder(dividingBy: period)
        if swatT < 0.8, giveUp < 0.5, fear < 0.5, e > 1.0 {
            let arc = sin(.pi * swatT / 0.8)
            pose.grip = CGPoint(x: -3 * arc, y: -10 * arc)
            pose.swordRot = 1.5 * arc
            pose.eyes = .angry
            pose.shoulderLift = 2 * arc
            pose.torsoRot = 0.1 * arc
        }

        if fear > 0 {
            pose.eyes = .wide
            pose.shakeX += sin(t * 55) * 0.4 * fear
            pose.shoulderLift = max(pose.shoulderLift, 1.8 * fear)
            pose.grip.y -= 1.5 * fear
            pose.headRot += 0.08 * fear
            pose.eyeDX = -1
        }
        if e < 0.25 { pose.bodyDY = -0.5 + 1.5 * ease(e / 0.25) }   // little yank when picked up
    }

    private func apply(_ kind: Action, elapsed e: Double, to pose: inout Pose) {
        let near = Skeleton.shoulderNear
        switch kind {
        case .wake:
            pose.eyes = e < 0.5 ? .closed : e < 0.9 ? .half : .open
            pose.headDY = 3 * (1 - ease(e / 1.6))
            pose.eyeDX = 0
            // knightly salute: fist to the chest, head bowed, then back up
            let bow = ease((e - 0.9) / 0.5) * (1 - ease((e - 2.2) / 0.6))
            if bow > 0.01 { Self.applySalute(k: bow, to: &pose) }
        case .farewell:
            // slowly go down on one knee, sword planted, head bowed
            let k = ease(e / 1.8) * (1 - ease((e - 5.6) / 0.8))   // down by 1.8 s, stays on the knee until the blood comes
            pose.kneel = k
            pose.nearHand = nil
            pose.grip = lerp(pose.grip, CGPoint(x: -7, y: -27), k)
            pose.swordRot += (-0.82 - pose.swordRot) * k   // blade straight down
            pose.torsoRot += (-0.08 - pose.torsoRot) * k
            pose.headDY += 2.4 * k
            pose.headRot += 0.1 * k
        case .sad:
            pose.eyes = e < 1.4 ? .half : .closed
            pose.headDY = 2.5 * ease(e / 0.8)
            pose.headRot = 0.07 * ease(e / 0.8)
            pose.bodyDY = 1.2 * ease(e / 0.8)
            pose.grip = CGPoint(x: 0, y: 2.5 * ease(e / 0.8))
            pose.eyeDX = 0
        case .surprised:
            pose.eyes = .wide
            let hop = e < 0.5 ? sin(.pi * e / 0.5) : 0
            pose.bodyDY = -4 * hop
            pose.headRot -= 0.1 * (1 - ease(e / 0.8))
            pose.nearHand = lerp(Skeleton.relaxedNear, CGPoint(x: near.x + 10, y: near.y - 16),
                                 ease(e / 0.15) * (1 - ease((e - 0.5) / 0.4)))
            pose.kick = hop * 0.5
            pose.kickPhase = e * 20
            pose.shoulderLift = 2.5 * (1 - ease(e / 0.6))
            pose.torsoRot = 0.1 * (1 - ease(e / 0.6))
        case .angry:
            // hunch, shake, stamp: shoulders up, body drops on each stamp
            pose.eyes = .angry
            pose.shakeX = sin(e * 55) * 0.5
            pose.headDY += 0.6
            pose.grip = CGPoint(x: 2, y: -5 * ease(e / 0.2))
            pose.swordRot = 0.5 * ease(e / 0.2)
            pose.shoulderLift = 2 * ease(e / 0.15)
            pose.torsoRot = -0.06 * ease(e / 0.15)
            pose.bodyDY = abs(sin(e * 9)) * 1.2
            pose.kick = 0.12
            pose.kickPhase = e * 9
        case .happy:
            pose.eyes = .happy
            let hop = abs(sin(e * 8))
            pose.bodyDY = -2.4 * hop
            pose.headDY -= 0.6 * hop
            pose.nearHand = lerp(Skeleton.relaxedNear, CGPoint(x: near.x + 8, y: near.y - 12 - 3 * hop), 0.7 * ease(e / 0.2))
            pose.shoulderLift = 1.2 * hop
        case .swing:
            // wind up above the head, cut down from head height, hold the hit, recover
            let base = pose.grip, baseRot = pose.swordRot, baseTorso = pose.torsoRot
            let wind = (grip: CGPoint(x: -1, y: -22), rot: 2.0, torso: 0.12, lift: 2.0)
            let hit = (grip: CGPoint(x: 7, y: -10), rot: -1.5, torso: -0.2, lift: -1.2)
            func blend(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
            pose.nearHand = nil          // two hands on the hilt
            if e < 0.7 {
                let k = ease(e / 0.55)
                pose.grip = lerp(base, wind.grip, k)
                pose.swordRot = blend(baseRot, wind.rot, k)
                pose.torsoRot = blend(baseTorso, wind.torso, k)
                pose.shoulderLift = wind.lift * k
                pose.bodyDX = -0.8 * k
            } else if e < 1.15 {
                let k = ease((e - 0.7) / 0.14)
                let since = max(0, e - 0.84)
                pose.grip = lerp(wind.grip, hit.grip, k)
                pose.swordRot = blend(wind.rot, hit.rot, k)
                pose.torsoRot = blend(wind.torso, hit.torso, k)
                pose.shoulderLift = blend(wind.lift, hit.lift, k)
                pose.bodyDX = blend(-0.8, 2.2, k)
                pose.crouch = 0.3 * k
                pose.bodyDY = 1.0 * k
                pose.shakeX = sin(e * 80) * 0.9 * exp(-since * 14)     // the blow lands
                if since > 0, since < 0.1 { pose.glitch = 0.3 * (1 - since / 0.1) }
            } else {
                let k = ease((e - 1.15) / 0.7)
                pose.grip = lerp(hit.grip, base, k)
                pose.swordRot = blend(hit.rot, baseRot, k)
                pose.torsoRot = blend(hit.torso, baseTorso, k)
                pose.shoulderLift = hit.lift * (1 - k)
                pose.bodyDX = 2.2 * (1 - k)
                pose.crouch = 0.3 * (1 - k)
                pose.bodyDY = 1.0 * (1 - k)
            }
        case .look:
            let steps = [-2, 2, -1, 0]
            pose.eyeDX = steps[min(steps.count - 1, Int(e / 0.55))]
            pose.headRot += 0.07 * sin(e * 3.5)
            pose.bodyDX = 0.6 * sin(e * 3.5)
        case .finished:
            Self.applyFinished(e: e, to: &pose)
            if e > 0.22, finishedStage < 1 { finishedStage = 1; onSound?(.swish) }
            if e > 0.8, finishedStage < 2 { finishedStage = 2; onSound?(.scrape) }
        case .flourish:
            Self.applyFlourish(e: e, to: &pose)
            if e > 0.28, finishedStage < 1 { finishedStage = 1; onSound?(.swish) }
            if e > 0.97, finishedStage < 2 { finishedStage = 2; onSound?(.swish) }
            if e > 1.08, finishedStage < 3 { finishedStage = 3; onSound?(.clang) }
        case .fumble:
            Self.applyFumble(e: e, to: &pose)
            if e > 0.62, finishedStage < 1 { finishedStage = 1; onSound?(.tick) }     // a faint tick as it is caught
        case .guard_:
            let k = ease(e / 0.5) * (1 - ease((e - 6.0) / 0.6))
            Self.applyGuard(guardKind, k: k, to: &pose)
        case .glitch:
            pose.glitch = max(0, 1 - e / duration(.glitch))
            if Int(e * 25) % 3 == 0 { pose.eyes = .closed }
        }
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { Self.lerp(a, b, t) }
}

// MARK: - sentinel API (called by the Claude Code sentinel)

extension Brain {
    /// barrier = a permission is waiting, attend = Claude asked a question.
    enum SentinelHold: Equatable { case none, barrier, attend }

    /// A session finished: flick the blood off, scrape the point along the ground, one gold spark settles on the shoulder.
    /// Wizzy instead casts with the staff: a feast of stars and a chime, one gold star joins the others.
    func playFinished(at now: Double = CACurrentMediaTime()) {
        if Mage.isSelected { feastStart = now; onSound?(.chime); return }
        start(.finished, at: now, silent: true)
    }

    /// A session stopped with an error: the sword slips out of the hand and is caught again.
    /// Wizzy's spell misfires instead: a broken puff of smoke and sparks from the staff, and a flinch.
    func playError(at now: Double = CACurrentMediaTime()) {
        if Mage.isSelected { misfireStart = now; onSound?(.fizzle); return }
        start(.fumble, at: now, silent: true)
    }

    /// A permission has waited too long: one short shake of the barrier sword and a clang (Wizzy: the rune pulses).
    func remindPermission(at now: Double = CACurrentMediaTime()) {
        guard sentinelHold == .barrier else { return }
        remindStart = now
        onSound?(Mage.isSelected ? .nudge : .clang)
    }

    /// Glitch stands still in its sentinel pose; Wizzy keeps drifting, glancing and wandering around its rune or orb.
    var idleLifeRuns: Bool { sentinelHold == .none || Mage.isSelected }

    var actionKind: Action? { action?.kind }

    /// Wizzy's sentinel moves are overlays on its idle life, so they never block it.
    private func applyMageSentinel(_ now: Double, carried: Bool, to pose: inout Pose) {
        let free = action == nil && !carried
        switch sentinelHold {
        case .none: break
        case .barrier:
            pose.rune = now - holdSince
            if free { pose.eyeDX = -2 }                       // reads the rune hanging in front of it
            let r = now - remindStart
            if r >= 0, r < 0.8 { pose.nudge = r }
        case .attend:
            pose.orb = now - holdSince
            if free { pose.eyeDX = 2; pose.headDY += 0.8; pose.headRot += 0.05 }   // looks down into the ball
        }
        if let f = feastStart {
            let e = now - f
            if e > Mage.feastLength { feastStart = nil } else {
                pose.feast = e
                if e > 0.3, e < 2.2 { pose.eyes = .happy }
            }
        }
        if let m = misfireStart {
            let e = now - m
            if e > Mage.misfireLength { misfireStart = nil } else {
                pose.misfire = e
                if e < 0.5 { pose.shakeX += sin(e * 60) * 0.8 * (1 - e / 0.5); pose.eyes = .wide }
            }
        }
    }

    func setSentinel(hold: SentinelHold, redSparks: Int, goldSparks: Int, at now: Double = CACurrentMediaTime()) {
        self.redSparks = redSparks
        self.goldSparks = goldSparks
        guard hold != sentinelHold else { return }
        sentinelHold = hold
        holdSince = now
        walkTarget = nil
        if hold == .barrier {
            flareUntil = now + 0.3
            onSound?(Mage.isSelected ? .rune : .clang)
        }
        if hold == .attend, Mage.isSelected { onSound?(.orb) }
    }
}
