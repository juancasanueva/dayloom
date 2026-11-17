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
                HStack(spacing: 6) {
                    ForEach(scheduled) { habit in
                        TodayHabitChip(habit: habit, today: today)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// A habit as a soft pill: its check, icon and name. Done habits fill with the habit's color.
private struct TodayHabitChip: View {
    let habit: Habit
    let today: Date

    @State private var isHovered = false

    var body: some View {
        let isDone = habit.isCompleted(on: today)
        let tint = habit.color.color

        Button {
            withAnimation(.snappy) { habit.toggle(on: today) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isDone ? tint : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Image(systemName: habit.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(habit.name)
                    .fontWeight(.medium)
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(background(isDone: isDone, tint: tint), in: Capsule())
            .overlay {
                Capsule().strokeBorder(isDone ? tint.opacity(0.35) : Theme.hairline, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(habit.name)
        .accessibilityValue(isDone ? "Done today" : "Not done today")
        .accessibilityHint(isDone ? "Marks the habit as not done today" : "Marks the habit as done today")
    }

    private func background(isDone: Bool, tint: Color) -> AnyShapeStyle {
        if isDone { return AnyShapeStyle(tint.opacity(0.16)) }
        return AnyShapeStyle(isHovered ? Theme.cardHover : Theme.card)
    }
}
