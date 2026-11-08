import Foundation
import EventKit
import AppKit

struct ReminderList: Identifiable, Hashable {
    let id: String
    let title: String
}

/// One-way copy: Nudge → Apple Reminders. Nothing is ever read back.
/// Adding, ticking off, editing or deleting in Nudge updates the copy in Apple Reminders.
final class RemindersExporter {
    static let shared = RemindersExporter()

    weak var store: ReminderStore?
    private let eventStore = EKEventStore()
    private let prefs = Prefs.shared

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

    /// The user's Reminders lists, minus Nudge's own list (shown separately).
    func lists() -> [ReminderList] {
        guard hasAccess else { return [] }
        return eventStore.calendars(for: .reminder)
            .filter { $0.allowsContentModifications && $0.title != "Nudge" }
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func targetCalendar() -> EKCalendar? {
        if !prefs.remindersListID.isEmpty,
           let chosen = eventStore.calendar(withIdentifier: prefs.remindersListID) {
            return chosen
        }
        if let existing = eventStore.calendars(for: .reminder).first(where: { $0.title == "Nudge" }) {
            return existing
        }
        // Create a "Nudge" list in the same account as the default list (usually iCloud).
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

        let target: EKReminder
        if let exportID = reminder.exportID,
           let existing = eventStore.calendarItem(withIdentifier: exportID) as? EKReminder {
            target = existing
            // The chosen list changed in Settings: move the copy.
            if let calendar = targetCalendar(), existing.calendar.calendarIdentifier != calendar.calendarIdentifier {
                target.calendar = calendar
            }
        } else {
            guard let calendar = targetCalendar() else { return }
            target = EKReminder(eventStore: eventStore)
            target.calendar = calendar
        }

        target.title = reminder.title
        target.isCompleted = reminder.done
        if let due = reminder.due {
            target.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        } else {
            target.dueDateComponents = nil
        }
        target.notes = reminder.kind == .general ? "From Nudge · General" : "From Nudge · Planned"

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
        do {
            try eventStore.remove(item, commit: true)
        } catch {
            NSLog("Nudge: could not remove from Reminders: \(error.localizedDescription)")
        }
    }

    /// "Send all now": copies every Nudge reminder into the chosen list.
    func exportAll() {
        guard prefs.sendToReminders, hasAccess, let store else { return }
        for reminder in store.items {
            export(reminder)
        }
    }
}
