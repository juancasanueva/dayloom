import Foundation
import SwiftData
@testable import agenda

/// Deterministic calendar and clock shared by the domain tests.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    /// Tuesday 2026-11-17 10:00 UTC.
    static let now = date(2026, 11, 17, 10, 0)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

@MainActor
func makeInMemoryContext() throws -> ModelContext {
    // The app's in-memory configuration never syncs. A bare in-memory configuration would
    // default to `.automatic` and mirror test data to iCloud in builds with the entitlement.
    let container = try ModelContainer(
        for: PlannerSchema.schema,
        configurations: PlannerSchema.configuration(inMemory: true)
    )
    return ModelContext(container)
}
