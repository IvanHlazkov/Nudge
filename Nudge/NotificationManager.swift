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
        let done = UNNotificationAction(identifier: "DONE", title: "Mark done", options: [])
        let tenMinutes = UNNotificationAction(identifier: "SNOOZE_10", title: "Snooze 10 min", options: [])
        let oneHour = UNNotificationAction(identifier: "SNOOZE_60", title: "Snooze 1 hour", options: [])
        let tomorrow = UNNotificationAction(identifier: "SNOOZE_TOMORROW", title: "Tomorrow", options: [])
        let category = UNNotificationCategory(identifier: categoryID,
                                              actions: [done, tenMinutes, oneHour, tomorrow],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    private func snoozeDate(for action: String, due: Date?) -> Date? {
        let now = Date()
        let cal = Calendar.current
        switch action {
        case "SNOOZE_10":
            return now.addingTimeInterval(10 * 60)
        case "SNOOZE_60":
            return now.addingTimeInterval(60 * 60)
        case "SNOOZE_TOMORROW":
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else { return nil }
            let hour = due.map { cal.component(.hour, from: $0) } ?? 9
            let minute = due.map { cal.component(.minute, from: $0) } ?? 0
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow)
        default:
            return nil
        }
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
        case "SNOOZE_10", "SNOOZE_60", "SNOOZE_TOMORROW":
            let action = response.actionIdentifier
            if let id {
                DispatchQueue.main.async { [weak self] in
                    guard let self, let store = self.store else { return }
                    let due = store.reminder(id)?.due
                    if let date = self.snoozeDate(for: action, due: due) {
                        store.snooze(id, until: date)
                    }
                }
            }
        default:
            onOpen?()
        }
        completionHandler()
    }
}
