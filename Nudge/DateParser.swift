import Foundation

struct ParsedInput {
    var title: String
    var due: Date?
    var range: NSRange?
    var repeats: RepeatRule?
}

enum DateParser {
    private static let options: NSRegularExpression.Options = [.caseInsensitive]

    private static let dayRegex = try! NSRegularExpression(
        pattern: #"\b(?:(?:on|next)\s+)?(today|tonight|tomorrow|tommorow|tmrw|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b|\b(?:on|next)\s+(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b"#,
        options: options)

    private static let timeRegex = try! NSRegularExpression(
        pattern: #"\b(?:at\s+)?(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)\b|\bat\s+(\d{1,2})(?:[:.](\d{2}))?\b"#,
        options: options)

    private static let relativeRegex = try! NSRegularExpression(
        pattern: #"\bin\s+(\d+|an?|one)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)\b"#,
        options: options)

    private static let repeatRegex = try! NSRegularExpression(
        pattern: #"\b(?:every\s+(day|weekday|week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)|(daily|weekly|monthly))\b"#,
        options: options)

    private static let weekdays: [String: Int] = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]

    static func parse(_ text: String, enabled: Bool = true, now: Date = Date()) -> ParsedInput {
        guard enabled, !text.isEmpty else { return ParsedInput(title: text, due: nil, range: nil) }

        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let cal = Calendar.current
        var ranges: [NSRange] = []
        var due: Date?
        var repeats: RepeatRule?

        if let m = relativeRegex.firstMatch(in: text, range: full) {
            let amount = Int(ns.substring(with: m.range(at: 1))) ?? 1
            let unit = ns.substring(with: m.range(at: 2)).lowercased()
            let component: Calendar.Component =
                unit.hasPrefix("m") ? .minute :
                unit.hasPrefix("h") ? .hour :
                unit.hasPrefix("d") ? .day : .weekOfYear
            due = cal.date(byAdding: component, value: amount, to: now)
            ranges.append(m.range)
        } else {
            let today = cal.startOfDay(for: now)
            var day: Date?
            var tonight = false

            if let m = repeatRegex.firstMatch(in: text, range: full) {
                let group = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
                let word = ns.substring(with: group).lowercased()
                switch word {
                case "day", "daily": repeats = .daily
                case "weekday": repeats = .weekdays
                case "week", "weekly": repeats = .weekly
                case "month", "monthly": repeats = .monthly
                default:
                    if let weekday = weekdays[String(word.prefix(3))] {
                        repeats = .weekly
                        if cal.component(.weekday, from: today) == weekday {
                            day = today
                        } else {
                            var c = DateComponents()
                            c.weekday = weekday
                            day = cal.nextDate(after: today, matching: c, matchingPolicy: .nextTime)
                        }
                    }
                }
                if repeats != nil { ranges.append(m.range) }
            }

            if day == nil, let m = dayRegex.firstMatch(in: text, range: full),
               !ranges.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) {
                let group = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
                let word = ns.substring(with: group).lowercased()
                switch word {
                case "today":
                    day = today
                case "tonight":
                    day = today
                    tonight = true
                case "tomorrow", "tommorow", "tmrw":
                    day = cal.date(byAdding: .day, value: 1, to: today)
                default:
                    if let weekday = weekdays[String(word.prefix(3))] {
                        var c = DateComponents()
                        c.weekday = weekday
                        day = cal.nextDate(after: today, matching: c, matchingPolicy: .nextTime)
                    }
                }
                if day != nil { ranges.append(m.range) }
            }

            var hourMinute: (Int, Int)?
            if let m = timeRegex.firstMatch(in: text, range: full) {
                let hasAmPm = m.range(at: 1).location != NSNotFound
                let hourRange = hasAmPm ? m.range(at: 1) : m.range(at: 4)
                let minuteRange = hasAmPm ? m.range(at: 2) : m.range(at: 5)
                var hour = Int(ns.substring(with: hourRange)) ?? 9
                let minute = minuteRange.location != NSNotFound ? (Int(ns.substring(with: minuteRange)) ?? 0) : 0
                if hasAmPm {
                    let ampm = ns.substring(with: m.range(at: 3)).lowercased()
                    if ampm == "pm" && hour < 12 { hour += 12 }
                    if ampm == "am" && hour == 12 { hour = 0 }
                } else if hour < 8 {
                    hour += 12
                }
                if hour <= 23 && minute <= 59 {
                    hourMinute = (hour, minute)
                    ranges.append(m.range)
                }
            }

            if day != nil || hourMinute != nil || repeats != nil {
                let baseDay = day ?? today
                let (h, mi) = hourMinute ?? (tonight ? (21, 0) : (9, 0))
                var date = cal.date(bySettingHour: h, minute: mi, second: 0, of: baseDay)
                if let d = date, d <= now {
                    if let rule = repeats {
                        date = rule.next(after: d, calendar: cal)
                    } else if day == nil {
                        date = cal.date(byAdding: .day, value: 1, to: d)
                    }
                }
                if let rule = repeats, let d = date {
                    date = rule.firstOccurrence(onOrAfter: d, calendar: cal)
                }
                due = date
            }
        }

        guard due != nil, !ranges.isEmpty else {
            return ParsedInput(title: text, due: nil, range: nil)
        }

        var title = text
        for r in ranges.sorted(by: { $0.location > $1.location }) {
            title = (title as NSString).replacingCharacters(in: r, with: " ")
        }
        title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: #"\s+(on|at|by|for)$"#, with: "",
                                           options: [.regularExpression, .caseInsensitive])

        let start = ranges.map(\.location).min() ?? 0
        let end = ranges.map { NSMaxRange($0) }.max() ?? 0
        return ParsedInput(title: title, due: due, range: NSRange(location: start, length: end - start), repeats: repeats)
    }
}
