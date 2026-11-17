import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Merging sync duplicates")
struct DuplicateMergerTests {
    let merger = DuplicateMerger(calendar: TestClock.calendar)

    private func makeTag(_ name: String, createdAt: Date, color: TagColor = .blue, in context: ModelContext) -> agenda.Tag {
        let tag = agenda.Tag(name: name, color: color)
        tag.createdAt = createdAt
        context.insert(tag)
        return tag
    }

    private func makeDailyNote(_ day: Date, createdAt: Date, blocks: [(NoteBlockKind, String)], in context: ModelContext) -> Note {
        let note = Note(title: "Day", createdAt: createdAt)
        note.dailyDate = day
        context.insert(note)
        for (kind, text) in blocks {
            note.appendBlock(kind, text: text)
        }
        return note
    }

    // MARK: Tags (S2.1)

    @Test func tagsWithSameNameMergeIntoOldest() throws {
        let context = try makeInMemoryContext()
        let oldest = makeTag("Work", createdAt: TestClock.date(2026, 1, 1), color: .green, in: context)
        let copy = makeTag(" work ", createdAt: TestClock.date(2026, 2, 1), color: .red, in: context)
        let other = makeTag("Home", createdAt: TestClock.date(2026, 3, 1), in: context)
        let first = TaskItem(title: "Report")
        let second = TaskItem(title: "Slides")
        [first, second].forEach(context.insert)
        first.tags = [oldest]
        second.tags = [copy]
        try context.save()

        let report = merger.mergeDuplicates(in: context)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<agenda.Tag>(sortBy: [SortDescriptor(\.name)]))
        #expect(tags.map(\.name) == ["Home", "Work"])
        #expect(tags.contains { $0 === oldest })
        #expect(tags.contains { $0 === other })
        #expect(oldest.color == .green)
        #expect(Set((oldest.tasks ?? []).map(\.title)) == ["Report", "Slides"])
        #expect(second.orderedTags.map(\.name) == ["Work"])
        #expect(report.tags == 1)
    }

    @Test func taskTaggedWithBothCopiesKeepsOneTag() throws {
        let context = try makeInMemoryContext()
        let oldest = makeTag("Work", createdAt: TestClock.date(2026, 1, 1), in: context)
        let copy = makeTag("Work", createdAt: TestClock.date(2026, 2, 1), in: context)
        let task = TaskItem(title: "Report")
        context.insert(task)
        task.tags = [oldest, copy]
        try context.save()

        merger.mergeDuplicates(in: context)
        try context.save()

        #expect(task.orderedTags.count == 1)
        #expect(task.orderedTags.first === oldest)
    }

    // MARK: Daily notes (S2.2)

    @Test func dailyNotesForSameDayMergeIntoOldest() throws {
        let context = try makeInMemoryContext()
        let day = TestClock.date(2026, 11, 17)
        let oldest = makeDailyNote(day, createdAt: TestClock.date(2026, 11, 17, 7), blocks: [(.text, "Morning")], in: context)
        let copy = makeDailyNote(day, createdAt: TestClock.date(2026, 11, 17, 8), blocks: [(.text, ""), (.checklist, "Call mom"), (.text, "Evening")], in: context)
        copy.isPinned = true
        let tomorrow = makeDailyNote(TestClock.date(2026, 11, 18), createdAt: TestClock.date(2026, 11, 17, 9), blocks: [(.text, "Plan")], in: context)
        try context.save()

        let report = merger.mergeDuplicates(in: context)
        try context.save()

        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 2)
        #expect(notes.contains { $0 === oldest })
        #expect(notes.contains { $0 === tomorrow })
        #expect(oldest.orderedBlocks.map(\.text) == ["Morning", "Call mom", "Evening"])
        #expect(oldest.orderedBlocks.map(\.kind) == [.text, .checklist, .text])
        #expect(oldest.isPinned)
        #expect(try context.fetch(FetchDescriptor<NoteBlock>()).count == 4)
        #expect(report.dailyNotes == 1)
    }

    @Test func mergedTaskBlockKeepsItsTask() throws {
        let context = try makeInMemoryContext()
        let day = TestClock.date(2026, 11, 17)
        let oldest = makeDailyNote(day, createdAt: TestClock.date(2026, 11, 17, 7), blocks: [], in: context)
        let copy = makeDailyNote(day, createdAt: TestClock.date(2026, 11, 17, 8), blocks: [(.checklist, "Pay rent")], in: context)
        let task = NoteEditor(now: TestClock.now, calendar: TestClock.calendar).convertToTask(copy.orderedBlocks[0], in: context)
        try context.save()

        merger.mergeDuplicates(in: context)
        try context.save()

        #expect(oldest.orderedBlocks.map(\.kind) == [.task])
        #expect(oldest.orderedBlocks.first?.task === task)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
    }

    @Test func regularNotesAreNeverMerged() throws {
        let context = try makeInMemoryContext()
        let first = Note(title: "Ideas", createdAt: TestClock.date(2026, 1, 1))
        let second = Note(title: "Ideas", createdAt: TestClock.date(2026, 1, 2))
        [first, second].forEach(context.insert)
        try context.save()

        #expect(merger.mergeDuplicates(in: context).dailyNotes == 0)
        #expect(try context.fetch(FetchDescriptor<Note>()).count == 2)
    }

    // MARK: Habit completions (S2.3, S2.4)

    /// Copies carry nothing that lets every Mac pick the same survivor, so deleting them could
    /// remove a different copy on each Mac and lose the tick. They stay, and count once.
    @Test func sameDayCompletionsAreLeftAloneAndCountOnce() throws {
        let context = try makeInMemoryContext()
        let habit = Habit(name: "Run", createdAt: TestClock.date(2026, 11, 1))
        context.insert(habit)
        for date in [TestClock.date(2026, 11, 16), TestClock.date(2026, 11, 16), TestClock.date(2026, 11, 17)] {
            let completion = HabitCompletion(day: date)
            context.insert(completion)
            completion.habit = habit
        }
        try context.save()

        merger.mergeDuplicates(in: context)

        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<HabitCompletion>()).count == 3)
        #expect(habit.isCompleted(on: TestClock.date(2026, 11, 16), calendar: TestClock.calendar))
        #expect(habit.currentStreak(asOf: TestClock.now, calendar: TestClock.calendar) == 2)
    }

    @Test func untickingRemovesEveryCompletionOfTheDay() throws {
        let context = try makeInMemoryContext()
        let habit = Habit(name: "Run", createdAt: TestClock.date(2026, 11, 1))
        context.insert(habit)
        for _ in 0..<2 {
            let completion = HabitCompletion(day: TestClock.date(2026, 11, 17))
            context.insert(completion)
            completion.habit = habit
        }

        habit.toggle(on: TestClock.now, calendar: TestClock.calendar)

        #expect(!habit.isCompleted(on: TestClock.now, calendar: TestClock.calendar))
        #expect(habit.completions?.isEmpty == true)
    }

    // MARK: No duplicates

    @Test func nothingToMergeChangesNothing() throws {
        let context = try makeInMemoryContext()
        _ = makeTag("Work", createdAt: TestClock.date(2026, 1, 1), in: context)
        _ = makeDailyNote(TestClock.date(2026, 11, 17), createdAt: TestClock.now, blocks: [(.text, "Hi")], in: context)
        try context.save()

        let report = merger.mergeDuplicates(in: context)

        #expect(report == DuplicateMerger.Report())
        #expect(!context.hasChanges)
    }
}
