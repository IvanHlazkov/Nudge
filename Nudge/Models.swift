import Foundation

enum ReminderKind: String, Codable {
    case general
    case planned
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Every day"
        case .weekdays: return "Every weekday"
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        }
    }

    func next(after date: Date, calendar cal: Calendar = .current) -> Date {
        switch self {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date) ?? date
        case .weekdays:
            var d = cal.date(byAdding: .day, value: 1, to: date) ?? date
            while cal.isDateInWeekend(d) {
                d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        }
    }

    func firstOccurrence(onOrAfter date: Date, calendar cal: Calendar = .current) -> Date {
        guard self == .weekdays, cal.isDateInWeekend(date) else { return date }
        return next(after: date, calendar: cal)
    }
}

struct Reminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var kind: ReminderKind
    var day: Date
    var due: Date?
    var done = false
    var created = Date()
    var exportID: String?
    var repeats: RepeatRule?
    var spawnedNext: Bool?
}

enum LeftTab {
    case general
    case notes
}

final class UIState: ObservableObject {
    static let shared = UIState()
    @Published var showSettings = false
    @Published var leftTab: LeftTab = .general
    @Published var noteMode = false
    @Published var focusToken = 0
    @Published var plannedOffset = 0
}
