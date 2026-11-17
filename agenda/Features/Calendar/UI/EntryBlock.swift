import SwiftData
import SwiftUI

/// One event or scheduled task drawn on the grid. Tasks open in the inspector; events show a popover.
struct EntryBlock: View {
    let entry: CalendarEntry
    var showsTime = true
    /// Whether this is the task open in the inspector.
    var isSelected = false
    var onSelectTask: (PersistentIdentifier) -> Void

    @State private var showsDetails = false
    @State private var isHovered = false

    private static let radius: CGFloat = 7
    private var isTask: Bool { entry.taskID != nil }

    var body: some View {
        let tint = entry.tint.color
        let shape = RoundedRectangle(cornerRadius: Self.radius)

        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if isTask {
                    Image(systemName: entry.isCompletedTask ? "checkmark.circle.fill" : "circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .strikethrough(entry.isCompletedTask)
                    .lineLimit(2)
            }
            if showsTime {
                Text(entry.start, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // Tasks sit on the card surface with a hint of their color; events are washed in theirs.
            shape.fill(isTask ? (isHovered ? Theme.cardHover : Theme.card) : Theme.panel)
            shape.fill(tint.opacity(isTask ? (isSelected ? 0.16 : 0.07) : (isHovered ? 0.28 : 0.20)))
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(tint.opacity(entry.isCompletedTask ? 0.5 : 1))
                .frame(width: 3)
                .padding(.vertical, 3)
                .padding(.leading, 2)
        }
        .overlay {
            shape.strokeBorder(
                isSelected ? Theme.accent.opacity(0.8) : (isTask ? Theme.hairline : .clear),
                lineWidth: isSelected ? 1.5 : 1
            )
        }
        .opacity(entry.isCompletedTask ? 0.6 : 1)
        .clipShape(shape)
        .contentShape(shape)
        .onHover { isHovered = $0 }
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
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
