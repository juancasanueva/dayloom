import SwiftUI

/// Lists one day's calendar events so one can be added to a note.
struct EventPickerSheet: View {
    @State var day: Date
    let pick: (CalendarEntry) -> Void

    @Environment(WeekCalendarModel.self) private var calendarModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Event").font(.headline)
                Spacer()
                Button("Previous Day", systemImage: "chevron.left") { shiftDay(by: -1) }
                    .labelStyle(.iconOnly)
                Text(DayFormatting.relativeTitle(for: day))
                    .frame(minWidth: 110)
                Button("Next Day", systemImage: "chevron.right") { shiftDay(by: 1) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)

            if calendarModel.access == .granted {
                eventList
            } else {
                CalendarAccessBanner()
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 400, height: 380)
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
            List(events) { event in
                Button {
                    pick(event)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.tint.color)
                            .frame(width: 4, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).fontWeight(.medium)
                            Text(timeText(event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
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
