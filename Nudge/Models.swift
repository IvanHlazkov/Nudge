import Foundation

enum ReminderKind: String, Codable {
    case general   // no date and time
    case planned   // has a date and time
}

struct Reminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var kind: ReminderKind
    /// Start of the day this reminder is shown on.
    var day: Date
    /// Exact date and time (planned reminders only).
    var due: Date?
    var done = false
    var created = Date()
    /// Identifier of the copy in Apple Reminders, if it was sent there.
    var exportID: String?
}

final class UIState: ObservableObject {
    static let shared = UIState()
    @Published var showSettings = false
    @Published var focusToken = 0
    @Published var generalOffset = 0
    @Published var plannedOffset = 0
}
