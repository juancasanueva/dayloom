import SwiftData
import SwiftUI

/// One event or scheduled task drawn on the grid. Tasks open in the inspector; events show a popover.
struct EntryBlock: View {
    let entry: CalendarEntry
    var showsTime = true
    var onSelectTask: (PersistentIdentifier) -> Void

    @State private var showsDetails = false

    private var isTask: Bool { entry.taskID != nil }

    var body: some View {
        let tint = entry.tint.color

        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if isTask {
                    Image(systemName: entry.isCompletedTask ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                }
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .strikethrough(entry.isCompletedTask)
                    .lineLimit(2)
            }
            if showsTime {
                Text(entry.start, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(isTask ? 0.10 : 0.20), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .overlay {
            if isTask {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(tint.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
        .opacity(entry.isCompletedTask ? 0.6 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = entry.taskID {
                onSelectTask(id)
            } else {
                showsDetails = true
            }
        }
        .popover(isPresented: $showsDetails, arrowEdge: .trailing) {
            EventDetails(entry: entry)
        }
        .help(entry.title)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct EventDetails: View {
    let entry: CalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)

            Label(timeDescription, systemImage: "clock")

            if let calendarName = entry.calendarName {
                Label {
                    Text(calendarName)
                } icon: {
                    Image(systemName: "circle.fill").foregroundStyle(entry.tint.color)
                }
            }
            if let location = entry.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
            }
            if let url = entry.url {
                Link(destination: url) {
                    Label("Open Link", systemImage: "link")
                }
            }
        }
        .font(.callout)
        .padding(14)
        .frame(minWidth: 220, alignment: .leading)
    }

    private var timeDescription: String {
        if entry.isAllDay {
            return "\(entry.start.formatted(date: .abbreviated, time: .omitted)) · All day"
        }
        let range = entry.start..<entry.end
        return range.formatted(.interval.weekday().month(.abbreviated).day().hour().minute())
    }
}
