import SwiftData
import SwiftUI

/// Three status lanes side by side. Cards are dragged between lanes to change their status.
struct TaskBoardView<CardMenu: View>: View {
    let columns: [BoardColumn]
    let emphasis: (TaskItem) -> TimeEmphasis
    /// Handles dropped payloads for a column and reports whether anything moved.
    let onDrop: ([String], TaskStatus) -> Bool
    @ViewBuilder let cardMenu: (TaskItem) -> CardMenu

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(columns) { column in
                BoardColumnView(column: column, emphasis: emphasis, onDrop: onDrop, cardMenu: cardMenu)
            }
        }
        // Lanes start where the page header starts.
        .padding(.top, 14)
        .padding(.leading, Theme.pagePadding.leading)
        .padding(.trailing, Theme.pagePadding.trailing)
        .padding(.bottom, Theme.pagePadding.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct BoardColumnView<CardMenu: View>: View {
    let column: BoardColumn
    let emphasis: (TaskItem) -> TimeEmphasis
    let onDrop: ([String], TaskStatus) -> Bool
    let cardMenu: (TaskItem) -> CardMenu

    @Environment(AppState.self) private var appState
    @State private var isTargeted = false

    private static var laneRadius: CGFloat { 14 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(column.tasks) { task in
                        card(for: task)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.automatic)
            .overlay {
                if column.tasks.isEmpty {
                    Text(placeholder)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(lane)
        .dropDestination(for: String.self) { payloads, _ in
            withAnimation(.snappy) { onDrop(payloads, column.status) }
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.15)) { isTargeted = targeted }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(column.status.title), \(column.tasks.count) tasks")
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(column.status.title)
                .font(.system(.headline, design: .rounded))
            Text(column.tasks.count, format: .number)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Theme.hairline, in: Capsule())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func card(for task: TaskItem) -> some View {
        let id = task.persistentModelID
        return BoardCardView(task: task, emphasis: emphasis(task), isSelected: appState.selectedTaskID == id)
            .onTapGesture { appState.select(task: id) }
            .contextMenu { cardMenu(task) }
            .draggable(TaskBoard.dragPayload(for: task) ?? "") {
                BoardCardView(task: task, emphasis: emphasis(task), isSelected: false)
                    .frame(width: 240)
            }
    }

    /// A soft lane on the panel; it lights up in the accent colour while a card hovers over it.
    private var lane: some View {
        let shape = RoundedRectangle(cornerRadius: Self.laneRadius)
        return shape
            .fill(isTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(Theme.card.opacity(0.4)))
            .overlay {
                shape.strokeBorder(
                    isTargeted ? Color.accentColor.opacity(0.7) : Theme.hairline,
                    lineWidth: isTargeted ? 1.5 : 1
                )
            }
    }

    private var symbol: String {
        switch column.status {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch column.status {
        case .todo: .secondary
        case .inProgress: .orange
        case .done: .green
        }
    }

    private var placeholder: String {
        switch column.status {
        case .todo: "Nothing to start"
        case .inProgress: "Drag a card here when you start it"
        case .done: "Tasks finished in the last week show up here"
        }
    }
}
