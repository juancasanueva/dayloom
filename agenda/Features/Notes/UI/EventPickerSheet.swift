import SwiftUI

/// Lists one day's calendar events so one can be added to a note.
struct EventPickerSheet: View {
    @State var day: Date
    let pick: (CalendarEntry) -> Void

    @Environment(WeekCalendarModel.self) private var calendarModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Add Event")
                    .font(Theme.sectionTitle)
                Spacer()
                Button("Previous Day", systemImage: "chevron.left") { shiftDay(by: -1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(PageControlStyle(horizontalPadding: 8))
                Text(DayFormatting.relativeTitle(for: day))
                    .font(.callout.weight(.medium))
                    .frame(minWidth: 110)
                Button("Next Day", systemImage: "chevron.right") { shiftDay(by: 1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(PageControlStyle(horizontalPadding: 8))
            }

            if calendarModel.access == .granted {
                eventList
            } else {
                CalendarAccessBanner()
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 400, height: 380)
        .background(Theme.panel)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var eventList: some View {
        let events = calendarModel.events(on: day)
        if events.isEmpty {
            ContentUnavailableView("No Events", systemImage: "calendar", description: Text("Nothing is scheduled on this day."))
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(events) { event in
                        Button {
                            pick(event)
                            dismiss()
                        } label: {
                            EventPickerRow(title: event.title, detail: timeText(event), tint: event.tint.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func timeText(_ event: CalendarEntry) -> String {
        if event.isAllDay { return "All day" }
        let from = event.start.formatted(date: .omitted, time: .shortened)
        let to = event.end.formatted(date: .omitted, time: .shortened)
        let calendar = event.calendarName.map { " · \($0)" } ?? ""
        return "\(from) – \(to)\(calendar)"
    }

    private func shiftDay(by days: Int) {
        day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
    }
}

/// One event in the picker, as a soft card tinted with its calendar's color.
private struct EventPickerRow: View {
    let title: String
    let detail: String
    let tint: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(isHovered: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
