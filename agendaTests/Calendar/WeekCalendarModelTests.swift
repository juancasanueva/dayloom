import Foundation
import Testing
@testable import agenda

@MainActor
struct WeekCalendarModelTests {
    private func makeEntry(_ id: String, day: Int) -> CalendarEntry {
        CalendarEntry(
            id: id,
            title: id,
            start: TestClock.date(2026, 11, day, 9),
            end: TestClock.date(2026, 11, day, 10),
            isAllDay: false,
            kind: .event,
            tint: .accent
        )
    }

    private func makeModel(access: CalendarAccess) -> (WeekCalendarModel, StaticCalendarSource) {
        let source = StaticCalendarSource(
            access: access,
            entries: [makeEntry("This week", day: 18), makeEntry("Next week", day: 25)]
        )
        let model = WeekCalendarModel(
            source: source,
            week: WeekCalendar(calendar: TestClock.calendar),
            anchor: TestClock.now
        )
        return (model, source)
    }

    @Test func reloadLoadsOnlyTheVisibleWeek() {
        let (model, _) = makeModel(access: .granted)

        model.reload()

        #expect(model.events.map(\.id) == ["This week"])
    }

    @Test func navigatingWeeksReloadsEvents() {
        let (model, _) = makeModel(access: .granted)

        model.showNextWeek()
        #expect(model.events.map(\.id) == ["Next week"])
        #expect(model.days.first == TestClock.date(2026, 11, 23))

        model.showPreviousWeek()
        #expect(model.events.map(\.id) == ["This week"])

        model.showNextWeek()
        model.showToday(TestClock.now)
        #expect(model.days.first == TestClock.date(2026, 11, 16))
    }

    @Test func deniedAccessShowsNoEvents() {
        let (model, _) = makeModel(access: .denied)

        model.reload()

        #expect(model.access == .denied)
        #expect(model.events.isEmpty)
    }

    @Test func grantingAccessLoadsEvents() async {
        let (model, source) = makeModel(access: .notDetermined)
        model.reload()
        #expect(model.events.isEmpty)

        source.access = .granted
        await model.requestAccess()

        #expect(model.access == .granted)
        #expect(model.events.map(\.id) == ["This week"])
    }

    @Test func createEventSavesAndReloadsTheWeek() throws {
        let (model, source) = makeModel(access: .granted)
        model.reload()

        try model.createEvent(
            title: "Review",
            start: TestClock.date(2026, 11, 19, 14),
            end: TestClock.date(2026, 11, 19, 15),
            isAllDay: false
        )

        let created = try #require(source.entries.last)
        #expect(source.entries.count == 3)
        #expect(created.title == "Review")
        #expect(created.start == TestClock.date(2026, 11, 19, 14))
        #expect(created.end == TestClock.date(2026, 11, 19, 15))
        #expect(!created.isAllDay)
        #expect(model.events.map(\.id) == ["This week", created.id])
    }

    @Test func createEventWithoutAccessThrowsAndKeepsEvents() {
        let (model, source) = makeModel(access: .denied)

        #expect(throws: CalendarWriteError.accessDenied) {
            try model.createEvent(
                title: "Review",
                start: TestClock.date(2026, 11, 19, 14),
                end: TestClock.date(2026, 11, 19, 15),
                isAllDay: false
            )
        }
        #expect(source.entries.count == 2)
    }

    @Test func eventsOnADayIgnoreTheVisibleWeek() {
        let (model, _) = makeModel(access: .granted)

        #expect(model.events(on: TestClock.date(2026, 11, 25, 15)).map(\.id) == ["Next week"])
        #expect(model.events(on: TestClock.date(2026, 11, 24)).isEmpty)
        #expect(model.events.isEmpty) // The visible week isn't loaded or changed.
    }

    @Test func eventsOnADayNeedAccess() {
        let (model, _) = makeModel(access: .denied)

        #expect(model.events(on: TestClock.date(2026, 11, 18)).isEmpty)
    }
}
