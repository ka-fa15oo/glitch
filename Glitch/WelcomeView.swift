import ServiceManagement
import SwiftUI

/// Shown once, on the first launch: explains the permissions and optional extras before asking for any of them.
struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(Prefs.welcomed) private var welcomed = false
    @AppStorage(Prefs.character) private var character = "glitch"
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var sentinelInstalled = HookSetup.isInstalled

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Glitch").font(.title2.weight(.semibold))
                    Text("A quiet pixel companion for your desktop.").foregroundStyle(.secondary)
                }
            }

            Form {
                Section("Choose your companion") {
                    HStack(spacing: 12) {
                        ForEach(CharacterInfo.all.filter(\.available)) { info in
                            CharacterCard(info: info, selected: character == info.id) { character = info.id }
                        }
                    }
                }
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in setOpenAtLogin(on) }

                LabeledContent {
                    // the permission is granted in System Settings, so poll until it shows up
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        if AXIsProcessTrusted() {
                            Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("Allow access…") { allowAccessibility() }
                        }
                    }
                } label: {
                    Text("Keep out of text fields")
                    Text("Needs Accessibility, so your companion can step aside while you type.")
                }

                LabeledContent {
                    if sentinelInstalled {
                        Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Install…") {
                            HookSetup.askAndInstall()
                            sentinelInstalled = HookSetup.isInstalled
                        }
                    }
                } label: {
                    Text("Watch Claude Code sessions")
                    Text("Optional. Glitch shows you which session is waiting for you.")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Text("Click the eyes in the menu bar for Customize, Sound and Quit.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Start") {
                    welcomed = true
                    dismissWindow(id: "welcome")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear { NSApp.activate() }   // an accessory app's window otherwise opens behind the frontmost app
    }

    /// One selectable character: name and theme; the chosen one gets the accent outline.
    private struct CharacterCard: View {
        let info: CharacterInfo
        let selected: Bool
        let choose: () -> Void

        var body: some View {
            Button(action: choose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name).fontWeight(.semibold)
                    Text(info.theme).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(selected ? 1 : 0.4), in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Login item change failed: \(error)")
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func allowAccessibility() {
        TextFieldGuard.askForPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
