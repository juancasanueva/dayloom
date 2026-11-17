import SwiftUI

/// The day beside a group of tasks: its name, large, with the date under it. Today stands out.
struct DayColumnLabel: View {
    let day: Date

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)

        VStack(alignment: .leading, spacing: 1) {
            Text(DayFormatting.dayName(for: day))
                .font(Theme.sectionTitle)
                .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(DayFormatting.shortDate(for: day))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
