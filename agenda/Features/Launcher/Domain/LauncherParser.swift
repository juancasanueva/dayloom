import Foundation

/// Turns launcher text such as "Review budget fri 3pm for 45min !high #work" into a `LauncherInput`.
///
/// Pure and deterministic: the result depends only on the text, `now`, and `calendar`.
/// English only. The first date, time, duration, and priority win; repeats stay in the title.
enum LauncherParser {
    static func parse(_ text: String, now: Date, calendar: Calendar) -> LauncherInput {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let today = calendar.startOfDay(for: now)

        var input = LauncherInput()
        var date: Date?
        var time: (hour: Int, minute: Int)?
        var titleTokens: [String] = []

        var index = 0
        while index < tokens.count {
            let rest = tokens[index...].map { $0.lowercased() }

            if input.priority == .none, let priority = priority(rest[0]) {
                input.priority = priority
                index += 1
            } else if let tag = tagName(tokens[index]) {
                if !input.tagNames.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                    input.tagNames.append(tag)
                }
                index += 1
            } else if date == nil, let match = dateMatch(rest, today: today, calendar: calendar) {
                date = match.date
                index += match.length
            } else if time == nil, let match = timeMatch(rest) {
                time = match.time
                index += match.length
            } else if input.duration == nil, let match = durationMatch(rest) {
                input.duration = match.seconds
                index += match.length
            } else {
                titleTokens.append(tokens[index])
                index += 1
            }
        }

        input.title = titleTokens.joined(separator: " ")
        if let time {
            let day = date ?? today
            input.day = day
            input.start = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
        } else {
            input.day = date
        }
        return input
    }

    // MARK: Priority and tags

    private static func priority(_ token: String) -> TaskPriority? {
        switch token {
        case "!high", "!!!": .high
        case "!medium", "!med", "!!": .medium
        case "!low", "!": .low
        default: nil
        }
    }

    private static func tagName(_ token: String) -> String? {
        guard token.hasPrefix("#") else { return nil }
        let name = token.dropFirst()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !name.isEmpty, name.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return String(name)
    }

    // MARK: Dates

    private static let weekdays: [String: Int] = {
        let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        var map: [String: Int] = [:]
        for (offset, name) in names.enumerated() {
            map[name] = offset + 1
            map[String(name.prefix(3))] = offset + 1
        }
        return map
    }()

    private static func dateMatch(_ tokens: [String], today: Date, calendar: Calendar) -> (date: Date, length: Int)? {
        func adding(days: Int) -> Date? { calendar.date(byAdding: .day, value: days, to: today) }

        switch tokens[0] {
        case "today":
            return (today, 1)
        case "tomorrow", "tmr":
            return adding(days: 1).map { ($0, 1) }
        default:
            break
        }

        if let weekday = weekdays[tokens[0]] {
            let current = calendar.component(.weekday, from: today)
            let ahead = (weekday - current + 7) % 7
            return adding(days: ahead == 0 ? 7 : ahead).map { ($0, 1) }
        }

        if tokens.count >= 2, tokens[0] == "next", tokens[1] == "week",
           let nextWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.end {
            return (calendar.startOfDay(for: nextWeek), 2)
        }

        if tokens.count >= 3, tokens[0] == "in", let count = Int(tokens[1]), count >= 0 {
            switch tokens[2] {
            case "day", "days": return adding(days: count).map { ($0, 3) }
            case "week", "weeks": return adding(days: count * 7).map { ($0, 3) }
            default: return nil
            }
        }
        return nil
    }

    // MARK: Times

    private static func timeMatch(_ tokens: [String]) -> (time: (hour: Int, minute: Int), length: Int)? {
        if let time = time(tokens[0]) { return (time, 1) }
        if tokens.count >= 2, tokens[0] == "at", let time = time(tokens[1]) { return (time, 2) }
        return nil
    }

    /// Accepts "3pm", "3:30pm", "15:00", "noon", and "midnight".
    private static func time(_ token: String) -> (hour: Int, minute: Int)? {
        switch token {
        case "noon": return (12, 0)
        case "midnight": return (0, 0)
        default: break
        }

        var text = Substring(token)
        var isPM: Bool?
        if text.hasSuffix("am") || text.hasSuffix("pm") {
            isPM = text.hasSuffix("pm")
            text = text.dropLast(2)
        }

        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }),
              parts[0].count <= 2,
              let hour = Int(parts[0]) else { return nil }

        var minute = 0
        if parts.count == 2 {
            guard parts[1].count == 2, let value = Int(parts[1]), value < 60 else { return nil }
            minute = value
        }

        if let isPM {
            guard (1...12).contains(hour) else { return nil }
            return (hour % 12 + (isPM ? 12 : 0), minute)
        }
        // Without am/pm only the 24-hour "HH:MM" form counts, so plain numbers stay in the title.
        guard parts.count == 2, hour < 24 else { return nil }
        return (hour, minute)
    }

    // MARK: Durations

    private static func durationMatch(_ tokens: [String]) -> (seconds: TimeInterval, length: Int)? {
        guard tokens.count >= 2, tokens[0] == "for" else { return nil }
        if let seconds = duration(tokens[1]) { return (seconds, 2) }
        if tokens.count >= 3, let seconds = duration(tokens[1] + tokens[2]) { return (seconds, 3) }
        return nil
    }

    /// Accepts "30m", "45min", "1h", "1.5h", "90minutes" (the last also typed as two words).
    private static func duration(_ token: String) -> TimeInterval? {
        let number = token.prefix { $0.isASCIIDigit || $0 == "." }
        let unit = token.dropFirst(number.count)
        guard let value = Double(number), value > 0 else { return nil }

        switch unit {
        case "m", "min", "mins", "minute", "minutes": return (value * 60).rounded()
        case "h", "hr", "hrs", "hour", "hours": return (value * 3600).rounded()
        default: return nil
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
