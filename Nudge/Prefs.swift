import Foundation
import Combine

enum PanelPosition: String, CaseIterable {
    case desktop
    case onTop
}

enum AlertSound: String, CaseIterable {
    case standard
    case silent
}

final class Prefs: ObservableObject {
    static let shared = Prefs()

    private let defaults = UserDefaults.standard
    var onChange: ((String) -> Void)?

    @Published var morningSummary: Bool { didSet { save(morningSummary, "morningSummary") } }
    @Published var sound: AlertSound { didSet { save(sound.rawValue, "sound") } }
    @Published var showNextInMenuBar: Bool { didSet { save(showNextInMenuBar, "showNextInMenuBar") } }
    @Published var spotDates: Bool { didSet { save(spotDates, "spotDates") } }
    @Published var use24h: Bool { didSet { save(use24h, "use24h") } }
    @Published var position: PanelPosition { didSet { save(position.rawValue, "position") } }
    @Published var opacity: Double { didSet { save(opacity, "opacity") } }
    @Published var hideOnClickAway: Bool { didSet { save(hideOnClickAway, "hideOnClickAway") } }
    @Published var openAtLogin: Bool {
        didSet {
            LoginItem.set(openAtLogin)
            save(openAtLogin, "openAtLogin")
        }
    }
    @Published var sendToReminders: Bool { didSet { save(sendToReminders, "sendToReminders") } }
    @Published var remindersListID: String { didSet { save(remindersListID, "remindersListID") } }
    @Published var lastSent: Date? { didSet { defaults.set(lastSent, forKey: "lastSent") } }

    private init() {
        defaults.register(defaults: [
            "morningSummary": true,
            "sound": AlertSound.standard.rawValue,
            "showNextInMenuBar": true,
            "spotDates": true,
            "use24h": false,
            "position": PanelPosition.desktop.rawValue,
            "opacity": 0.86,
            "hideOnClickAway": true,
            "openAtLogin": true,
            "sendToReminders": false,
            "remindersListID": ""
        ])
        morningSummary = defaults.bool(forKey: "morningSummary")
        sound = AlertSound(rawValue: defaults.string(forKey: "sound") ?? "") ?? .standard
        showNextInMenuBar = defaults.bool(forKey: "showNextInMenuBar")
        spotDates = defaults.bool(forKey: "spotDates")
        use24h = defaults.bool(forKey: "use24h")
        position = PanelPosition(rawValue: defaults.string(forKey: "position") ?? "") ?? .desktop
        opacity = defaults.double(forKey: "opacity")
        hideOnClickAway = defaults.bool(forKey: "hideOnClickAway")
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
