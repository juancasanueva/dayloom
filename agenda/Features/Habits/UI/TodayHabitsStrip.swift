import SwiftData
import SwiftUI

/// Compact row of the habits scheduled today, each with a check toggle.
/// Renders nothing when no habit is scheduled today.
struct TodayHabitsStrip: View {
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]

    var body: some View {
        let today = Date.now
        let scheduled = habits.filter { $0.isScheduled(on: today) }

        if !scheduled.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(scheduled) { habit in
                        TodayHabitChip(habit: habit, today: today)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct TodayHabitChip: View {
    let habit: Habit
    let today: Date

    var body: some View {
        let isDone = habit.isCompleted(on: today)
        let tint = habit.color.color

        Button {
            withAnimation(.snappy) { habit.toggle(on: today) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? tint : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Image(systemName: habit.symbolName)
                    .foregroundStyle(tint)
                Text(habit.name)
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(isDone ? 0.18 : 0.08), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.name)
        .accessibilityValue(isDone ? "Done today" : "Not done today")
        .accessibilityHint(isDone ? "Marks the habit as not done today" : "Marks the habit as done today")
    }
}
