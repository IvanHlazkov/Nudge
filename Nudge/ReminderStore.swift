import Foundation
import Combine

final class ReminderStore: ObservableObject {
    enum Change {
        case added(Reminder)
        case updated(Reminder)
        case removed(Reminder)
    }

    @Published private(set) var items: [Reminder] = []
    @Published private(set) var today: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var now = Date()

    private(set) var syncing = false

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

    func refreshToday() {
        let t = cal.startOfDay(for: Date())
        if t != today { today = t }
    }

    func tick() {
        now = Date()
        refreshToday()
    }

    func nextPlanned(after date: Date) -> Reminder? {
        items
            .filter { $0.kind == .planned && !$0.done && ($0.due ?? .distantPast) >= date }
            .min { ($0.due ?? date) < ($1.due ?? date) }
    }

    func duringSync(_ body: () -> Void) {
        syncing = true
        body()
        syncing = false
    }

    func date(offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: today) ?? today
    }

    func offset(of date: Date) -> Int {
        cal.dateComponents([.day], from: today, to: cal.startOfDay(for: date)).day ?? 0
    }

    func list(_ kind: ReminderKind, on day: Date) -> [Reminder] {
        items
            .filter { $0.kind == kind && cal.isDate($0.day, inSameDayAs: day) }
            .sorted { a, b in
                if a.done != b.done { return !a.done }
                return (a.due ?? a.created) < (b.due ?? b.created)
            }
    }

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

    @discardableResult
    func add(title: String, kind: ReminderKind, day: Date, due: Date?,
             repeats: RepeatRule? = nil, exportID: String? = nil) -> Reminder {
        var r = Reminder(title: title, kind: kind, day: cal.startOfDay(for: day), due: due)
        r.repeats = due == nil ? nil : repeats
        r.exportID = exportID
        items.append(r)
        persist()
        onChange?(.added(r))
        return r
    }

    @discardableResult
    func quickAdd(_ text: String, spotDates: Bool, generalDay: Date) -> Reminder? {
        let parsed = DateParser.parse(text, enabled: spotDates)
        var title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !title.isEmpty else { return nil }
        if let due = parsed.due {
            return add(title: title, kind: .planned, day: due, due: due, repeats: parsed.repeats)
        }
        return add(title: title, kind: .general, day: generalDay, due: nil)
    }

    func toggle(_ id: UUID) {
        guard let r = reminder(id) else { return }
        setDone(id, !r.done)
    }

    func setDone(_ id: UUID, _ done: Bool) {
        update(id) { $0.done = done }
        if done { spawnNextIfRepeating(id) }
    }

    func snooze(_ id: UUID, until date: Date) {
        let cal = self.cal
        let date = cal.date(from: cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)) ?? date
        update(id) { r in
            r.kind = .planned
            r.due = date
            r.day = cal.startOfDay(for: date)
            r.done = false
        }
    }

    func applyRemote(_ id: UUID, title: String, due: Date?, done: Bool) {
        let cal = self.cal
        let today = self.today
        let wasDone = reminder(id)?.done ?? false
        update(id) { r in
            r.title = title
            r.done = done
            if let due {
                r.kind = .planned
                r.due = due
                r.day = cal.startOfDay(for: due)
            } else if r.kind == .planned {
                r.kind = .general
                r.due = nil
                r.day = today
                r.repeats = nil
            }
        }
        if done && !wasDone { spawnNextIfRepeating(id) }
    }

    private func spawnNextIfRepeating(_ id: UUID) {
        guard let r = reminder(id), r.done, r.spawnedNext != true,
              let rule = r.repeats, let due = r.due else { return }
        var next = rule.next(after: due, calendar: cal)
        let now = Date()
        while next <= now, next > due {
            next = rule.next(after: next, calendar: cal)
        }
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].spawnedNext = true
        persist()
        add(title: r.title, kind: .planned, day: next, due: next, repeats: rule)
    }

    func move(_ id: UUID, byDays days: Int) {
        let cal = self.cal
        update(id) { r in
            r.day = cal.date(byAdding: .day, value: days, to: r.day) ?? r.day
            if let due = r.due { r.due = cal.date(byAdding: .day, value: days, to: due) }
        }
    }

    func edit(_ id: UUID, title: String, due: Date?, repeats: RepeatRule? = nil) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let cal = self.cal
        let today = self.today
        let due = due.flatMap { cal.date(from: cal.dateComponents([.year, .month, .day, .hour, .minute], from: $0)) }
        update(id) { r in
            r.title = title
            if let due {
                r.kind = .planned
                r.due = due
                r.day = cal.startOfDay(for: due)
                if r.repeats != repeats { r.spawnedNext = nil }
                r.repeats = repeats
            } else {
                if r.kind == .planned { r.day = today }
                r.kind = .general
                r.due = nil
                r.repeats = nil
            }
        }
    }

    func delete(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: i)
        persist()
        onChange?(.removed(removed))
    }

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
