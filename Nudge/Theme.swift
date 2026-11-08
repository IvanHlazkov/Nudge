import SwiftUI
import AppKit

enum Theme {
    static let text = Color(white: 0.95)
    static let secondary = Color(white: 0.78)
    static let card = Color.white.opacity(0.09)
    static let field = Color.white.opacity(0.10)
    static let accent = Color(red: 1.0, green: 0.608, blue: 0.361)        // #FF9B5C
    static let dateText = Color(red: 0.867, green: 0.843, blue: 1.0)      // #DDD7FF
    static let dateBackground = Color(red: 0.59, green: 0.51, blue: 1.0).opacity(0.25)
    static let green = Color(red: 0.435, green: 0.878, blue: 0.627)       // #6FE0A0

    static let nsDateText = NSColor(red: 0.867, green: 0.843, blue: 1.0, alpha: 1)
    static let nsDateBackground = NSColor(red: 0.59, green: 0.51, blue: 1.0, alpha: 0.30)
    static let nsPlaceholder = NSColor(white: 0.77, alpha: 1)
}

enum Fmt {
    private static let gb = Locale(identifier: "en_GB")

    static func time(_ date: Date, use24h: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if use24h {
            f.dateFormat = "HH:mm"
        } else {
            f.dateFormat = Calendar.current.component(.minute, from: date) == 0 ? "h a" : "h:mm a"
        }
        return f.string(from: date)
    }

    static func dayLabel(_ date: Date) -> String {
        let c = Calendar.current
        if c.isDateInToday(date) { return "Today" }
        if c.isDateInYesterday(date) { return "Yesterday" }
        if c.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.locale = gb
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = gb
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased() + " · " + String(Calendar.current.component(.year, from: date))
    }
}
