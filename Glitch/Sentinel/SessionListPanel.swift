import AppKit
import SwiftUI

/// The small dark list beside the knight: one row per session that is waiting or done.
@MainActor
final class SessionListPanel {
    private var panel: NSPanel?

    func show(_ rows: [SessionStatus], names: @escaping (String) -> String, titles: @escaping (String) -> String,
              beside frame: CGRect) {
        let view = SessionListView(rows: rows, names: names, titles: titles, now: Date())
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        let size = host.fittingSize
        let screen = (NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main)?.visibleFrame ?? .zero
        // right of the knight, or left when there is no room; level with its head
        var x = frame.maxX - 30
        if x + size.width > screen.maxX { x = frame.minX + 30 - size.width }
        let y = min(max(frame.maxY - size.height - 40, screen.minY), screen.maxY - size.height)
        panel.setFrame(CGRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

private struct SessionListView: View {
    let rows: [SessionStatus]
    let names: (String) -> String
    let titles: (String) -> String
    let now: Date

    private static let crimson = Color(red: 0.72, green: 0.1, blue: 0.14)
    private static let gold = Color(red: 0.85, green: 0.68, blue: 0.3)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.id) { row in
                HStack(spacing: 6) {
                    Text(mark(row.state)).foregroundStyle(color(row.state))
                    Text("\(names(row.cwd)) · \(titles(row.id))").foregroundStyle(.white.opacity(0.92))
                    Text("— \(label(row.state)) · \(age(row.since))").foregroundStyle(.white.opacity(0.55))
                }
            }
            if let first = rows.first {
                Text("— tıkla: \(titles(first.id)) açılır")
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 2)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 14 / 255, green: 12 / 255, blue: 14 / 255).opacity(0.92))
        .overlay(Rectangle().stroke(Self.crimson, lineWidth: 1))
        .fixedSize()
    }

    private func mark(_ state: SessionState) -> String {
        switch state {
        case .permission, .question: "⚔"
        case .finished: "◆"
        case .error: "✕"
        }
    }

    private func color(_ state: SessionState) -> Color { state == .finished ? Self.gold : Self.crimson }

    private func label(_ state: SessionState) -> String {
        switch state {
        case .permission: "izin bekliyor"
        case .question: "cevap bekliyor"
        case .finished: "bitti"
        case .error: "hata"
        }
    }

    private func age(_ since: Date) -> String {
        let minutes = Int(now.timeIntervalSince(since) / 60)
        if minutes < 1 { return "az önce" }
        if minutes < 60 { return "\(minutes) dk" }
        return "\(minutes / 60) sa"
    }
}
