import Foundation

/// An entry placed on a single day column, in minutes from midnight.
struct PositionedEntry: Identifiable, Hashable {
    let entry: CalendarEntry
    let startMinute: Int
    let endMinute: Int
    let column: Int
    let columnCount: Int

    var id: String { entry.id }
}

/// Week math and the side-by-side layout for overlapping entries.
struct WeekCalendar {
    static let minutesPerDay = 24 * 60
    static let minimumEntryMinutes = 15

    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func interval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 24 * 60 * 60)
    }

    func days(containing date: Date) -> [Date] {
        let start = interval(containing: date).start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func shift(_ date: Date, byWeeks weeks: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }

    /// The whole day containing `date`, from midnight to the next midnight.
    func dayInterval(containing date: Date) -> DateInterval {
        let (start, end) = bounds(of: date)
        return DateInterval(start: start, end: end)
    }

    func shift(_ date: Date, byDays days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// The half hour on `day` that a point `minute` minutes into the day falls in, for a new task.
    func slotStart(on day: Date, atMinute minute: Double) -> Date {
        let snapped = min(max(Int(minute), 0) / 30 * 30, 23 * 60 + 30)
        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: snapped, to: dayStart) ?? dayStart
    }

    func allDayEntries(_ entries: [CalendarEntry], on day: Date) -> [CalendarEntry] {
        let (dayStart, dayEnd) = bounds(of: day)
        return entries
            .filter { $0.isAllDay && $0.start < dayEnd && $0.end > dayStart }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Lays out timed entries for one day. Overlapping entries share the column
    /// width; a column is reused as soon as its previous entry has ended.
    func layout(_ entries: [CalendarEntry], on day: Date) -> [PositionedEntry] {
        let (dayStart, dayEnd) = bounds(of: day)

        let spans: [(entry: CalendarEntry, start: Int, end: Int)] = entries
            .filter { !$0.isAllDay && $0.start < dayEnd && $0.end > dayStart }
            .map { entry in
                let start = clampMinutes(entry.start.timeIntervalSince(dayStart))
                let end = clampMinutes(entry.end.timeIntervalSince(dayStart))
                return (entry, start, min(Self.minutesPerDay, max(end, start + Self.minimumEntryMinutes)))
            }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }

        var result: [PositionedEntry] = []
        var cluster: [(span: (entry: CalendarEntry, start: Int, end: Int), column: Int)] = []
        var columnEnds: [Int] = []
        var clusterEnd = 0

        func flush() {
            let count = max(columnEnds.count, 1)
            result += cluster.map {
                PositionedEntry(
                    entry: $0.span.entry,
                    startMinute: $0.span.start,
                    endMinute: $0.span.end,
                    column: $0.column,
                    columnCount: count
                )
            }
            cluster.removeAll()
            columnEnds.removeAll()
        }

        for span in spans {
            if !cluster.isEmpty && span.start >= clusterEnd { flush() }

            let column: Int
            if let free = columnEnds.firstIndex(where: { $0 <= span.start }) {
                column = free
                columnEnds[free] = span.end
            } else {
                column = columnEnds.count
                columnEnds.append(span.end)
            }
            cluster.append((span, column))
            clusterEnd = cluster.count == 1 ? span.end : max(clusterEnd, span.end)
        }
        flush()

        return result
    }

    private func bounds(of day: Date) -> (Date, Date) {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    private func clampMinutes(_ seconds: TimeInterval) -> Int {
        min(Self.minutesPerDay, max(0, Int((seconds / 60).rounded())))
    }
}
