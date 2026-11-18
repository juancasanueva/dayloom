import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("List or board, per list")
struct TaskLayoutStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "TaskLayoutStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func everyListStartsAsAList() {
        let store = TaskLayoutStore(defaults: makeDefaults())

        #expect(store.layout(for: .inbox) == .list)
        #expect(store.layout(for: .today) == .list)
        #expect(store.layout(for: .upcoming) == .list)
    }

    @Test func inboxTodayAndUpcomingEachKeepTheirOwnLayout() {
        let store = TaskLayoutStore(defaults: makeDefaults())

        store.setLayout(.board, for: .today)

        #expect(store.layout(for: .today) == .board)
        #expect(store.layout(for: .inbox) == .list)
        #expect(store.layout(for: .upcoming) == .list)

        store.setLayout(.board, for: .upcoming)
        store.setLayout(.list, for: .today)

        #expect(store.layout(for: .today) == .list)
        #expect(store.layout(for: .upcoming) == .board)
        #expect(store.layout(for: .inbox) == .list)
    }

    @Test func choicesAreRememberedAcrossLaunches() {
        let defaults = makeDefaults()
        let store = TaskLayoutStore(defaults: defaults)
        store.setLayout(.board, for: .inbox)
        store.setLayout(.board, for: .upcoming)

        let relaunched = TaskLayoutStore(defaults: defaults)

        #expect(relaunched.layout(for: .inbox) == .board)
        #expect(relaunched.layout(for: .today) == .list)
        #expect(relaunched.layout(for: .upcoming) == .board)
    }

    @Test func listsStartFromTheChoiceMadeBeforeTheyWereSeparate() {
        let defaults = makeDefaults()
        defaults.set(TaskLayout.board.rawValue, forKey: TaskLayout.storageKey)

        let store = TaskLayoutStore(defaults: defaults)

        #expect(store.layout(for: .inbox) == .board)
        #expect(store.layout(for: .today) == .board)
        #expect(store.layout(for: .upcoming) == .board)

        store.setLayout(.list, for: .today)
        #expect(store.layout(for: .today) == .list)
        #expect(store.layout(for: .inbox) == .board)
    }

    @Test func tagListsShareOneLayout() throws {
        let context = try makeInMemoryContext()
        let work = agenda.Tag(name: "Work", color: .blue)
        let home = agenda.Tag(name: "Home", color: .green)
        context.insert(work)
        context.insert(home)
        try context.save()
        let store = TaskLayoutStore(defaults: makeDefaults())

        store.setLayout(.board, for: .tag(work.persistentModelID))

        #expect(store.layout(for: .tag(home.persistentModelID)) == .board)
        #expect(store.layout(for: .inbox) == .list)
    }

    @Test func completedAlwaysShowsTheList() {
        let store = TaskLayoutStore(defaults: makeDefaults())

        store.setLayout(.board, for: .completed)

        #expect(store.layout(for: .completed) == .list)
        #expect(store.layout(for: .inbox) == .list)
    }
}
