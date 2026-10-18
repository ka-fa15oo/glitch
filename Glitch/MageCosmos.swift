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

    // MARK: - the star rain

    /// The rain falls for the first 1.5 s over the landing spot; the star dust starts to gather into Wizzy at
    /// `materializeAt`. The overlay and the brain share these times.
    static let materializeAt = 1.0
    static let rainLength = 3.0

    struct RainView: View {
        let landing: CGPoint          // view coordinates (y down) of the middle of the pet window
        let ground: Double            // y of the ground line there
        var fixedAge: Double?
        private let began = Date.timeIntervalSinceReferenceDate

        var body: some View {
            if let fixedAge { canvas(age: fixedAge) } else {
                TimelineView(.animation) { canvas(age: $0.date.timeIntervalSinceReferenceDate - began) }
            }
        }

        private func canvas(age: Double) -> some View {
            Canvas { c, size in
                let unit = 2.0
                var rng = SplitMix(seed: 0x5A1A)
                func random() -> Double { Double(rng.next() % 10_000) / 10_000 }
                var layers = Array(repeating: Path(), count: 4)       // glow, mid, white, gold
                func px(_ tone: Int, _ x: Double, _ y: Double) {
                    layers[tone].addRect(CGRect(x: (x / unit).rounded() * unit, y: (y / unit).rounded() * unit, width: unit, height: unit))
                }
                let fade = 1 - ease((age - rainLength + 0.7) / 0.7)
                guard fade > 0 else { return }
                let count = 340
                for k in 0 ..< count {
                    // most of the rain falls in a column over the landing spot, some across the rest of the sky
                    let wide = k % 5 == 0
                    let spread = wide ? size.width * 0.9 : 300.0
                    let x0 = landing.x + (random() + random() - 1) * spread
                    let delay = pow(random(), 0.8) * 1.2              // it thickens, then thins
                    let speed = 900 + 700 * random()
                    let slant = -0.32
                    let tau = age - delay
                    if tau < 0 { continue }
                    let startY = -30.0
                    let y = startY + speed * tau
                    let x = x0 + slant * speed * tau
                    let hit = ground - random() * 26                   // lands somewhere along the ground line
                    let big = k % 6 == 0
                    let tone = big ? 3 : (k % 3 == 0 ? 2 : 1)
                    if y < hit {
                        // a falling star: a bright head with a fading streak behind it, along the fall direction
                        let len = big ? 9 : 6
                        for t in 0 ..< len {
                            let back = Double(t) * unit * 1.6               // further up the line it came down
                            px(t < 2 ? tone : 0, x - slant * back, y - back)
                        }
                        if big { px(3, x + unit, y); px(3, x, y + unit) }
                    } else {
                        // landed: a flash, then it fades
                        let since = (y - hit) / speed
                        if since < 0.3 {
                            px(2, x, hit); px(big ? 3 : 1, x + unit, hit); px(1, x - unit, hit); px(0, x, hit - unit)
                            if since < 0.12 { px(0, x + 2 * unit, hit); px(0, x - 2 * unit, hit); px(0, x, hit - 2 * unit) }
                        }
                    }
                }
                var layer = c
                layer.opacity = fade
                // a glow gathers on the ground where it is raining
                let g = ease((age - 0.3) / 0.8) * (1 - ease((age - materializeAt - 0.8) / 0.8))
                if g > 0.01 {
                    var glow = layer
                    glow.opacity = 0.42 * g * fade
                    let w = 150.0 + 90 * g, h = 160.0 + 60 * g
                    glow.fill(Path(ellipseIn: CGRect(x: landing.x - w / 2, y: ground - h * 0.8, width: w, height: h)),
                              with: .radialGradient(Gradient(colors: [starLight.opacity(0.9), starGlow.opacity(0.5), .clear]),
                                                    center: CGPoint(x: landing.x, y: ground - h * 0.3), startRadius: 0, endRadius: h * 0.55))
                }
                layer.fill(layers[0], with: .color(starGlow))
                layer.fill(layers[1], with: .color(Color(red: 0.72, green: 0.74, blue: 1.0)))
                layer.fill(layers[2], with: .color(starLight))
                layer.fill(layers[3], with: .color(Color(red: 1, green: 0.95, blue: 0.7)))
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

    /// `center` is the middle of the pet window in screen coordinates (y up).
    @MainActor static func openStarRain(over center: CGPoint) {
        showOverlay(containing: center, life: rainLength) { frame in
            let ground = Double(frame.maxY - (center.y - 80))                      // the feet are 80 pt under the middle
            return AnyView(RainView(landing: CGPoint(x: center.x - frame.minX, y: frame.maxY - center.y), ground: ground))
        }
    }

    @MainActor static func openBlackHole(at center: CGPoint, length: Double) {
        showOverlay(containing: center, life: length) { frame in
            AnyView(HoleView(center: CGPoint(x: center.x - frame.minX, y: frame.maxY - center.y), collapseAt: length - 0.9))
        }
    }
}
