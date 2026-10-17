import SwiftUI

/// The Customize and Sound window opened from the menu bar.
struct SettingsView: View {
    @AppStorage(Prefs.settingsTab) private var tab = "customize"

    var body: some View {
        TabView(selection: $tab) {
            CustomizeTab()
                .tabItem { Label("Customize", systemImage: "paintbrush") }
                .tag("customize")
            SoundTab()
                .tabItem { Label("Ses", systemImage: "speaker.wave.2") }
                .tag("sound")
        }
        .frame(width: 620, height: 580)
    }
}

private struct CustomizeTab: View {
    @AppStorage(Prefs.character) private var character = "glitch"
    @AppStorage(Prefs.scale) private var scale = 2.0
    @AppStorage(Prefs.hue) private var hue = 0.0
    @AppStorage(Prefs.liveliness) private var liveliness = 1
    @AppStorage(Prefs.gravity) private var gravity = true
    @AppStorage(Prefs.hideInFullscreen) private var hideInFullscreen = true

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // live preview drawn back at the default size so the window never resizes
            RobotView()
                .hueRotation(.degrees(hue))
                .scaleEffect(2 / scale)
                .frame(width: 230, height: 255)
                .clipped()
                .background(.black.opacity(0.85), in: .rect(cornerRadius: 10))
                .accessibilityLabel("Karakter önizlemesi")

            Form {
                Section("Karakter") {
                    ForEach(CharacterInfo.all) { info in
                        Button {
                            character = info.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(info.name).fontWeight(.medium)
                                    Text(info.theme).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if character == info.id { Image(systemName: "checkmark") }
                                if !info.available { Image(systemName: "lock") }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(!info.available)
                    }
                }
                Section("Görünüm") {
                    Picker("Renk", selection: $hue) {
                        ForEach(ColorTheme.all) { Text($0.name).tag($0.hue) }
                    }
                    Picker("Boyut", selection: $scale) {
                        Text("Küçük").tag(1.0)
                        Text("Orta").tag(2.0)
                        Text("Büyük").tag(3.0)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Davranış") {
                    Picker("Hareketlilik", selection: $liveliness) {
                        Text("Sakin").tag(0)
                        Text("Normal").tag(1)
                        Text("Hareketli").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Yer çekimi", isOn: $gravity)
                    Toggle("Tam ekranda gizlen", isOn: $hideInFullscreen)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
}

private struct SoundTab: View {
    @AppStorage(Prefs.volume) private var volume = 0.5
    @AppStorage(Prefs.muted) private var muted = false

    var body: some View {
        Form {
            Section {
                Toggle("Sessiz", isOn: $muted)
                LabeledContent("Ses seviyesi") {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $volume, in: 0 ... 1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
                .disabled(muted)
            }
            Section("Olay sesleri") {
                ForEach(SoundGroup.allCases, id: \.self) { group in
                    SoundGroupToggle(group: group)
                }
            }
            .disabled(muted)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct SoundGroupToggle: View {
    let group: SoundGroup
    @AppStorage private var on: Bool

    init(group: SoundGroup) {
        self.group = group
        _on = AppStorage(wrappedValue: true, group.key)
    }

    var body: some View {
        Toggle(group.title, isOn: $on)
    }
}
