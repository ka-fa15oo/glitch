import AppKit
import ApplicationServices

/// Finds the text box the user is typing in (in any app), so the knight can keep out of it.
/// Needs the Accessibility permission; without it `focusedTextFrame()` simply returns nil.
@MainActor
enum TextFieldGuard {
    private static var awakenedPID: pid_t = 0
    /// Why the last lookup found no text box, for the log; empty when it found one.
    private(set) static var lastProblem = ""

    /// Shows macOS' own "allow Accessibility" prompt if the permission is missing.
    static func askForPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Frame of the focused text input in Cocoa screen coordinates (origin bottom-left), or nil.
    static func focusedTextFrame() -> CGRect? {
        guard AXIsProcessTrusted() else { return miss("not trusted") }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return miss("no other app in front") }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if awakenedPID != app.processIdentifier {
            // Chromium/Electron apps only expose their text fields once an assistive app asks for them
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            awakenedPID = app.processIdentifier
        }
        let name = app.bundleIdentifier ?? "?"
        var focused: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        if result != .success {
            // some apps answer only the system-wide element
            result = AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        }
        guard result == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            awakenedPID = 0   // ask Electron again next time; its renderer may have restarted
            return miss("\(name): no focused element (AX error \(result.rawValue))")
        }
        let element = focused as! AXUIElement   // swiftlint:disable:this force_cast
        guard isTextInput(element) else { return miss("\(name): focused \(describe(element)) is not a text input") }
        guard let frame = frame(of: element) else { return miss("\(name): \(describe(element)) has no frame") }
        // a whole page or editor reported as one field is too big to dodge
        let screen = NSScreen.screens.first?.frame ?? .zero
        guard frame.width * frame.height < screen.width * screen.height * 0.35 else {
            return miss("\(name): \(describe(element)) \(NSStringFromRect(frame)) is too big")
        }
        lastProblem = ""
        return frame
    }

    private static func miss(_ problem: String) -> CGRect? {
        lastProblem = problem
        return nil
    }

    private static func describe(_ element: AXUIElement) -> String {
        var role: CFTypeRef?, subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        return "\(role as? String ?? "-")/\(subrole as? String ?? "-")"
    }

    private static func isTextInput(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let name = role as? String ?? ""
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField"].contains(name) { return true }
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef else { return nil }
        var position = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)   // swiftlint:disable:this force_cast
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)            // swiftlint:disable:this force_cast
        // Accessibility measures from the top-left of the main display; Cocoa from its bottom-left
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: position.x, y: mainHeight - position.y - size.height, width: size.width, height: size.height)
    }
}
