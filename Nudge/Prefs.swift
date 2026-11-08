import Foundation
import Combine

enum PanelPosition: String, CaseIterable {
    case desktop   // sits on the desktop, behind other windows
    case onTop     // floats above every window
}

enum AlertSound: String, CaseIterable {
    case standard
    case silent
}

/// All settings, saved in UserDefaults. `onChange` reports the key that changed.
final class Prefs: ObservableObject {
    static let shared = Prefs()

    private let defaults = UserDefaults.standard
    var onChange: ((String) -> Void)?

    @Published var morningSummary: Bool { didSet { save(morningSummary, "morningSummary") } }
    @Published var sound: AlertSound { didSet { save(sound.rawValue, "sound") } }
    @Published var snoozeMinutes: Int { didSet { save(snoozeMinutes, "snoozeMinutes") } }
    @Published var spotDates: Bool { didSet { save(spotDates, "spotDates") } }
    @Published var use24h: Bool { didSet { save(use24h, "use24h") } }
    @Published var position: PanelPosition { didSet { save(position.rawValue, "position") } }
    @Published var opacity: Double { didSet { save(opacity, "opacity") } }
    @Published var hideOnDesktopClick: Bool { didSet { save(hideOnDesktopClick, "hideOnDesktopClick") } }
    @Published var openAtLogin: Bool {
        didSet {
            LoginItem.set(openAtLogin)
            save(openAtLogin, "openAtLogin")
        }
    }
    @Published var sendToReminders: Bool { didSet { save(sendToReminders, "sendToReminders") } }
    /// Empty string = Nudge's own "Nudge" list.
    @Published var remindersListID: String { didSet { save(remindersListID, "remindersListID") } }
    @Published var lastSent: Date? { didSet { defaults.set(lastSent, forKey: "lastSent") } }

    private init() {
        defaults.register(defaults: [
            "morningSummary": true,
            "sound": AlertSound.standard.rawValue,
            "snoozeMinutes": 10,
            "spotDates": true,
            "use24h": false,
            "position": PanelPosition.desktop.rawValue,
            "opacity": 0.86,
            "hideOnDesktopClick": true,
            "openAtLogin": true,
            "sendToReminders": false,
            "remindersListID": ""
        ])
        morningSummary = defaults.bool(forKey: "morningSummary")
        sound = AlertSound(rawValue: defaults.string(forKey: "sound") ?? "") ?? .standard
        snoozeMinutes = defaults.integer(forKey: "snoozeMinutes")
        spotDates = defaults.bool(forKey: "spotDates")
        use24h = defaults.bool(forKey: "use24h")
        position = PanelPosition(rawValue: defaults.string(forKey: "position") ?? "") ?? .desktop
        opacity = defaults.double(forKey: "opacity")
        hideOnDesktopClick = defaults.bool(forKey: "hideOnDesktopClick")
        openAtLogin = defaults.bool(forKey: "openAtLogin")
        sendToReminders = defaults.bool(forKey: "sendToReminders")
        remindersListID = defaults.string(forKey: "remindersListID") ?? ""
        lastSent = defaults.object(forKey: "lastSent") as? Date
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?(key)
    }
}
