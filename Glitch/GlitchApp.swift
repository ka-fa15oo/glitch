import AppKit
import os
import ServiceManagement
import SwiftUI

@main
struct GlitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() { Prefs.register() }

    var body: some Scene {
        MenuBarExtra("Glitch", image: "MenuBarIcon") {
            SettingsButtons()
            Divider()
            LoginToggle()
            MuteToggle()
            AccessibilityStatus()
            SentinelMenu()
            Divider()
            Button("About Glitch") {
                NSApp.activate()   // an accessory app's panel otherwise opens behind the frontmost app
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        Window("Glitch Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        Window("Welcome to Glitch", id: "welcome") {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(Prefs.d.bool(forKey: Prefs.welcomed) ? .suppressed : .presented)
    }
}

private struct SettingsButtons: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.settingsTab) private var tab = "customize"

    var body: some View {
        Button("Customize…") { open("customize") }
            .keyboardShortcut(",")
        Button("Sound…") { open("sound") }
    }

    private func open(_ name: String) {
        tab = name
        openWindow(id: "settings")
        NSApp.activate()   // an accessory app's window otherwise opens behind the frontmost app
    }
}

private struct MuteToggle: View {
    @AppStorage(Prefs.muted) private var muted = false

    var body: some View {
        Button(muted ? "Unmute" : "Mute") { muted.toggle() }
    }
}

