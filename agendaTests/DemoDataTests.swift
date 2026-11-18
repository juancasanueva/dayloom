import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Demo data for screenshots")
struct DemoDataTests {
    @Test func isOffWithoutTheLaunchFlag() {
        #expect(!DemoData.isEnabled(arguments: ["Dayloom"]))
        #expect(DemoData.isEnabled(arguments: ["Dayloom", "-DayloomDemo"]))
    }

    @Test func seedsEveryScreenAndFeaturesAVideoCall() throws {
        let context = try makeInMemoryContext()

        let featured = DemoData.seed(context, now: TestClock.now, calendar: TestClock.calendar)

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count >= 10)
        #expect(featured.meetingLink?.provider == .googleMeet)
        #expect(!featured.orderedSubtasks.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Habit>()).count >= 3)
        #expect(try context.fetch(FetchDescriptor<Note>()).count >= 2)
        #expect(try context.fetch(FetchDescriptor<agenda.Tag>()).count >= 3)
    }

    @Test func calendarEventsFillTheWeekOfTheGivenDay() {
        let source = DemoData.calendarSource(now: TestClock.now, calendar: TestClock.calendar)
        let week = WeekCalendar(calendar: TestClock.calendar).interval(containing: TestClock.now)

        let events = source.events(in: week)

        #expect(events.count >= 6)
        #expect(events.contains { $0.isAllDay })
        #expect(events.contains { $0.meetingLink != nil })
    }
}
