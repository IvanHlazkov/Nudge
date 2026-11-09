import Foundation
import Combine

/// Keeps every reminder and saves them to ~/Library/Application Support/Nudge/reminders.json
/// (inside the app's sandbox container).
final class ReminderStore: ObservableObject {
    enum Change {
        case added(Reminder)
        case updated(Reminder)
        case removed(Reminder)
    }

    @Published private(set) var items: [Reminder] = []
    @Published private(set) var today: Date = Calendar.current.startOfDay(for: Date())

    var onChange: ((Change) -> Void)?

    private let fileURL: URL
    private let cal = Calendar.current

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Nudge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("reminders.json")
        load()
    }

    // MARK: Days

    func refreshToday() {
        let t = cal.startOfDay(for: Date())
        if t != today { today = t }
    }

    func date(offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: today) ?? today
    }

    func offset(of date: Date) -> Int {
        cal.dateComponents([.day], from: today, to: cal.startOfDay(for: date)).day ?? 0
    }

    // MARK: Reading

    func list(_ kind: ReminderKind, on day: Date) -> [Reminder] {
        items
            .filter { $0.kind == kind && cal.isDate($0.day, inSameDayAs: day) }
            .sorted { a, b in
                if a.done != b.done { return !a.done }
                return (a.due ?? a.created) < (b.due ?? b.created)
            }
    }

    /// Every General reminder. They have no date, so they're shown together:
    /// open ones first, then in the order they were added.
    func generalList() -> [Reminder] {
        items
            .filter { $0.kind == .general }
            .sorted { a, b in
                if a.done != b.done { return !a.done }
                return a.created < b.created
            }
    }

    func hasOpen(_ kind: ReminderKind, on day: Date) -> Bool {
        items.contains { $0.kind == kind && !$0.done && cal.isDate($0.day, inSameDayAs: day) }
    }

    func reminder(_ id: UUID) -> Reminder? {
        items.first { $0.id == id }
    }

    // MARK: Writing

    @discardableResult
    func add(title: String, kind: ReminderKind, day: Date, due: Date?) -> Reminder {
        let r = Reminder(title: title, kind: kind, day: cal.startOfDay(for: day), due: due)
        items.append(r)
        persist()
        onChange?(.added(r))
        return r
    }

    /// Adds whatever was typed in a quick-add field. Text with a date/time becomes Planned.
    @discardableResult
    func quickAdd(_ text: String, spotDates: Bool, generalDay: Date) -> Reminder? {
        let parsed = DateParser.parse(text, enabled: spotDates)
        var title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !title.isEmpty else { return nil }
        if let due = parsed.due {
            return add(title: title, kind: .planned, day: due, due: due)
        }
        return add(title: title, kind: .general, day: generalDay, due: nil)
    }

    func toggle(_ id: UUID) {
        update(id) { $0.done.toggle() }
    }

    func setDone(_ id: UUID, _ done: Bool) {
        update(id) { $0.done = done }
    }

    func move(_ id: UUID, byDays days: Int) {
        let cal = self.cal
        update(id) { r in
            r.day = cal.date(byAdding: .day, value: days, to: r.day) ?? r.day
            if let due = r.due { r.due = cal.date(byAdding: .day, value: days, to: due) }
        }
    }

    /// Changes the text and/or the date and time. A date and time makes it Planned; none makes it General.
    func edit(_ id: UUID, title: String, due: Date?) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let cal = self.cal
        let today = self.today
        // Drop seconds so notifications fire right on the minute.
        let due = due.flatMap { cal.date(from: cal.dateComponents([.year, .month, .day, .hour, .minute], from: $0)) }
        update(id) { r in
            r.title = title
            if let due {
                r.kind = .planned
                r.due = due
                r.day = cal.startOfDay(for: due)
            } else {
                if r.kind == .planned { r.day = today }
                r.kind = .general
                r.due = nil
            }
        }
    }

    func delete(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: i)
        persist()
        onChange?(.removed(removed))
    }

    /// Records the Apple Reminders copy. Does not fire onChange (avoids an export loop).
    func setExportID(_ id: UUID, _ exportID: String?) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].exportID = exportID
        persist()
    }

    private func update(_ id: UUID, _ change: (inout Reminder) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        persist()
        onChange?(.updated(items[i]))
    }

    // MARK: Disk

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([Reminder].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
