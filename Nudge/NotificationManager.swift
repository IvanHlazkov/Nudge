import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    weak var store: ReminderStore?
    var onOpen: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let prefs = Prefs.shared
    private let categoryID = "NUDGE_REMINDER"
    private let snoozePrefix = "snooze-"

    func setUp() {
        center.delegate = self
        updateCategories()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { NSLog("Nudge: notification permission error: \(error.localizedDescription)") }
        }
    }

    private func updateCategories() {
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze \(snoozeLabel)", options: [])
        let done = UNNotificationAction(identifier: "DONE", title: "Mark done", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [snooze, done],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    private var snoozeLabel: String {
        prefs.snoozeMinutes >= 60 ? "1 h" : "\(prefs.snoozeMinutes) min"
    }

    func reschedule() {
        guard let store else { return }
        updateCategories()

        let items = store.items
        let playSound = prefs.sound == .standard
        let summaryOn = prefs.morningSummary
        let use24h = prefs.use24h
        let categoryID = self.categoryID
        let snoozePrefix = self.snoozePrefix

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let old = requests.map(\.identifier).filter { !$0.hasPrefix(snoozePrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: old)

            let now = Date()
            let cal = Calendar.current

            let upcoming = items
                .filter { $0.kind == .planned && !$0.done && ($0.due ?? .distantPast) > now }
                .sorted { ($0.due ?? now) < ($1.due ?? now) }
                .prefix(60)

            for r in upcoming {
                guard let due = r.due else { continue }
                let content = UNMutableNotificationContent()
                content.title = r.title
                content.body = "Due at \(Fmt.time(due, use24h: use24h))"
                content.categoryIdentifier = categoryID
                content.userInfo = ["id": r.id.uuidString]
                content.sound = playSound ? .default : nil
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: due)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                self.center.add(UNNotificationRequest(identifier: r.id.uuidString, content: content, trigger: trigger))
            }

            guard summaryOn else { return }
            guard var next = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) else { return }
            if next <= now, let tomorrow = cal.date(byAdding: .day, value: 1, to: next) { next = tomorrow }
            let general = items.filter { $0.kind == .general && !$0.done }
            guard !general.isEmpty else { return }

            let content = UNMutableNotificationContent()
            content.title = "Good morning · \(general.count) reminder\(general.count == 1 ? "" : "s") to do"
            content.body = general.prefix(4).map(\.title).joined(separator: ", ")
            content.sound = playSound ? .default : nil
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            self.center.add(UNNotificationRequest(identifier: "summary", content: content, trigger: trigger))
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        let idString = request.content.userInfo["id"] as? String
        let id = idString.flatMap(UUID.init(uuidString:))

        switch response.actionIdentifier {
        case "DONE":
            if let id {
                DispatchQueue.main.async { [weak self] in self?.store?.setDone(id, true) }
            }
        case "SNOOZE":
            if let content = request.content.mutableCopy() as? UNMutableNotificationContent {
                let seconds = TimeInterval(max(1, prefs.snoozeMinutes) * 60)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                center.add(UNNotificationRequest(identifier: snoozePrefix + UUID().uuidString,
                                                 content: content, trigger: trigger))
            }
        default:
            onOpen?()
        }
        completionHandler()
    }
}
