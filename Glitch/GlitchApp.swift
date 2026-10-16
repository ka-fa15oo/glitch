import AppKit
import ServiceManagement
import SwiftUI

@main
struct GlitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Glitch", systemImage: "square.grid.3x3.fill") {
            LoginToggle()
            Button(delegate.sound.isMuted ? "Sesi aç" : "Sessize al") {
                delegate.sound.isMuted.toggle()
            }
            GravityToggle(brain: delegate.brain)
            Divider()
            Button("Çıkış") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

private struct GravityToggle: View {
    let brain: Brain
    @State private var on = true

    var body: some View {
        Button(on ? "✓ Yer çekimi" : "Yer çekimi") {
            on.toggle()
            brain.gravityEnabled = on
        }
    }
}

private struct LoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Button(enabled ? "✓ Girişte başlat" : "Girişte başlat") {
            do {
                if enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
            } catch {
                NSLog("Login item change failed: \(error)")
            }
            enabled = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Borderless windows refuse key status by default, which blocks mouse events on some setups.
final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let brain = Brain()
    let sound = SoundBank()
    private var window: NSWindow?
    private var clickMonitor: Any?
    private var mouseDownAt: (time: Double, origin: CGPoint, mouse: CGPoint)?
    private var pressedQuitButton = false
    private var fullscreenTimer: Timer?
    private var brainTimer: Timer?
    private var farewellDone = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--snapshot"), args.indices.contains(flag + 1) {
            renderSnapshot(to: args[flag + 1], time: args.indices.contains(flag + 2) ? Double(args[flag + 2]) ?? 0 : 0,
                           mood: args.indices.contains(flag + 3) ? args[flag + 3] : "")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        let size = RobotView.canvasSize
        let window = PetWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: RobotView(brain: brain))
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.midY - size.height / 2))
        }
        window.orderFrontRegardless()
        self.window = window

        brain.onSound = { [weak self] effect in self?.sound.play(effect) }
        brain.mouseTarget = { [weak self] in
            guard let frame = self?.window?.frame else { return nil }
            return (NSEvent.mouseLocation, CGPoint(x: frame.midX, y: frame.midY))
        }
        brain.windowOrigin = { [weak self] in self?.window?.frame.origin ?? .zero }
        brain.setWindowOrigin = { [weak self] origin in self?.window?.setFrameOrigin(origin) }
        brain.walkBounds = { [weak self] in
            guard let window = self?.window, let screen = window.screen ?? NSScreen.main else { return .zero }
            let f = screen.visibleFrame
            let floor = f.minY - CGFloat(RobotView.padBottom) * RobotView.scale
            return CGRect(x: f.minX - CGFloat(RobotView.padLeft) * RobotView.scale, y: floor,
                          width: f.width - window.frame.width + CGFloat(RobotView.padLeft + RobotView.padRight) * RobotView.scale,
                          height: f.maxY - floor - window.frame.height + CGFloat(RobotView.padTop) * RobotView.scale)
        }
        brain.groundY = { [weak self] in
            guard let window = self?.window, let screen = window.screen ?? NSScreen.main else { return 0 }
            return screen.visibleFrame.minY - CGFloat(RobotView.padBottom) * RobotView.scale
        }
        brain.start(.wake)
        // common modes: the goodbye plays while a pending terminate has the run loop in the modal mode
        brainTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.update(at: CACurrentMediaTime()) }
        }
        RunLoop.main.add(timer, forMode: .common)
        brainTimer = timer

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.start(.sad) }
        }
        workspace.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.start(.farewell) }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.start(.wake) }
        }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }

        fullscreenTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
    }

    // MARK: - clicks

    private func handle(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        let now = CACurrentMediaTime()
        let mouse = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            let viewSize = window.frame.size
            let p = event.locationInWindow
            pressedQuitButton = brain.quitButtonVisible
                && RobotView.quitRect.contains(CGPoint(x: p.x, y: viewSize.height - p.y))
            mouseDownAt = (now, window.frame.origin, mouse)
            // where on the sprite was it grabbed? (sprite space, accounting for the mirrored canvas)
            let size = window.frame.size
            let point = event.locationInWindow
            let scale = RobotView.scale
            let x = (brain.current.facingRight ? size.width - point.x : point.x) / scale - CGFloat(RobotView.padLeft)
            let y = (size.height - point.y) / scale - CGFloat(RobotView.padTop)
            brain.grabPoint = CGPoint(x: max(0, min(CGFloat(Sprite.width), x)), y: max(0, min(CGFloat(Sprite.height), y)))
        case .leftMouseDragged:
            guard let down = mouseDownAt else { return }
            if hypot(mouse.x - down.mouse.x, mouse.y - down.mouse.y) > 3 { brain.carried(mouseX: Double(mouse.x)) }
            window.setFrameOrigin(NSPoint(
                x: down.origin.x + mouse.x - down.mouse.x,
                y: down.origin.y + mouse.y - down.mouse.y
            ))
        case .leftMouseUp:
            if pressedQuitButton {
                pressedQuitButton = false
                let size = window.frame.size
                let p = event.locationInWindow
                if RobotView.quitRect.contains(CGPoint(x: p.x, y: size.height - p.y)) {
                    quitWithGoodbye()
                }
            } else if let down = mouseDownAt {
                let moved = hypot(mouse.x - down.mouse.x, mouse.y - down.mouse.y)
                if moved < 3, now - down.time < 0.5 {
                    if event.clickCount >= 2 { brain.revealQuitButton() } else { brain.clicked() }
                }
            }
            mouseDownAt = nil
        default:
            break
        }
    }

    // MARK: - hide while a fullscreen app is up

    private func updateVisibility() {
        guard let window else { return }
        let hide = Self.fullscreenAppIsFrontmost()
        if hide, window.isVisible {
            window.orderOut(nil)
        } else if !hide, !window.isVisible {
            window.orderFrontRegardless()
            brain.windowOrigin = { [weak self] in self?.window?.frame.origin ?? .zero }
        brain.setWindowOrigin = { [weak self] origin in self?.window?.setFrameOrigin(origin) }
        brain.walkBounds = { [weak self] in
            guard let window = self?.window, let screen = window.screen ?? NSScreen.main else { return .zero }
            let f = screen.visibleFrame
            let floor = f.minY - CGFloat(RobotView.padBottom) * RobotView.scale
            return CGRect(x: f.minX - CGFloat(RobotView.padLeft) * RobotView.scale, y: floor,
                          width: f.width - window.frame.width + CGFloat(RobotView.padLeft + RobotView.padRight) * RobotView.scale,
                          height: f.maxY - floor - window.frame.height + CGFloat(RobotView.padTop) * RobotView.scale)
        }
        brain.start(.wake)
        // common modes: the goodbye plays while a pending terminate has the run loop in the modal mode
        brainTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.update(at: CACurrentMediaTime()) }
        }
        RunLoop.main.add(timer, forMode: .common)
        brainTimer = timer
        }
    }

    private static func fullscreenAppIsFrontmost() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        let screens = NSScreen.screens.map(\.frame)
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int) != ownPID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            if screens.contains(where: { abs($0.width - bounds.width) < 1 && abs($0.height - bounds.height) < 1 }) {
                return true
            }
        }
        return false
    }

    // MARK: - goodbye wave before quitting

    /// The close button: kneel and sink into the blood first, then quit.
    private func quitWithGoodbye() {
        guard !farewellDone else { return }
        farewellDone = true
        brain.start(.farewell)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) { NSApp.terminate(nil) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if farewellDone || window == nil || !(window?.isVisible ?? false) { return .terminateNow }
        farewellDone = true
        brain.start(.farewell)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // MARK: - snapshot (dev helper)

    private func renderSnapshot(to path: String, time: Double, mood: String) {
        var pose = Brain.Pose()
        switch mood {
        case "angry": pose.eyes = .angry; pose.headDY = 0.6
        case "happy": pose.eyes = .happy
        case "wide": pose.eyes = .wide; pose.bodyDY = -4
        case "wave": pose.eyes = .happy; pose.nearHand = CGPoint(x: 60, y: 17)
        case "up": pose.nearHand = nil; pose.grip = CGPoint(x: -1, y: -22); pose.swordRot = 2.0; pose.torsoRot = 0.12; pose.shoulderLift = 2
        case "chop": pose.nearHand = nil; pose.grip = CGPoint(x: 7, y: -10); pose.swordRot = -1.5; pose.torsoRot = -0.2; pose.shoulderLift = -1.2; pose.bodyDX = 2.2; pose.crouch = 0.3; pose.bodyDY = 1
        case "sad": pose.eyes = .half; pose.headDY = 2.5; pose.headRot = 0.07
        case "glitch": pose.glitch = 1
        case "quit": pose.showQuit = true
        case "cocoon0": pose.cocoonAge = 0.5; pose.reveal = 0
        case "cocoon1": pose.cocoonAge = 1.2; pose.reveal = 0.5
        case "cocoon2": pose.cocoonAge = 2.0; pose.reveal = 1
        case "goodbye2": pose.kneel = 1; pose.nearHand = nil; pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82; pose.torsoRot = -0.08; pose.headDY = 2.4; pose.headRot = 0.1; pose.cocoonAge = 2.2; pose.cocoonHold = true; pose.reveal = 0.2
        case "goodbye": pose.kneel = 1; pose.nearHand = nil; pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82; pose.torsoRot = -0.08; pose.headDY = 2.4; pose.headRot = 0.1; pose.cocoonAge = 1.0; pose.cocoonHold = true; pose.reveal = 0.55
        case "wind": pose.wind = 1; pose.eyes = .open
        case "fling": pose.carried = true; pose.carriedAmount = 1; pose.fling = 0.9; pose.hang = 0.12; pose.kick = 0.3; pose.kickPhase = 1; pose.eyes = .angry
        case "fall": pose.fallAmount = 1; pose.falling = true; pose.eyes = .wide; pose.kick = 0.5; pose.kickPhase = 1
            pose.nearHand = CGPoint(x: 63, y: 23); pose.farHand = CGPoint(x: 18, y: 23); pose.headRot = -0.08
        case "impact": pose.squash = 0.9; pose.crouch = 0.9; pose.eyes = .wide; pose.torsoRot = -0.1; pose.headDY = 1.5
            pose.nearHand = CGPoint(x: 60, y: 34)
        case "stagger": pose.bodyDX = 2; pose.torsoRot = 0.12; pose.swordRot = 0.5; pose.stepAmount = 0.5
            pose.stepPhase = 1; pose.shoulderLift = 1.5; pose.eyes = .wide
        case "dust": pose.eyes = .half; pose.nearHand = CGPoint(x: 52, y: 66); pose.headDY = 0.6
        case "giveup": pose.carried = true; pose.hang = 0.04; pose.eyes = .half; pose.headDY = 2; pose.headRot = 0.12
            pose.kick = 0.02; pose.grip = CGPoint(x: 0, y: 2); pose.bodyDY = 2.5
        case "scared": pose.carried = true; pose.hang = 0.05; pose.eyes = .wide; pose.shoulderLift = 1.8
            pose.grip = CGPoint(x: 0, y: -2.5); pose.headRot = 0.08; pose.eyeDX = -1
        case "swat": pose.carried = true; pose.hang = 0.1; pose.eyes = .angry; pose.grip = CGPoint(x: -3, y: -10)
            pose.swordRot = 1.5; pose.shoulderLift = 2; pose.torsoRot = 0.1; pose.kick = 0.3; pose.kickPhase = 2
        case "tilt": pose.headRot = 0.09; pose.eyeDX = 2
        case "walk": pose.stepAmount = 1; pose.stepPhase = 1.2; pose.facingRight = true; pose.bodyDY = -1
        case "walk2": pose.stepAmount = 1; pose.stepPhase = 1.2 + .pi; pose.facingRight = true; pose.bodyDY = -1
        case "carried": pose.carried = true; pose.hang = 0.15; pose.kick = 1; pose.kickPhase = 1.0; pose.eyes = .angry
            pose.grip = CGPoint(x: 4, y: -3); pose.swordRot = 0.5; pose.bodyDY = 1.5
        case "kneel": pose.kneel = 1; pose.nearHand = nil; pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82; pose.torsoRot = -0.08; pose.headDY = 2.4; pose.headRot = 0.1
        case "kneel2": pose.kneel = 0.5; pose.nearHand = nil; pose.grip = CGPoint(x: -1, y: -9); pose.torsoRot = -0.02; pose.headDY = 1.2; pose.headRot = 0.05
        case "planted": Brain.applyStance(.planted, to: &pose)
        case "twohand": Brain.applyStance(.twoHand, to: &pose)
        case "salute": Brain.applySalute(k: 1, to: &pose)
        case "pflug": Brain.applyGuard(.pflug, k: 1, to: &pose)
        case "ochs": Brain.applyGuard(.ochs, k: 1, to: &pose)
        case "vomtag": Brain.applyGuard(.vomTag, k: 1, to: &pose)
        case "stretch": pose.nearHand = CGPoint(x: 63, y: 18); pose.farHand = CGPoint(x: 17, y: 18); pose.farWeight = 1; pose.eyes = .open
        default:
            if mood.hasPrefix("blood:"), let age = Double(mood.dropFirst(6)) { pose.bloodAge = age }
            else if mood.hasPrefix("walk:"), let phase = Double(mood.dropFirst(5)) {
                pose.stepAmount = 1; pose.stepPhase = phase; pose.facingRight = false
            }
        }
        let view = RobotView(fixedTime: time, fixedPose: pose)
            .background(Color(red: 0.79, green: 0.81, blue: 0.85))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
