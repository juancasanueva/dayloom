import SwiftData
import SwiftUI

enum HabitEditorTarget: Identifiable {
    case new
    case edit(Habit)

    enum ID: Hashable {
        case new
        case habit(PersistentIdentifier)
    }

    var id: ID {
        switch self {
        case .new: .new
        case .edit(let habit): .habit(habit.persistentModelID)
        }
    }
}

/// Creates or edits a habit. Changes apply only when saved.
struct HabitEditorSheet: View {
    let target: HabitEditorTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbolName: String
    @State private var color: TagColor
    @State private var days: HabitDays
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFocused: Bool

    private let calendar = Calendar.current

    static let symbols = [
        "checkmark", "drop.fill", "figure.walk", "figure.run", "dumbbell.fill", "bed.double.fill",
        "book.fill", "pencil", "brain.head.profile", "leaf.fill", "fork.knife", "music.note",
        "sun.max.fill", "heart.fill", "pills.fill", "dollarsign.circle",
    ]

    init(target: HabitEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _name = State(initialValue: "")
            _symbolName = State(initialValue: Self.symbols[0])
            _color = State(initialValue: .blue)
            _days = State(initialValue: .everyDay)
        case .edit(let habit):
            _name = State(initialValue: habit.name)
            _symbolName = State(initialValue: habit.symbolName)
            _color = State(initialValue: habit.color)
            _days = State(initialValue: habit.days)
        }
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !days.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            EditorSection("Name") {
                TextField("Name", text: $name, prompt: Text("Drink water"))
                    .textFieldStyle(.plain)
                    .focused($isNameFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isNameFocused ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: 1)
                    }
            }
            EditorSection("Icon") { symbolGrid }
            EditorSection("Color") { colorRow }
            EditorSection("Repeat On") { weekdayPicker }
        }
        .padding(20)
        .frame(width: 440)
        .background(Theme.panel)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add Habit" : "Save", action: save)
                    .disabled(!canSave)
            }
            if case .edit = target {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Habit", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .confirmationDialog("Delete this habit?", isPresented: $isConfirmingDelete) {
            Button("Delete Habit", role: .destructive, action: delete)
        } message: {
            Text("Its check-in history will be deleted too.")
        }
    }

    /// Title with a live preview of the habit's icon and name.
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color.color)
                .frame(width: 44, height: 44)
                .background(color.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(isNew ? "New Habit" : "Edit Habit")
                    .font(Theme.sectionTitle)
                Text(trimmedName.isEmpty ? "A routine to keep, one day at a time" : trimmedName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Controls

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(Self.symbols, id: \.self) { symbol in
                let isSelected = symbol == symbolName
                Button {
                    symbolName = symbol
                } label: {
                    Image(systemName: symbol)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(isSelected ? color.color : Color.secondary)
                        .background(isSelected ? color.color.opacity(0.18) : Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? color.color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var colorRow: some View {
        HStack(spacing: 8) {
            ForEach(TagColor.allCases) { option in
                let isSelected = option == color
                Button {
                    color = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                        .padding(3)
                        .overlay(Circle().strokeBorder(isSelected ? option.color : Color.clear, lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue.capitalized)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    let isOn = days.contains(weekday: weekday)
                    Button {
                        days.formSymmetricDifference(HabitDays(weekday: weekday))
                    } label: {
                        Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                            .font(.callout.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .background(isOn ? AnyShapeStyle(color.color) : AnyShapeStyle(Theme.card), in: Circle())
                            .overlay(Circle().strokeBorder(isOn ? Color.clear : Theme.hairline, lineWidth: 1))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            HStack(spacing: 6) {
                Button("Every Day") { days = .everyDay }
                    .disabled(days == .everyDay)
                Button("Weekdays") { days = .weekdays }
                    .disabled(days == .weekdays)
            }
            .buttonStyle(PageControlStyle(horizontalPadding: 10))
            .controlSize(.small)
            if days.isEmpty {
                Text("Pick at least one day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Calendar weekday numbers (1 = Sunday) starting from the user's first weekday.
    private var orderedWeekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    // MARK: Actions

    private func save() {
        guard canSave else { return }
        switch target {
        case .new:
            modelContext.insert(Habit(name: trimmedName, symbolName: symbolName, color: color, days: days))
        case .edit(let habit):
            habit.name = trimmedName
            habit.symbolName = symbolName
            habit.color = color
            habit.days = days
        }
        dismiss()
    }

    private func delete() {
        if case .edit(let habit) = target {
            modelContext.delete(habit)
        }
        dismiss()
    }
}

/// A small caption over a group of fields in the editor.
private struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}
