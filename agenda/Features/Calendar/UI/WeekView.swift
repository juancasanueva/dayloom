import SwiftData
import SwiftUI

enum WeekGridMetrics {
    static let hourHeight: CGFloat = 52
    static let timeColumnWidth: CGFloat = 56
    static let initialScrollHour = 7
    /// Corner radius of the soft strip that marks today's column.
    static let todayRadius: CGFloat = 10
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
        let selectedTaskID = appState.selectedTaskID

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(title(for: days), subtitle: subtitle(for: days, count: entries.count)) {
                    WeekNavigationControls(
                        onPrevious: model.showPreviousWeek,
                        onToday: { model.showToday() },
                        onNext: model.showNextWeek
                    )
                }
                CalendarAccessBanner()
            }
            .padding(.top, Theme.pagePadding.top)
            .padding(.horizontal, Theme.pagePadding.leading)
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                WeekDayHeader(days: days)
                AllDayRow(days: days, entries: entries, week: model.week, selectedTaskID: selectedTaskID, onSelectTask: selectTask)
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 0) {
                            HourLabelsColumn(showsNow: days.contains(where: Calendar.current.isDateInToday))
                            ForEach(days, id: \.self) { day in
                                DayColumn(
                                    day: day,
                                    positioned: model.week.layout(entries, on: day),
                                    selectedTaskID: selectedTaskID,
                                    onCreateTask: createTask(at:),
                                    onSelectTask: selectTask
                                )
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .onAppear { proxy.scrollTo(WeekGridMetrics.initialScrollHour, anchor: .top) }
                }
            }
            .padding(.leading, Theme.pagePadding.leading - 16)
            .padding(.trailing, Theme.pagePadding.trailing - 8)
        }
        .frame(minWidth: 600)
        .plannerPanel()
        .navigationTitle(title(for: days))
        .toolbar(removing: .title)
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

    /// The visible days, such as "Nov 16 – 22", and how much is on them.
    private func subtitle(for days: [Date], count: Int) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let range = (first..<last).formatted(.interval.month(.abbreviated).day())
        return count == 0 ? "\(range) · Nothing scheduled" : "\(range) · \(count) scheduled"
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

// MARK: - Week navigation

/// Previous week, back to today, and next week, shown in the page header.
private struct WeekNavigationControls: View {
    var onPrevious: () -> Void
    var onToday: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button("Today", action: onToday)
                .keyboardShortcut("t", modifiers: .command)
                .help("Go to This Week (⌘T)")
                .buttonStyle(HeaderControlStyle(horizontalPadding: 12))

            HStack(spacing: 2) {
                Button("Previous Week", systemImage: "chevron.left", action: onPrevious)
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .help("Previous Week (⌘←)")
                Button("Next Week", systemImage: "chevron.right", action: onNext)
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .help("Next Week (⌘→)")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(HeaderControlStyle(horizontalPadding: 9))
        }
        .font(.callout.weight(.medium))
    }
}

/// A quiet rounded control on the card surface, a little stronger under the pointer or when pressed.
private struct HeaderControlStyle: ButtonStyle {
    var horizontalPadding: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        HeaderControl(configuration: configuration, horizontalPadding: horizontalPadding)
    }

    private struct HeaderControl: View {
        let configuration: ButtonStyleConfiguration
        let horizontalPadding: CGFloat
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(.horizontal, horizontalPadding)
                .frame(minHeight: 28)
                .background(
                    configuration.isPressed ? Theme.hairline : (isHovered ? Theme.cardHover : Theme.card),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Header rows

private struct WeekDayHeader: View {
    let days: [Date]

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: WeekGridMetrics.timeColumnWidth, height: 1)
            ForEach(days, id: \.self) { day in
                WeekDayLabel(day: day)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if Calendar.current.isDateInToday(day) {
                            UnevenRoundedRectangle(topLeadingRadius: WeekGridMetrics.todayRadius, topTrailingRadius: WeekGridMetrics.todayRadius)
                                .fill(TodayColumn.tint)
                        }
                    }
            }
        }
    }
}

/// A day at the top of the week: its short name, large, with the date under it. Today is in the accent color.
private struct WeekDayLabel: View {
    let day: Date

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)

        VStack(alignment: .leading, spacing: 1) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(Theme.sectionTitle)
                .foregroundStyle(isToday ? Color.accentColor : Color.primary)
            Text(DayFormatting.shortDate(for: day))
                .font(.caption)
                .foregroundStyle(isToday ? AnyShapeStyle(Color.accentColor.opacity(0.8)) : AnyShapeStyle(.secondary))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isToday ? "Today, \(day.formatted(date: .complete, time: .omitted))" : day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(.isHeader)
    }
}

