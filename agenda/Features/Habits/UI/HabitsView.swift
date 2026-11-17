import SwiftData
import SwiftUI

/// Full-screen list of habits with streaks and the current week's check-ins.
struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]

    @State private var editorTarget: HabitEditorTarget?
    @State private var habitPendingDeletion: Habit?

    var body: some View {
        let now = Date.now

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader("Habits", subtitle: HabitsHeading.subtitle(for: habits, now: now)) {
                    Button("New Habit", systemImage: "plus") { editorTarget = .new }
                        .help("New Habit")
                        .buttonStyle(PageControlStyle())
                }

                if habits.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    VStack(spacing: 6) {
                        ForEach(habits) { habit in
                            HabitRowView(habit: habit, now: now) {
                                habitActions(habit)
                            }
                            .contextMenu { habitActions(habit) }
                        }
                    }
                }
            }
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .padding(Theme.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .plannerPanel()
        .navigationTitle("Habits")
        .toolbar(removing: .title)
        .sheet(item: $editorTarget) { target in
            HabitEditorSheet(target: target)
        }
        .confirmationDialog(
            "Delete this habit?",
            isPresented: isConfirmingDeletion,
            presenting: habitPendingDeletion
        ) { habit in
            Button("Delete \u{201C}\(habit.name)\u{201D}", role: .destructive) {
                modelContext.delete(habit)
            }
        } message: { _ in
            Text("Its check-in history will be deleted too.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Habits", systemImage: "flame")
        } description: {
            Text("Track a routine you want to keep, one day at a time.")
        } actions: {
            Button("New Habit") { editorTarget = .new }
        }
    }

    @ViewBuilder
    private func habitActions(_ habit: Habit) -> some View {
        Button("Edit Habit…") { editorTarget = .edit(habit) }
        Divider()
        Button("Delete Habit", role: .destructive) { habitPendingDeletion = habit }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(get: { habitPendingDeletion != nil }, set: { if !$0 { habitPendingDeletion = nil } })
    }
}

/// The short line under the Habits title: how today's check-ins are going.
enum HabitsHeading {
    static func subtitle(for habits: [Habit], now: Date = .now, calendar: Calendar = .current) -> String {
        guard !habits.isEmpty else { return "No habits yet" }
        let due = habits.filter { $0.isScheduled(on: now, calendar: calendar) }
        guard !due.isEmpty else { return "Nothing due today" }
        let done = due.filter { $0.isCompleted(on: now, calendar: calendar) }.count
        return done == due.count ? "All \(done) done today" : "\(done) of \(due.count) done today"
    }
}

/// One habit as a soft card: icon, name, 30-day rate, streak, and this week's day circles.
struct HabitRowView<Actions: View>: View {
    let habit: Habit
    let now: Date
    var calendar: Calendar = .current
    @ViewBuilder var actions: () -> Actions

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            HabitIcon(habit: habit)

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name.isEmpty ? "Untitled" : habit.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let rate = habit.completionRate(asOf: now, calendar: calendar) {
                    Text("\(rate, format: .percent.precision(.fractionLength(0))) of the last 30 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            StreakBadge(count: habit.currentStreak(asOf: now, calendar: calendar))

            HStack(spacing: 4) {
                ForEach(HabitWeek.days(containing: now, calendar: calendar), id: \.self) { day in
                    HabitDayButton(habit: habit, day: day, now: now, calendar: calendar)
                }
            }
            .fixedSize()

            Menu {
                actions()
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Habit Actions")
            .accessibilityLabel("Habit Actions")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(isHovered: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// A habit's symbol on a tinted rounded square.
struct HabitIcon: View {
    let habit: Habit
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: habit.symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(habit.color.color)
            .frame(width: size, height: size)
            .background(habit.color.color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

/// The current streak as a flame and a count, warm while the streak is alive.
private struct StreakBadge: View {
    let count: Int

    var body: some View {
        let isActive = count > 0

        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(isActive ? Color.orange : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(isActive ? Color.orange.opacity(0.14) : Theme.hairline, in: Capsule())
        .fixedSize()
        .frame(minWidth: 56, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak: \(count) \(count == 1 ? "day" : "days")")
    }
}

/// A day circle: filled when done, toggleable when scheduled and not in the future.
/// Today's column sits on a soft tint so it reads first.
private struct HabitDayButton: View {
    let habit: Habit
    let day: Date
    let now: Date
    let calendar: Calendar

    var body: some View {
        let isScheduled = habit.isScheduled(on: day, calendar: calendar)
        let isDone = habit.isCompleted(on: day, calendar: calendar)
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let isFuture = day > now && !isToday
        let tint = habit.color.color

        VStack(spacing: 4) {
            Text(verbatim: calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1])
                .font(.caption2.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? tint : Color.secondary)

            Button {
                withAnimation(.snappy) { habit.toggle(on: day, calendar: calendar) }
            } label: {
                ZStack {
                    Circle()
                        .fill(isDone ? tint : (isScheduled && !isFuture ? tint.opacity(0.08) : Color.clear))
                    Circle()
                        .strokeBorder(
                            isScheduled ? tint.opacity(isFuture ? 0.3 : (isDone ? 0 : 0.85)) : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: isToday ? 2 : 1.5, dash: isScheduled ? [] : [2, 2])
                        )
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isScheduled || isFuture)
            .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month().day()))
            .accessibilityValue(isDone ? "Done" : (isScheduled ? "Not done" : "Not scheduled"))
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .background(isToday ? tint.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}
