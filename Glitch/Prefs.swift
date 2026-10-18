import Foundation

/// UserDefaults keys for everything the Customize and Sound tabs change; views bind with @AppStorage.
enum Prefs {
    static let character = "character"
    static let scale = "scale"
    static let hue = "hue"
    static let liveliness = "liveliness"
    static let gravity = "gravity"
    static let hideInFullscreen = "hideInFullscreen"
    static let volume = "volume"
    static let muted = "muted"
    static let settingsTab = "settingsTab"
    static let welcomed = "welcomed"

    static func register() {
        var defaults: [String: Any] = [
            character: "glitch", scale: 2.0, hue: 0.0, liveliness: 1, gravity: true,
            hideInFullscreen: true, volume: 0.5, muted: false, settingsTab: "customize", welcomed: false,
        ]
        for group in SoundGroup.allCases { defaults[group.key] = true }
        UserDefaults.standard.register(defaults: defaults)
    }

    static var d: UserDefaults { .standard }

    /// Reset leaves the character alone: changing it is an animated switch, done with Apply.
    static let customizeKeys = [scale, hue, liveliness, gravity, hideInFullscreen]

    /// Asks the app to switch characters: the current one says goodbye, then the new one makes its entrance.
    static let switchCharacter = Notification.Name("switchCharacter")
    static func requestCharacter(_ id: String) { NotificationCenter.default.post(name: switchCharacter, object: id) }
    static var soundKeys: [String] { [volume, muted] + SoundGroup.allCases.map(\.key) }

    /// Back to the registered defaults: removing a key makes UserDefaults fall back to them.
    static func reset(_ keys: [String]) {
        keys.forEach(d.removeObject(forKey:))
    }
}

/// Sound tab toggles: each switches a group of effects on or off.
enum SoundGroup: String, CaseIterable {
    case arrival, reactions, movement, glitch, sword, spells

    var key: String { "sound.\(rawValue)" }

    var title: String {
        switch self {
        case .arrival: "Wake and goodbye"
        case .reactions: "Reactions (click, drag)"
        case .movement: "Steps and falls"
        case .glitch: "Glitch effect"
        case .sword: "Sword"
        case .spells: "Wizzy's spells"
        }
    }

    init(_ effect: SoundEffect) {
        switch effect {
        case .wake, .farewell, .sad: self = .arrival
        case .angry, .happy, .surprised: self = .reactions
        case .tick, .thud: self = .movement
        case .glitch: self = .glitch
        case .swish, .clang, .scrape: self = .sword
        case .chime, .nudge, .rune, .orb, .fizzle, .starGlide, .hole, .constellation, .dustOut, .dustIn, .shootingStar:
            self = .spells
        }
    }

    static func allows(_ effect: SoundEffect) -> Bool { Prefs.d.bool(forKey: SoundGroup(effect).key) }
}

/// The characters on the picker. Locked slots wait for the user's design approval.
struct CharacterInfo: Identifiable {
    let id: String
    let name: String
    let theme: String
    let available: Bool

    static let all = [
        CharacterInfo(id: "glitch", name: "Vorn", theme: "Cursed digital knight", available: true),
        CharacterInfo(id: Mage.id, name: "Wizzy", theme: "Cosmic mage", available: true),
        CharacterInfo(id: "slot3", name: "Character 3", theme: "Coming soon", available: false),
    ]
}

/// Hue themes for the Customize tab; rotation is applied to the whole character.
struct ColorTheme: Identifiable {
    let name: String
    let hue: Double
    var id: Double { hue }

    static let all = [
        ColorTheme(name: "Crimson", hue: 0),
        ColorTheme(name: "Amber", hue: 35),
        ColorTheme(name: "Emerald", hue: 140),
        ColorTheme(name: "Ice", hue: 200),
    ]
}
