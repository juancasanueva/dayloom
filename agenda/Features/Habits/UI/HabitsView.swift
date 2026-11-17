import SwiftData
import SwiftUI

/// Full-screen list of habits with streaks and the current week's check-ins.
struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]

    @State private var editorTarget: HabitEditorTarget?
    @State private var habitPendingDeletion: Habit?

    var body: some View {
        Group {
            if habits.isEmpty {
                ContentUnavailableView {
                    Label("No Habits", systemImage: "flame")
                } description: {
                    Text("Track a routine you want to keep, one day at a time.")
                } actions: {
                    Button("New Habit") { editorTarget = .new }
                }
            } else {
                List {
                    ForEach(habits) { habit in
                        HabitRowView(habit: habit, now: .now) {
                            habitActions(habit)
                        }
                        .contextMenu { habitActions(habit) }
                    }
                }
            }
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Habit", systemImage: "plus") { editorTarget = .new }
            }
        }
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

/// One habit: icon, name, 30-day rate, streak, and this week's day circles.
struct HabitRowView<Actions: View>: View {
    let habit: Habit
    let now: Date
    var calendar: Calendar = .current
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            HabitIcon(habit: habit)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name.isEmpty ? "Untitled" : habit.name)
                    .lineLimit(1)
                if let rate = habit.completionRate(asOf: now, calendar: calendar) {
                    Text("\(rate, format: .percent.precision(.fractionLength(0))) of the last 30 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            StreakBadge(count: habit.currentStreak(asOf: now, calendar: calendar))

            HStack(spacing: 6) {
                ForEach(HabitWeek.days(containing: now, calendar: calendar), id: \.self) { day in
                    HabitDayButton(habit: habit, day: day, now: now, calendar: calendar)
                }
            }

            Menu {
                actions()
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Habit Actions")
        }
        .padding(.vertical, 4)
    }
}

struct HabitIcon: View {
    let habit: Habit

    var body: some View {
        Image(systemName: habit.symbolName)
            .font(.title3)
            .foregroundStyle(habit.color.color)
            .frame(width: 32, height: 32)
            .background(habit.color.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

private struct StreakBadge: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "flame.fill")
            .font(.callout.monospacedDigit())
            .foregroundStyle(count > 0 ? Color.orange : Color.secondary)
            .frame(minWidth: 44, alignment: .trailing)
            .accessibilityLabel("Streak: \(count) \(count == 1 ? "day" : "days")")
    }
}

/// A day circle: filled when done, toggleable when scheduled and not in the future.
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

        VStack(spacing: 3) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.primary : Color.secondary)

            Button {
                withAnimation(.snappy) { habit.toggle(on: day, calendar: calendar) }
            } label: {
                ZStack {
                    Circle()
                        .fill(isDone ? tint : Color.clear)
                    Circle()
                        .strokeBorder(
                            isScheduled ? tint.opacity(isFuture ? 0.35 : 1) : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1.5, dash: isScheduled ? [] : [2, 2])
                        )
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isScheduled || isFuture)
            .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month().day()))
            .accessibilityValue(isDone ? "Done" : (isScheduled ? "Not done" : "Not scheduled"))
        }
    }
}
