import Foundation

enum ReminderKind: String, Codable {
    case general
    case planned
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
}

final class UIState: ObservableObject {
    static let shared = UIState()
    @Published var showSettings = false
    @Published var focusToken = 0
    @Published var plannedOffset = 0
}
