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
}
