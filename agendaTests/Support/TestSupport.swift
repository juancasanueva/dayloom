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
    let container = try ModelContainer(
        for: PlannerSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
}
