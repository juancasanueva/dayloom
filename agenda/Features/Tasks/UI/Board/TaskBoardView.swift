import SwiftData
import SwiftUI

/// Three status columns side by side. Cards are dragged between columns to change their status.
struct TaskBoardView<CardMenu: View>: View {
    let columns: [BoardColumn]
    let isOverdue: (TaskItem) -> Bool
    /// Handles dropped payloads for a column and reports whether anything moved.
    let onDrop: ([String], TaskStatus) -> Bool
    @ViewBuilder let cardMenu: (TaskItem) -> CardMenu

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(columns) { column in
                BoardColumnView(column: column, isOverdue: isOverdue, onDrop: onDrop, cardMenu: cardMenu)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct BoardColumnView<CardMenu: View>: View {
    let column: BoardColumn
    let isOverdue: (TaskItem) -> Bool
    let onDrop: ([String], TaskStatus) -> Bool
    let cardMenu: (TaskItem) -> CardMenu

    @Environment(AppState.self) private var appState
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ScrollView {
                LazyVStack(spacing: 8) {
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
        .background(background)
        .dropDestination(for: String.self) { payloads, _ in
            withAnimation(.snappy) { onDrop(payloads, column.status) }
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.15)) { isTargeted = targeted }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(column.status.title), \(column.tasks.count) tasks")
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(column.status.title)
                .font(.headline)
            Text(column.tasks.count, format: .number)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func card(for task: TaskItem) -> some View {
        let id = task.persistentModelID
        return BoardCardView(task: task, isOverdue: isOverdue(task), isSelected: appState.selectedTaskID == id)
            .onTapGesture { appState.select(task: id) }
            .contextMenu { cardMenu(task) }
            .draggable(TaskBoard.dragPayload(for: task) ?? "") {
                BoardCardView(task: task, isOverdue: isOverdue(task), isSelected: false)
                    .frame(width: 240)
            }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isTargeted ? AnyShapeStyle(tint.opacity(0.14)) : AnyShapeStyle(.quaternary.opacity(0.5)))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(isTargeted ? 0.7 : 0), lineWidth: 2)
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
