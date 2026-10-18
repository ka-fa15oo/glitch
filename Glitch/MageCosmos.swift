import SwiftUI

/// Wizzy's two big scenes, drawn on a see-through, click-through window over the whole screen (the pet window is too
/// small for them): the arrival, where it draws a road through the stars and glides down it, and the goodbye, where a
/// black hole opens beside it and takes it in.
enum MageCosmos {
    static let starLight = Color(red: 0.91, green: 0.90, blue: 1.0)
    static let starGlow = Color(red: 0.50, green: 0.53, blue: 0.77)
    static let pink = Color(red: 0.75, green: 0.38, blue: 0.62)
    static let gold = Color(red: 0.94, green: 0.85, blue: 0.56)
    static let deep = Color(red: 0.20, green: 0.16, blue: 0.40)

    static func ease(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    // MARK: - the star road

    /// A cubic Bézier through the sky, in whatever coordinates its user likes.
    struct Road {
        var p0, p1, p2, p3: CGPoint
        func point(_ u: Double) -> CGPoint {
            let v = 1 - u
            let a = v * v * v, b = 3 * v * v * u, c = 3 * v * u * u, d = u * u * u
            return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
        }
        func tangent(_ u: Double) -> CGPoint {
            let v = 1 - u
            let x = 3 * v * v * (p1.x - p0.x) + 6 * v * u * (p2.x - p1.x) + 3 * u * u * (p3.x - p2.x)
            let y = 3 * v * v * (p1.y - p0.y) + 6 * v * u * (p2.y - p1.y) + 3 * u * u * (p3.y - p2.y)
            let n = max(0.0001, hypot(x, y))
            return CGPoint(x: x / n, y: y / n)
        }
    }

    /// The road is drawn in the first 0.9 s, the mage leaves at `glideStart` and arrives `glideDuration` later.
    static let glideStart = 0.7, glideDuration = 1.6
    static let roadLength = glideStart + glideDuration + 1.1

    /// Where the mage is on the road at `age` seconds (0...1).
    static func glideProgress(_ age: Double) -> Double { ease((age - glideStart) / glideDuration) }

    struct RoadView: View {
        let road: Road                // view coordinates, y down
        var fixedAge: Double?
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge { canvas(age: fixedAge) } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        private func canvas(age: Double) -> some View {
            Canvas { c, _ in
                let unit: CGFloat = 2
                let drawn = 1 - pow(1 - min(1, age / 0.9), 3)                        // the pen races ahead, then slows
                let fade = 1 - ease((age - glideStart - glideDuration - 0.05) / 0.9)
                guard fade > 0 else { return }
                var line = Path(), glow = Path(), core = Path()
                func px(_ p: inout Path, _ x: Double, _ y: Double) {
                    p.addRect(CGRect(x: (x / Double(unit)).rounded() * Double(unit), y: (y / Double(unit)).rounded() * Double(unit),
                                     width: Double(unit), height: Double(unit)))
                }
                // a dotted line along the road, as far as the pen has got
                var u = 0.0
                var i = 0
                while u < drawn {
                    let p = road.point(u)
                    if i % 3 != 2 {
                        px(&line, p.x, p.y); px(&line, p.x + Double(unit), p.y); px(&line, p.x, p.y + Double(unit))
                    }
                    u += 0.004
                    i += 1
                }
                // stars set along it, each with a flash as it lands and a slow twinkle after
                var rng = SplitMix(seed: 0xA57A)
                func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
                let n = 34
                for k in 0 ..< n {
                    let at = (Double(k) + 0.5 + (random() - 0.5) * 0.6) / Double(n)
                    guard at <= drawn else { continue }
                    let p = road.point(at)
                    let off = CGPoint(x: (random() - 0.5) * 34, y: (random() - 0.5) * 34)   // scattered either side of the line
                    let sx = p.x + off.x, sy = p.y + off.y
                    let born = at * 0.9
                    let flash = 1 - (age - born) / 0.35
                    let big = k % 3 == 0
                    px(&core, sx, sy)
                    if big { px(&core, sx + Double(unit), sy); px(&core, sx, sy + Double(unit)); px(&core, sx + Double(unit), sy + Double(unit)) }
                    let twinkle = sin(age * 3 + Double(k) * 2.1) > 0.45
                    if flash > 0 || twinkle || big {
                        for (ox, oy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] {
                            px(&glow, sx + ox * Double(unit) * (big ? 2 : 1), sy + oy * Double(unit) * (big ? 2 : 1))
                        }
                    }
                }
                var layer = c
                layer.opacity = fade
                var faint = layer
                faint.opacity *= 0.7
                faint.fill(line, with: .color(starGlow))
                layer.fill(glow, with: .color(starGlow))
                layer.fill(core, with: .color(starLight))
                // the pen: a bright star at the front of the line
                if age < 0.95 {
                    let p = road.point(drawn)
                    var head = Path(), halo = Path()
                    for dy in -2 ... 2 { for dx in -2 ... 2 where abs(dx) + abs(dy) <= 3 { px(&head, p.x + Double(dx) * Double(unit), p.y + Double(dy) * Double(unit)) } }
                    for (ox, oy) in [(-5.0, 0.0), (5, 0), (0, -5), (0, 5), (-4, -4), (4, 4), (-4, 4), (4, -4)] { px(&halo, p.x + ox * Double(unit), p.y + oy * Double(unit)) }
                    layer.fill(halo, with: .color(gold))
                    layer.fill(head, with: .color(Color(red: 1, green: 0.97, blue: 0.85)))
                }
                // sparkles shed behind the mage as it glides
                let e = age - glideStart
                if e > 0, e < glideDuration + 0.5 {
                    let now = glideProgress(age)
                    var sp = Path(), sp2 = Path()
                    for j in 0 ..< 26 {
                        let back = Double(j) / 26 * 0.22
                        let uu = max(0, now - back)
                        let q = road.point(uu)
                        let a = random() * 6.28, d = random() * 26 * (1 + back * 4)
                        let drift = back * 40
                        let x = q.x + cos(a) * d, y = q.y + sin(a) * d + drift
                        if sin(age * 9 + Double(j)) > -0.3 {
                            if j % 3 == 0 { px(&sp2, x, y) } else { px(&sp, x, y) }
                        }
                    }
                    layer.fill(sp, with: .color(starLight))
                    layer.fill(sp2, with: .color(gold))
                }
            }
        }
    }

    // MARK: - the black hole

    struct HoleView: View {
        let center: CGPoint           // view coordinates, y down
        var radius: Double = 30       // in art pixels
        var collapseAt: Double = 3.0
        var fixedAge: Double?
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge { canvas(age: fixedAge) } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        private func canvas(age: Double) -> some View {
            Canvas { c, _ in
                let unit = 2.0
                let open = ease(age / 0.9)
                let collapse = ease((age - collapseAt) / 0.5)
                let r = radius * open * (1 - collapse)
                let cx = center.x / unit, cy = center.y / unit
                var layers = Array(repeating: Path(), count: 7)    // 0 void, 1 deep, 2 violet, 3 pink, 4 gold, 5 white, 6 stars
                func cell(_ tone: Int, _ x: Int, _ y: Int) {
                    layers[tone].addRect(CGRect(x: Double(x) * unit, y: Double(y) * unit, width: unit, height: unit))
                }
                if r > 0.5 {
                    let reach = Int((r * 1.75).rounded(.up))
                    for y in Int(cy) - reach ... Int(cy) + reach {
                        for x in Int(cx) - reach ... Int(cx) + reach {
                            let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                            let d = hypot(dx, dy) / r                      // 1 = the edge of the hole
                            if d > 1.75 { continue }
                            let theta = atan2(dy, dx)
                            if d < 0.64 { cell(0, x, y); continue }          // the void
                            if d < 0.76 {                                     // the thin bright ring, brighter on one side
                                let side = 0.5 + 0.5 * cos(theta - 0.9)
                                cell(side > 0.55 ? 5 : 4, x, y)
                                continue
                            }
                            // the disc: spiral arms that turn as they fall in
                            let arm = 0.5 + 0.5 * sin(3 * theta + 4.2 * log(d / 0.76) - age * 3.6)
                            let fall = (d - 0.76) / 0.99
                            let strength = pow(1 - fall, 1.2) * (0.35 + 0.65 * arm)
                            if strength < 0.16 { continue }
                            let heat = strength + (1 - fall) * 0.25
                            let tone = heat > 0.85 ? 5 : heat > 0.62 ? 4 : heat > 0.42 ? 3 : heat > 0.28 ? 2 : 1
                            cell(tone, x, y)
                        }
                    }
                    // stars dragged in from far out
                    var rng = SplitMix(seed: 0xB1AC)
                    func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
                    for _ in 0 ..< 64 {
                        let a0 = random() * 6.28, r0 = 1.9 + random() * 2.4, speed = 0.18 + random() * 0.3
                        let prog = (age * speed + random()).truncatingRemainder(dividingBy: 1)
                        let rr = r0 * (1 - prog) + 0.7 * prog
                        let aa = a0 + prog * prog * 5.0
                        let x = Int((cx + cos(aa) * rr * r).rounded()), y = Int((cy + sin(aa) * rr * r * 0.9).rounded())
                        if rr > 0.78, open > 0.2 { cell(6, x, y) }
                    }
                }
                let palette: [Color] = [Color(red: 0.01, green: 0.0, blue: 0.04), deep, Color(red: 0.36, green: 0.22, blue: 0.62),
                                        pink, gold, Color(red: 1, green: 0.97, blue: 0.88), starLight]
                for (path, color) in zip(layers, palette) { c.fill(path, with: .color(color)) }
                // the hole collapses in a flash and a ring of light
                if collapse > 0 {
                    let flash = collapse * (1 - ease((age - collapseAt - 0.5) / 0.5))
                    let ringR = radius * (0.3 + 2.2 * collapse) * unit
                    var ring = Path()
                    ring.addEllipse(in: CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2))
                    c.stroke(ring, with: .color(starLight.opacity(0.9 * (1 - collapse))), lineWidth: 3)
                    var glow = Path()
                    let g = radius * 0.7 * unit * flash
                    glow.addEllipse(in: CGRect(x: center.x - g, y: center.y - g, width: g * 2, height: g * 2))
                    c.fill(glow, with: .color(Color(red: 1, green: 0.97, blue: 0.9).opacity(0.85 * flash)))
                }
            }
        }
    }

    // MARK: - overlay windows

    @MainActor private static var overlay: NSWindow?

    /// A window the size of the screen that holds `center`, click-through and see-through; closes itself after `life`.
    @MainActor private static func showOverlay(containing point: CGPoint, life: Double,
                                               content: (_ frame: CGRect) -> AnyView) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return }
        let frame = screen.frame
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content(frame))
        overlay?.close()
        overlay = window
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + life) {
            window.close()
            if overlay === window { overlay = nil }
        }
    }

    /// `road` is in screen coordinates of the whole desktop (y up), as the centre of the pet window.
    @MainActor static func openStarRoad(_ road: Road) {
        showOverlay(containing: road.p3, life: roadLength) { frame in
            func view(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y) }
            return AnyView(RoadView(road: Road(p0: view(road.p0), p1: view(road.p1), p2: view(road.p2), p3: view(road.p3))))
        }
    }

    @MainActor static func openBlackHole(at center: CGPoint, length: Double) {
        showOverlay(containing: center, life: length) { frame in
            AnyView(HoleView(center: CGPoint(x: center.x - frame.minX, y: frame.maxY - center.y), collapseAt: length - 0.9))
        }
    }
}
