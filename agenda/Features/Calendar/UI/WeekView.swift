import SwiftData
import SwiftUI

enum WeekGridMetrics {
    static let hourHeight: CGFloat = 52
    static let timeColumnWidth: CGFloat = 56
    static let initialScrollHour = 7
}

/// Seven-day grid with calendar events and scheduled tasks side by side.
struct WeekView: View {
    @Environment(WeekCalendarModel.self) private var model
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]

    var body: some View {
        let entries = model.events + CalendarEntry.scheduledTasks(tasks, in: model.interval)
        let days = model.days

        VStack(spacing: 0) {
            CalendarAccessBanner()
            WeekDayHeader(days: days)
            AllDayRow(days: days, entries: entries, week: model.week, onSelectTask: selectTask)
            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        HourLabelsColumn()
                        ForEach(days, id: \.self) { day in
                            DayColumn(
                                day: day,
                                positioned: model.week.layout(entries, on: day),
                                onCreateTask: createTask(at:),
                                onSelectTask: selectTask
                            )
                        }
                    }
                }
                .onAppear { proxy.scrollTo(WeekGridMetrics.initialScrollHour, anchor: .top) }
            }
        }
        .frame(minWidth: 600)
        .navigationTitle(title(for: days))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button("Previous Week", systemImage: "chevron.left", action: model.showPreviousWeek)
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Today") { model.showToday() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Next Week", systemImage: "chevron.right", action: model.showNextWeek)
                    .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
        .task {
            model.reload()
            await model.observeChanges()
        }
    }

    private func title(for days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "Calendar" }
        let calendar = Calendar.current
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return first.formatted(.dateTime.month(.wide).year())
        }
        return "\(first.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
    }

    private func selectTask(_ id: PersistentIdentifier) {
        appState.select(task: id)
    }

    private func createTask(at start: Date) {
        let task = TaskItem(title: "New Task", scheduledStart: start)
        modelContext.insert(task)
        try? modelContext.save() // Swap the temporary ID for a permanent one before selecting it.
        appState.select(task: task.persistentModelID)
    }
}

// MARK: - Header rows

private struct WeekDayHeader: View {
    let days: [Date]

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: WeekGridMetrics.timeColumnWidth, height: 1)
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isToday ? .white : .primary)
                        .frame(minWidth: 26, minHeight: 26)
                        .background {
                            if isToday { Circle().fill(Color.accentColor) }
                        }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct AllDayRow: View {
    let days: [Date]
    let entries: [CalendarEntry]
    let week: WeekCalendar
    var onSelectTask: (PersistentIdentifier) -> Void

    var body: some View {
        let perDay = days.map { week.allDayEntries(entries, on: $0) }
        if perDay.contains(where: { !$0.isEmpty }) {
            HStack(alignment: .top, spacing: 0) {
                Text("all-day")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: WeekGridMetrics.timeColumnWidth - 6, alignment: .trailing)
                    .padding(.trailing, 6)
                ForEach(Array(days.enumerated()), id: \.element) { index, _ in
                    VStack(spacing: 2) {
                        ForEach(perDay[index]) { entry in
                            EntryBlock(entry: entry, showsTime: false, onSelectTask: onSelectTask)
                                .frame(height: 20)
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Grid

private struct HourLabelsColumn: View {
    var body: some View {
        let midnight = Calendar.current.startOfDay(for: .now)
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(midnight.addingTimeInterval(TimeInterval(hour * 3600)), format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .opacity(hour == 0 ? 0 : 1)
                    .offset(y: -7)
                    .frame(width: WeekGridMetrics.timeColumnWidth - 8, height: WeekGridMetrics.hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 8)
                    .id(hour)
            }
        }
    }
}

private struct DayColumn: View {
    let day: Date
    let positioned: [PositionedEntry]
    var onCreateTask: (Date) -> Void
    var onSelectTask: (PersistentIdentifier) -> Void

    private let hourHeight = WeekGridMetrics.hourHeight

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HourLines()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { location in
                        onCreateTask(startDate(forY: location.y))
                    }

                ForEach(positioned) { item in
                    let columnWidth = (geometry.size.width - 4) / CGFloat(item.columnCount)
                    let height = CGFloat(item.endMinute - item.startMinute) / 60 * hourHeight
                    EntryBlock(entry: item.entry, showsTime: height >= 34, onSelectTask: onSelectTask)
                        .frame(width: max(columnWidth - 2, 0), height: max(height - 2, 14))
                        .offset(
                            x: 2 + CGFloat(item.column) * columnWidth,
                            y: CGFloat(item.startMinute) / 60 * hourHeight + 1
                        )
                }

                if Calendar.current.isDateInToday(day) {
                    NowIndicator(day: day)
                }
            }
        }
        .frame(height: hourHeight * 24)
        .frame(maxWidth: .infinity)
        .background(Calendar.current.isDateInWeekend(day) ? Color.secondary.opacity(0.04) : .clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(.separator).frame(width: 1)
        }
    }

    /// Snaps a click in the column to the half hour it falls in.
    private func startDate(forY y: CGFloat) -> Date {
        let minutes = Int(max(0, y) / hourHeight * 60) / 30 * 30
        let dayStart = Calendar.current.startOfDay(for: day)
        return Calendar.current.date(byAdding: .minute, value: min(minutes, 23 * 60 + 30), to: dayStart) ?? dayStart
    }
}

private struct HourLines: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle().fill(.separator).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: WeekGridMetrics.hourHeight)
            }
        }
    }
}

private struct NowIndicator: View {
    let day: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            let minutes = context.date.timeIntervalSince(Calendar.current.startOfDay(for: day)) / 60
            HStack(spacing: 0) {
                Circle().frame(width: 8, height: 8)
                Rectangle().frame(height: 1.5)
            }
            .foregroundStyle(.red)
            .offset(x: -4, y: CGFloat(minutes) / 60 * WeekGridMetrics.hourHeight - 4)
            .allowsHitTesting(false)
        }
    }
}