/// Shows whether the text-box guard can work; opens the Accessibility settings when it can't.
private struct AccessibilityStatus: View {
    var body: some View {
        if AXIsProcessTrusted() {
            Text("✓ Text field guard on")
        } else {
            Button("⚠︎ Text field guard off: allow…") {
                TextFieldGuard.askForPermission()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

private struct LoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Button(enabled ? "✓ Open at login" : "Open at login") {
            do {
                if enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
            } catch {
                NSLog("Login item change failed: \(error)")
            }
            enabled = SMAppService.mainApp.status == .enabled
        }
    }
}

/// The pet window's content: the character tinted with the Customize colour theme.
private struct PetRoot: View {
    let brain: Brain
    @AppStorage(Prefs.hue) private var hue = 0.0
    @AppStorage(Prefs.scale) private var scale = 2.0   // re-lays out the canvas when the size changes

    var body: some View {
        RobotView(brain: brain).hueRotation(.degrees(hue))
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
    private var hoverTimer: Timer?
    private var sentinel: SentinelController?
    private var textTimer: Timer?
    private var typingProblem = ""
    private static let textLog = Logger(subsystem: "com.kafa1500.glitch", category: "textguard")
    private var typingFrame: CGRect?
    private var screenLocked = false
    private var lastWake = -100.0
    private var fullscreenHits = 0
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
        if let flag = args.firstIndex(of: "--settings-snapshot"), args.indices.contains(flag + 2) {
            renderSettings(to: args[flag + 1], tab: args[flag + 2])
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
        window.contentView = NSHostingView(rootView: PetRoot(brain: brain))
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.midY - size.height / 2))
        }
        window.orderFrontRegardless()
        self.window = window

        // stay silent while the screen is locked, asleep or the knight is hidden
        brain.onSound = { [weak self] effect in
            guard let self, !self.screenLocked, let window = self.window, window.isVisible,
                  window.occlusionState.contains(.visible) else { return }
            self.sound.play(effect)
        }
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
        applyPrefs()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPrefs() }
        }
        wakeUp()
        let hub = SentinelHub.shared
        sentinel = SentinelController(brain: brain, store: hub.store, feed: hub.feed, projects: hub.projects)
        sentinel?.start()
        // common modes: the goodbye plays while a pending terminate has the run loop in the modal mode
        brainTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.update(at: CACurrentMediaTime()) }
        }
        RunLoop.main.add(timer, forMode: .common)
        brainTimer = timer

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.brain.start(.sad)
                self?.sound.suspend()
            }
        }
        workspace.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.brain.start(.farewell) }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wakeUp() }
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = true }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = false }
        }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }

        // keep out of the text box the user is typing in (needs Accessibility, asked for on the welcome screen)
        brain.keepOut = { [weak self] in self?.typingFrame }
        // the whole silhouette (sword tip and cape too), on the side the knight is facing
        brain.bodyFrame = { [weak self] origin in
            let scale = RobotView.scale, art = Sprite.hitBounds
            let canvasWidth = RobotView.canvasSize.width
            let left = (CGFloat(RobotView.padLeft) + art.minX) * scale
            let x = self?.brain.current.facingRight == true ? canvasWidth - left - art.width * scale : left
            let bottom = (CGFloat(RobotView.padBottom) + CGFloat(Sprite.height) - art.maxY) * scale
            return CGRect(x: origin.x + x, y: origin.y + bottom, width: art.width * scale, height: art.height * scale)
        }
        textTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let frame = TextFieldGuard.focusedTextFrame()
                if frame != self.typingFrame || TextFieldGuard.lastProblem != self.typingProblem {
                    // public: only app ids, roles and frames, never what the user types
                    Self.textLog.notice("text box: \(frame.map { NSStringFromRect($0) } ?? TextFieldGuard.lastProblem, privacy: .public)")
                }
                self.typingFrame = frame
                self.typingProblem = TextFieldGuard.lastProblem
            }
        }

        // clicks only land on the character's own pixels; the empty rest of the window lets them through
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateClickThrough() }
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
                    if event.clickCount >= 2 {
                        brain.revealQuitButton()
                    } else if !(sentinel?.handleClick() ?? false) {
                        brain.clicked()
                    }
                }
            }
            mouseDownAt = nil
        default:
            break
        }
    }

    // MARK: - click-through outside the character

    private func updateClickThrough() {
        guard let window else { return }
        if mouseDownAt != nil {            // keep holding a drag even when the cursor leaves the body
            window.ignoresMouseEvents = false
            sentinel?.hover(false, near: window.frame)
            return
        }
        let over = isOverCharacter(window.mouseLocationOutsideOfEventStream, in: window)
        window.ignoresMouseEvents = !over
        sentinel?.hover(over, near: window.frame)
    }

    /// `point` is in window coordinates (origin bottom-left).
    private func isOverCharacter(_ point: NSPoint, in window: NSWindow) -> Bool {
        let size = window.frame.size
        let top = CGPoint(x: point.x, y: size.height - point.y)
        if brain.quitButtonVisible, RobotView.quitRect.insetBy(dx: -4, dy: -4).contains(top) { return true }
        let pose = brain.current
        let x = pose.facingRight ? size.width - top.x : top.x
        let ax = Int(floor(x / RobotView.scale)) - RobotView.padLeft
        let ay = Int(floor(top.y / RobotView.scale - pose.bodyDY)) - RobotView.padTop
        return Sprite.hit(ax, ay)
    }

    // MARK: - Customize settings

    private func applyPrefs() {
        brain.gravityEnabled = Prefs.d.bool(forKey: Prefs.gravity)
        brain.restScale = [2.0, 1.0, 0.5][min(max(Prefs.d.integer(forKey: Prefs.liveliness), 0), 2)]
        guard let window else { return }
        let size = RobotView.canvasSize, old = window.frame
        guard old.size != size else { return }
        // keep the feet where they were: the transparent padding under them grows with the scale
        let oldScale = old.width / CGFloat(Sprite.width + RobotView.padLeft + RobotView.padRight)
        let pad = CGFloat(RobotView.padBottom)
        window.setFrame(NSRect(x: old.midX - size.width / 2, y: old.minY + pad * (oldScale - RobotView.scale),
                               width: size.width, height: size.height), display: true)
    }

    // MARK: - hide while a fullscreen app is up

    private func updateVisibility() {
        guard let window else { return }
        // two checks in a row (4 s) before hiding, so a lock screen or a window flicking by doesn't toggle it
        let watch = Prefs.d.bool(forKey: Prefs.hideInFullscreen)
        fullscreenHits = watch && Self.fullscreenAppIsFrontmost() ? fullscreenHits + 1 : 0
        let hide = fullscreenHits >= 2
        if hide, window.isVisible {
            window.orderOut(nil)
        } else if !hide, !window.isVisible {
            window.orderFrontRegardless()
            wakeUp()
        }
    }

    /// Plays the arrival at most once every 20 s; waking, unlocking and un-hiding often come in bursts.
    private func wakeUp() {
        let now = CACurrentMediaTime()
        guard now - lastWake > 20 else { return }
        lastWake = now
        brain.start(.wake)
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

    /// Dev helper: draws the Customize or Sound tab to a PNG without clicking through the menu bar.
    private func renderSettings(to path: String, tab: String) {
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 620, height: 640),
                              styleMask: [.titled], backing: .buffered, defer: false)
        if tab == "welcome" {
            window.contentView = NSHostingView(rootView: WelcomeView())
            window.setContentSize(window.contentView!.fittingSize)
        } else {
            Prefs.d.set(tab, forKey: Prefs.settingsTab)
            window.contentView = NSHostingView(rootView: SettingsView())
        }
        window.appearance = NSAppearance(named: .aqua)   // the cached image has no window background, so dark text reads
        window.orderFrontRegardless()
        self.window = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            exit(0)   // skip the goodbye animation that terminate would play
        }
    }

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
        case "storm1", "storm2", "storm3":
            pose.kneel = 1; pose.nearHand = nil; pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82
            pose.torsoRot = -0.08; pose.headDY = 2.4; pose.headRot = 0.1; pose.cocoonHold = true; pose.wind = 1
            pose.cocoonAge = mood == "storm1" ? 0.35 : (mood == "storm2" ? 1.3 : 2.35)
            pose.reveal = mood == "storm1" ? 0.35 : (mood == "storm2" ? 0.2 : 0)
        case "cocoon0": pose.cocoonAge = 0.5; pose.reveal = 0
        case "cocoon1": pose.cocoonAge = 1.2; pose.reveal = 0.5
        case "cocoon2": pose.cocoonAge = 2.0; pose.reveal = 1
        case "goodbye2": pose.kneel = 1; pose.nearHand = nil; pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82; pose.torsoRot = -0.08; pose.headDY = 2.4; pose.headRot = 0.1; pose.cocoonAge = 2.2; pose.cocoonHold = true; pose.reveal = 0.2
        case "goodbye": pose.kneel = 1; pose.nearHand = nil; pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82; pose.torsoRot = -0.08; pose.headDY = 2.4; pose.headRot = 0.1; pose.cocoonAge = 1.0; pose.cocoonHold = true; pose.reveal = 0.55
        case "barrier": Brain.applyBarrier(k: 1, to: &pose); pose.farWeight = 1; pose.nearWeight = 0
        case "attend": Brain.applyAttend(k: 1, to: &pose); pose.farWeight = 1; pose.nearWeight = 0
        case "flick": Brain.applyFinished(e: 0.3, to: &pose)
        case "cock": Brain.applyFinished(e: 0.2, to: &pose)
        case "settle": Brain.applyFinished(e: 1.85, to: &pose)
        case "scrape": Brain.applyFinished(e: 1.2, to: &pose)
        case "fumble": Brain.applyFumble(e: 0.45, to: &pose)
        case "catch": Brain.applyFumble(e: 0.64, to: &pose)
        case "sparks": pose.redSparks = 2; pose.goldSparks = 1
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
            if mood.hasPrefix("land:"), let e = Double(mood.dropFirst(5)) {
                pose.splashAge = e; pose.kneel = min(1, e / 0.12 + 0.3); pose.nearHand = nil
                pose.grip = CGPoint(x: -7, y: -27); pose.swordRot = -0.82; pose.torsoRot = -0.08
                pose.headDY = 2.4; pose.headRot = 0.1; pose.squash = 0.7 * max(0, 1 - e / 0.35)
            }
            else if mood.hasPrefix("rise:"), let age = Double(mood.dropFirst(5)) {
                pose.cocoonAge = age
                pose.reveal = max(0, min(1, (age - 0.55) / 0.9))
            }
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