private struct AllDayRow: View {
    let days: [Date]
    let entries: [CalendarEntry]
    let week: WeekCalendar
    let selectedTaskID: PersistentIdentifier?
    var onSelectTask: (PersistentIdentifier) -> Void

    var body: some View {
        let perDay = days.map { week.allDayEntries(entries, on: $0) }
        if perDay.contains(where: { !$0.isEmpty }) {
            HStack(alignment: .top, spacing: 0) {
                Text("all-day")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: WeekGridMetrics.timeColumnWidth - 8, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    VStack(spacing: 3) {
                        ForEach(perDay[index]) { entry in
                            EntryBlock(
                                entry: entry,
                                showsTime: false,
                                isSelected: entry.taskID != nil && entry.taskID == selectedTaskID,
                                onSelectTask: onSelectTask
                            )
                            .frame(height: 22)
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Calendar.current.isDateInToday(day) ? TodayColumn.tint : .clear)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Grid

private enum TodayColumn {
    /// The soft wash behind today's column.
    static let tint = Color.accentColor.opacity(0.06)
}

private struct HourLabelsColumn: View {
    /// Whether the visible week contains today, so the current time is labeled.
    let showsNow: Bool

    var body: some View {
        let midnight = Calendar.current.startOfDay(for: .now)
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(midnight.addingTimeInterval(TimeInterval(hour * 3600)), format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .opacity(hour == 0 ? 0 : 1)
                    .offset(y: -7)
                    .frame(width: WeekGridMetrics.timeColumnWidth - 10, height: WeekGridMetrics.hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 10)
                    .id(hour)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsNow {
                NowTimeLabel()
            }
        }
    }
}

private struct DayColumn: View {
    let day: Date
    let positioned: [PositionedEntry]
    let selectedTaskID: PersistentIdentifier?
    var onCreateTask: (Date) -> Void
    var onSelectTask: (PersistentIdentifier) -> Void

    private let hourHeight = WeekGridMetrics.hourHeight

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)

        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HourLines()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { location in
                        onCreateTask(startDate(forY: location.y))
                    }

                ForEach(positioned) { item in
                    let columnWidth = (geometry.size.width - 6) / CGFloat(item.columnCount)
                    let height = CGFloat(item.endMinute - item.startMinute) / 60 * hourHeight
                    EntryBlock(
                        entry: item.entry,
                        showsTime: height >= 34,
                        isSelected: item.entry.taskID != nil && item.entry.taskID == selectedTaskID,
                        onSelectTask: onSelectTask
                    )
                    .frame(width: max(columnWidth - 2, 0), height: max(height - 2, 16))
                    .offset(
                        x: 3 + CGFloat(item.column) * columnWidth,
                        y: CGFloat(item.startMinute) / 60 * hourHeight + 1
                    )
                }

                if isToday {
                    NowIndicator(day: day)
                }
            }
        }
        .frame(height: hourHeight * 24)
        .frame(maxWidth: .infinity)
        .background {
            if isToday {
                UnevenRoundedRectangle(bottomLeadingRadius: WeekGridMetrics.todayRadius, bottomTrailingRadius: WeekGridMetrics.todayRadius)
                    .fill(TodayColumn.tint)
            } else if Calendar.current.isDateInWeekend(day) {
                Color.primary.opacity(0.018)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
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
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: WeekGridMetrics.hourHeight)
            }
        }
    }
}

// MARK: - Current time

private enum NowStyle {
    static let color = Color.red
}

private struct NowIndicator: View {
    let day: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            let minutes = context.date.timeIntervalSince(Calendar.current.startOfDay(for: day)) / 60
            HStack(spacing: 0) {
                Circle().frame(width: 8, height: 8)
                Rectangle().frame(height: 2)
            }
            .foregroundStyle(NowStyle.color)
            .offset(x: -4, y: CGFloat(minutes) / 60 * WeekGridMetrics.hourHeight - 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// The current time in a small pill beside the hour labels, level with the indicator line.
private struct NowTimeLabel: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let minutes = context.date.timeIntervalSince(Calendar.current.startOfDay(for: context.date)) / 60
            Text(context.date, format: .dateTime.hour().minute())
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(NowStyle.color, in: Capsule())
                .offset(x: -4, y: CGFloat(minutes) / 60 * WeekGridMetrics.hourHeight - 8)
                .allowsHitTesting(false)
                .accessibilityLabel("Now, \(context.date.formatted(date: .omitted, time: .shortened))")
        }
    }
}
