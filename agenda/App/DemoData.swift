import Foundation
import SwiftData

/// Sample tasks, habits, notes and calendar events for screenshots. Debug builds launched with
/// `-DayloomDemo` use an in-memory store seeded with these and a fixed calendar, so the user's
/// own data and calendars are never shown or touched.
enum DemoData {
    static let launchFlag = "-DayloomDemo"

    static func isEnabled(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        arguments.contains(launchFlag)
        #else
        false
        #endif
    }

    /// Fills the store and returns the task to show in the inspector.
    @discardableResult
    static func seed(_ context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> TaskItem {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset))!
        }
        let weekStart = WeekCalendar(calendar: calendar).interval(containing: now).start
        func weekday(_ index: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: index, to: weekStart)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }

        let work = Tag(name: "Work", color: .blue)
        let home = Tag(name: "Home", color: .green)
        let health = Tag(name: "Health", color: .pink)
        let personal = Tag(name: "Personal", color: .purple)
        [work, home, health, personal].forEach(context.insert)

        func task(
            _ title: String,
            due: Date? = nil,
            start: Date? = nil,
            minutes: Int = 60,
            priority: TaskPriority = .none,
            tags: [Tag] = [],
            meeting: String = "",
            status: TaskStatus = .todo
        ) -> TaskItem {
            let item = TaskItem(title: title, dueDate: due, scheduledStart: start, priority: priority)
            item.scheduledDuration = TimeInterval(minutes * 60)
            item.meetingURL = meeting
            context.insert(item)
            item.tags = tags
            if status != .todo { item.updateStatus(status, at: now, calendar: calendar) }
            return item
        }

        // Today
        let review = task("Design review", due: today, start: at(0, 11), priority: .high, tags: [work],
                          meeting: "https://meet.google.com/kfr-xqzt-vbn")
        review.notes = "Walk through the new onboarding screens and agree on the empty states."
        _ = review.addSubtask(title: "Share the Figma link")
        _ = review.addSubtask(title: "Collect feedback from support")
        _ = review.addSubtask(title: "List open questions")
        review.orderedSubtasks.first?.setCompleted(true, at: now, calendar: calendar)

        let standup = task("Team standup", due: today, start: at(0, 9, 30), minutes: 15, tags: [work],
                           meeting: "https://us05web.zoom.us/j/81234567890?pwd=demo")
        standup.repeatRule = .weekdays
        _ = task("Call with Ana about the launch", due: today, start: at(0, 16), minutes: 30, priority: .medium,
                 tags: [work], meeting: "https://teams.live.com/meet/9312345678901")
        _ = task("Write release notes", due: today, priority: .medium, tags: [work], status: .inProgress)
        _ = task("Buy groceries", due: today, tags: [home])
        _ = task("Evening run", due: today, start: at(0, 18, 30), minutes: 45, tags: [health])
        _ = task("Pay the electricity bill", due: day(-1), priority: .high, tags: [home])
        _ = task("Send the invoice to Acme", due: today, tags: [work], status: .done)

        // Later this week and beyond
        _ = task("Sprint planning", start: weekday(0, 10), minutes: 90, tags: [work],
                 meeting: "https://meet.google.com/abc-defg-hij")
        _ = task("1:1 with Sam", start: weekday(1, 14), minutes: 30, tags: [work],
                 meeting: "https://us05web.zoom.us/j/89876543210")
        _ = task("Product demo", start: weekday(3, 15), minutes: 60, priority: .high, tags: [work],
                 meeting: "https://meet.google.com/xyz-abcd-efg")
        _ = task("Retrospective", start: weekday(4, 14, 30), minutes: 60, tags: [work])
        _ = task("Book the dentist", due: day(1), tags: [health])
        _ = task("Plan the weekend trip", due: day(3), tags: [personal])
        _ = task("Renew passport", due: day(8), priority: .medium, tags: [personal])
        _ = task("Water the plants", due: day(2), tags: [home])
        _ = task("Read about SwiftData migrations", tags: [work])
        _ = task("Ideas for Mom's birthday", tags: [personal])

        // Habits with a few weeks of history, so streaks show.
        let habits = [
            Habit(name: "Read 20 pages", symbolName: "book.fill", color: .orange, createdAt: day(-30)),
            Habit(name: "Drink water", symbolName: "drop.fill", color: .blue, createdAt: day(-30)),
            Habit(name: "Meditate", symbolName: "leaf.fill", color: .green, createdAt: day(-30)),
            Habit(name: "Walk 8,000 steps", symbolName: "figure.walk", color: .pink, days: .weekdays, createdAt: day(-30)),
        ]
        habits.forEach(context.insert)
        for offset in 1...20 {
            if offset % 7 != 3 { habits[0].toggle(on: day(-offset), calendar: calendar) }
            habits[1].toggle(on: day(-offset), calendar: calendar)
            if offset % 3 != 0 { habits[2].toggle(on: day(-offset), calendar: calendar) }
            if offset % 4 != 1 { habits[3].toggle(on: day(-offset), calendar: calendar) }
        }
        habits[1].toggle(on: today, calendar: calendar)

        // Notes
        let plan = Note(title: "Weekly plan", createdAt: day(-2))
        plan.isPinned = true
        context.insert(plan)
        _ = plan.appendBlock(.heading, text: "Focus")
        _ = plan.appendBlock(.bullet, text: "Ship the onboarding redesign")
        _ = plan.appendBlock(.bullet, text: "Prepare Thursday's product demo")
        _ = plan.appendBlock(.heading, text: "This week")
        plan.appendBlock(.checklist, text: "Draft the launch email").isChecked = true
        _ = plan.appendBlock(.checklist, text: "Review analytics dashboard")
        _ = plan.appendBlock(.checklist, text: "Clean up the backlog")
        plan.appendBlock(.task).task = review

        let ideas = Note(title: "Launch ideas", createdAt: day(-5))
        context.insert(ideas)
        _ = ideas.appendBlock(.text, text: "Short video tour of the new calendar views.")
        _ = ideas.appendBlock(.bullet, text: "Invite beta users to a live Q&A")
        _ = ideas.appendBlock(.bullet, text: "Write a post about weaving tasks and calendar together")

        let reading = Note(title: "Reading list", createdAt: day(-9))
        context.insert(reading)
        _ = reading.appendBlock(.checklist, text: "Shape Up")
        _ = reading.appendBlock(.checklist, text: "The Design of Everyday Things")

        // Meetings earlier this week already happened.
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        for item in tasks where !item.isDone {
            if let start = item.scheduledStart, start < today { item.setCompleted(true, at: start, calendar: calendar) }
        }

        try? context.save()
        return review
    }

    /// A fixed calendar around `now`: meetings, personal plans and all-day events.
    static func calendarSource(now: Date = .now, calendar: Calendar = .current) -> StaticCalendarSource {
        let weekStart = WeekCalendar(calendar: calendar).interval(containing: now).start
        func at(_ dayIndex: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: dayIndex, to: weekStart)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }
        let workTint = EntryTint.rgb(red: 0.36, green: 0.42, blue: 0.95)
        let homeTint = EntryTint.rgb(red: 0.20, green: 0.70, blue: 0.45)
        let familyTint = EntryTint.rgb(red: 0.93, green: 0.45, blue: 0.32)

        var index = 0
        func event(_ title: String, _ start: Date, _ minutes: Int, _ tint: EntryTint, _ calendarName: String,
                   allDay: Bool = false, location: String? = nil, meeting: String? = nil) -> CalendarEntry {
            index += 1
            let end = allDay ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))!
                             : start.addingTimeInterval(TimeInterval(minutes * 60))
            return CalendarEntry(
                id: "demo-event-\(index)", title: title,
                start: allDay ? calendar.startOfDay(for: start) : start, end: end,
                isAllDay: allDay, kind: .event, tint: tint, calendarName: calendarName,
                location: location, url: meeting.flatMap(URL.init(string:)),
                meetingLink: meeting.flatMap(MeetingLink.init)
            )
        }

        var entries: [CalendarEntry] = []
        for weekOffset in -2...2 {
            let base = weekOffset * 7
            entries += [
                event("Yoga", at(base + 1, 7, 30), 60, homeTint, "Personal", location: "Studio Norte"),
                event("Yoga", at(base + 3, 7, 30), 60, homeTint, "Personal", location: "Studio Norte"),
                event("Team lunch", at(base + 2, 13), 60, workTint, "Work", location: "Café Central"),
                event("Customer call", at(base + 1, 16, 30), 45, workTint, "Work",
                      meeting: "https://us05web.zoom.us/j/84455667788"),
            ]
        }
        entries += [
            event("Architecture sync", at(2, 10), 60, workTint, "Work", meeting: "https://meet.google.com/qwe-rtyu-iop"),
            event("Dinner with friends", at(4, 20), 120, familyTint, "Family", location: "La Taberna"),
            event("Mom's birthday", at(5, 0), 0, familyTint, "Family", allDay: true),
            event("Design conference", at(9, 0), 0, workTint, "Work", allDay: true),
            event("Design conference", at(10, 0), 0, workTint, "Work", allDay: true),
            event("Quarterly review", at(-4, 11), 90, workTint, "Work"),
            event("Dentist", at(8, 17), 45, familyTint, "Family", location: "Clínica Dental"),
        ]
        return StaticCalendarSource(access: .granted, entries: entries)
    }
}
