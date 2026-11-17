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
        VStack(alignment: .leading, spacing: 0) {
            Text(isNew ? "New Habit" : "Edit Habit")
                .font(.headline)
                .padding([.horizontal, .top], 20)

            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Drink water"))
                }
                Section("Icon") { symbolGrid }
                Section("Color") { colorRow }
                Section("Repeat On") { weekdayPicker }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440)
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

    // MARK: Controls

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 8), spacing: 8) {
            ForEach(Self.symbols, id: \.self) { symbol in
                let isSelected = symbol == symbolName
                Button {
                    symbolName = symbol
                } label: {
                    Image(systemName: symbol)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(isSelected ? color.color : Color.secondary)
                        .background(isSelected ? color.color.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var colorRow: some View {
        HStack(spacing: 10) {
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue.capitalized)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    let isOn = days.contains(weekday: weekday)
                    Button {
                        days.formSymmetricDifference(HabitDays(weekday: weekday))
                    } label: {
                        Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                            .font(.callout.weight(.medium))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .background(isOn ? color.color : Color.secondary.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            HStack {
                Button("Every Day") { days = .everyDay }
                    .disabled(days == .everyDay)
                Button("Weekdays") { days = .weekdays }
                    .disabled(days == .weekdays)
            }
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
