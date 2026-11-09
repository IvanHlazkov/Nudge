import Foundation
import EventKit
import AppKit

struct ReminderList: Identifiable, Hashable {
    let id: String
    let title: String
}

private struct RemoteItem {
    let id: String
    let title: String
    let due: Date?
    let done: Bool
}

final class RemindersExporter {
    static let shared = RemindersExporter()

    weak var store: ReminderStore?
    private let eventStore = EKEventStore()
    private let prefs = Prefs.shared
    private var observer: NSObjectProtocol?
    private var pullScheduled = false
    private var pulling = false
    private var localGeneration = 0

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    var accessDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return status == .denied || status == .restricted
    }

    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        if hasAccess { completion(true); return }
        eventStore.requestFullAccessToReminders { [weak self] granted, error in
            if let error { NSLog("Nudge: Reminders access error: \(error.localizedDescription)") }
            DispatchQueue.main.async {
                if granted { self?.eventStore.refreshSourcesIfNecessary() }
                completion(granted)
            }
        }
    }

    func lists() -> [ReminderList] {
        guard hasAccess else { return [] }
        return eventStore.calendars(for: .reminder)
            .filter { $0.allowsContentModifications && $0.title != "Nudge" }
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func startWatching() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
                                                          object: eventStore,
                                                          queue: .main) { [weak self] _ in
            self?.schedulePull()
        }
        schedulePull()
    }

    func schedulePull() {
        guard !pullScheduled else { return }
        pullScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.pullScheduled = false
            self.pull()
        }
    }

    private func targetCalendar(create: Bool) -> EKCalendar? {
        if !prefs.remindersListID.isEmpty,
           let chosen = eventStore.calendar(withIdentifier: prefs.remindersListID) {
            return chosen
        }
        if let existing = eventStore.calendars(for: .reminder).first(where: { $0.title == "Nudge" }) {
            return existing
        }
        guard create else { return nil }
        let list = EKCalendar(for: .reminder, eventStore: eventStore)
        list.title = "Nudge"
        list.cgColor = NSColor(red: 1.0, green: 0.608, blue: 0.361, alpha: 1).cgColor
        list.source = eventStore.defaultCalendarForNewReminders()?.source
            ?? eventStore.sources.first { $0.sourceType == .local }
        do {
            try eventStore.saveCalendar(list, commit: true)
            return list
        } catch {
            NSLog("Nudge: could not create Nudge list: \(error.localizedDescription)")
            return eventStore.defaultCalendarForNewReminders()
        }
    }

    func export(_ reminder: Reminder) {
        guard prefs.sendToReminders, hasAccess else { return }
        localGeneration += 1
        let calendar = targetCalendar(create: true)

        let target: EKReminder
        if let exportID = reminder.exportID,
           let existing = eventStore.calendarItem(withIdentifier: exportID) as? EKReminder {
            let sameList = calendar.map { existing.calendar.calendarIdentifier == $0.calendarIdentifier } ?? true
            if sameList,
               existing.title == reminder.title,
               existing.isCompleted == reminder.done,
               Self.sameMinute(Self.date(from: existing.dueDateComponents), reminder.due) {
                return
            }
            target = existing
            if let calendar, !sameList { target.calendar = calendar }
        } else {
            guard let calendar else { return }
            target = EKReminder(eventStore: eventStore)
            target.calendar = calendar
            target.notes = "From Nudge"
        }

        target.title = reminder.title
        target.isCompleted = reminder.done
        if let due = reminder.due {
            target.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        } else {
            target.dueDateComponents = nil
        }

        do {
            try eventStore.save(target, commit: true)
            if reminder.exportID != target.calendarItemIdentifier {
                store?.setExportID(reminder.id, target.calendarItemIdentifier)
            }
            prefs.lastSent = Date()
        } catch {
            NSLog("Nudge: could not send to Reminders: \(error.localizedDescription)")
        }
    }

    func remove(_ reminder: Reminder) {
        guard prefs.sendToReminders, hasAccess,
              let exportID = reminder.exportID,
              let item = eventStore.calendarItem(withIdentifier: exportID) as? EKReminder else { return }
        localGeneration += 1
        do {
            try eventStore.remove(item, commit: true)
        } catch {
            NSLog("Nudge: could not remove from Reminders: \(error.localizedDescription)")
        }
    }

    func exportAll() {
        guard prefs.sendToReminders, hasAccess, let store else { return }
        for reminder in store.items {
            export(reminder)
        }
        schedulePull()
    }

    private func pull() {
        guard prefs.sendToReminders, hasAccess, !pulling,
              let calendar = targetCalendar(create: false) else { return }
        pulling = true
        let generation = localGeneration
        let predicate = eventStore.predicateForReminders(in: [calendar])
        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            let items = (reminders ?? []).map { r in
                RemoteItem(id: r.calendarItemIdentifier,
                           title: (r.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                           due: Self.date(from: r.dueDateComponents),
                           done: r.isCompleted)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.pulling = false
                if generation != self.localGeneration {
                    self.schedulePull()
                    return
                }
                self.merge(items)
            }
        }
    }

    private func merge(_ remote: [RemoteItem]) {
        guard let store else { return }
        var unmatched = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var missing: [Reminder] = []

        store.duringSync {
            for local in store.items {
                guard let link = local.exportID else { continue }
                if let r = unmatched.removeValue(forKey: link) {
                    apply(r, to: local, in: store)
                } else {
                    missing.append(local)
                }
            }

            let looksOffline = remote.isEmpty && missing.count > 2
            for local in missing {
                if let match = unmatched.values.first(where: { $0.title == local.title && Self.sameMinute($0.due, local.due) }) {
                    unmatched.removeValue(forKey: match.id)
                    store.setExportID(local.id, match.id)
                    apply(match, to: local, in: store)
                } else if !looksOffline,
                          let link = local.exportID,
                          eventStore.calendarItem(withIdentifier: link) == nil {
                    store.delete(local.id)
                }
            }

            for r in unmatched.values where !r.done && !r.title.isEmpty {
                store.add(title: r.title,
                          kind: r.due == nil ? .general : .planned,
                          day: r.due ?? store.today,
                          due: r.due,
                          exportID: r.id)
            }
        }

        for r in store.items where r.exportID == nil && !r.done {
            export(r)
        }
        prefs.lastSent = Date()
    }

    private func apply(_ r: RemoteItem, to local: Reminder, in store: ReminderStore) {
        let title = r.title.isEmpty ? local.title : r.title
        guard title != local.title || r.done != local.done || !Self.sameMinute(r.due, local.due) else { return }
        store.applyRemote(local.id, title: title, due: r.due, done: r.done)
    }

    private static func date(from components: DateComponents?) -> Date? {
        guard let c = components, let year = c.year, let month = c.month, let day = c.day else { return nil }
        var parts = DateComponents()
        parts.timeZone = c.timeZone
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = c.hour ?? 9
        parts.minute = c.hour == nil ? 0 : (c.minute ?? 0)
        return Calendar.current.date(from: parts)
    }

    private static func sameMinute(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil):
            return true
        case let (x?, y?):
            return floor(x.timeIntervalSince1970 / 60) == floor(y.timeIntervalSince1970 / 60)
        default:
            return false
        }
    }
}
