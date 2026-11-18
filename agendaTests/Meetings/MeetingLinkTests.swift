import Foundation
import SwiftData
import Testing
@testable import agenda

@Suite("Meeting links")
struct MeetingLinkTests {
    @Test(arguments: [
        ("https://meet.google.com/abc-defg-hij", MeetingProvider.googleMeet),
        ("https://us02web.zoom.us/j/123456789?pwd=secret", .zoom),
        ("https://zoom.us/j/987654321", .zoom),
        ("https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0", .teams),
        ("https://teams.live.com/meet/9876543210", .teams),
        ("https://acme.webex.com/meet/jane", .webex),
        ("https://whereby.com/team-room", .other),
    ])
    func recognizesTheService(link: String, provider: MeetingProvider) throws {
        let meeting = try #require(MeetingLink(link))
        #expect(meeting.provider == provider)
        #expect(meeting.url.absoluteString == link)
    }

    @Test func namesTheJoinButtonAfterTheService() throws {
        #expect(try #require(MeetingLink("https://meet.google.com/abc-defg-hij")).joinTitle == "Join Google Meet")
        #expect(try #require(MeetingLink("https://zoom.us/j/1")).joinTitle == "Join Zoom")
        #expect(try #require(MeetingLink("https://teams.live.com/meet/1")).joinTitle == "Join Teams")
        #expect(try #require(MeetingLink("https://whereby.com/room")).joinTitle == "Join Call")
    }

    @Test func acceptsALinkPastedWithoutItsScheme() throws {
        let meeting = try #require(MeetingLink("  meet.google.com/abc-defg-hij \n"))
        #expect(meeting.url.absoluteString == "https://meet.google.com/abc-defg-hij")
        #expect(meeting.provider == .googleMeet)
    }

    @Test(arguments: ["", "   ", "standup", "mailto:jane@example.com", "ftp://files.example.com/a", "https://"])
    func rejectsWhatIsNotAWebLink(text: String) {
        #expect(MeetingLink(text) == nil)
    }

    @Test func findsAKnownMeetingInEventText() throws {
        let notes = """
        Agenda: https://docs.example.com/plan
        Join Zoom Meeting
        https://us02web.zoom.us/j/123456789?pwd=secret
        """
        let meeting = try #require(MeetingLink.find(in: [nil, "Room 4", notes]))
        #expect(meeting.provider == .zoom)
        #expect(meeting.url.absoluteString == "https://us02web.zoom.us/j/123456789?pwd=secret")
    }

    @Test func eventTextWithoutAKnownServiceHasNoMeeting() {
        #expect(MeetingLink.find(in: ["https://docs.example.com/plan", "Room 4", nil]) == nil)
    }

    @Test func zoomMeetingsOpenInTheZoomApp() throws {
        let meeting = try #require(MeetingLink("https://us02web.zoom.us/j/123456789?pwd=secret"))
        #expect(meeting.appURL?.absoluteString == "zoommtg://zoom.us/join?action=join&confno=123456789&pwd=secret")

        let withoutPassword = try #require(MeetingLink("https://zoom.us/j/987654321"))
        #expect(withoutPassword.appURL?.absoluteString == "zoommtg://zoom.us/join?action=join&confno=987654321")
    }

    @Test func teamsMeetingsOpenInTheTeamsApp() throws {
        let meeting = try #require(MeetingLink("https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=x"))
        #expect(meeting.appURL?.absoluteString == "msteams:/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=x")
    }

    @Test func otherMeetingsOpenInTheBrowser() throws {
        #expect(try #require(MeetingLink("https://meet.google.com/abc-defg-hij")).appURL == nil)
        #expect(try #require(MeetingLink("https://zoom.us/my/jane")).appURL == nil)
        #expect(try #require(MeetingLink("https://whereby.com/room")).appURL == nil)
    }
}

@MainActor
struct TaskMeetingTests {
    @Test func aTaskWithALinkIsAVideoCall() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Standup")
        context.insert(task)
        #expect(task.meetingLink == nil)

        task.meetingURL = "https://meet.google.com/abc-defg-hij"

        #expect(task.meetingLink?.provider == .googleMeet)
    }

    @Test func aRepeatingCallKeepsItsLinkOnTheNextOccurrence() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Standup", scheduledStart: TestClock.date(2026, 11, 17, 9))
        task.repeatRule = .daily
        task.meetingURL = "https://meet.google.com/abc-defg-hij"
        context.insert(task)

        task.setCompleted(true, at: TestClock.now, calendar: TestClock.calendar)

        let all = try context.fetch(FetchDescriptor<TaskItem>())
        let next = try #require(all.first { !$0.isDone })
        #expect(next.meetingURL == "https://meet.google.com/abc-defg-hij")
    }

    @Test func scheduledTasksCarryTheirMeetingToTheCalendar() throws {
        let context = try makeInMemoryContext()
        let task = TaskItem(title: "Standup", scheduledStart: TestClock.date(2026, 11, 17, 9))
        task.meetingURL = "https://zoom.us/j/987654321"
        context.insert(task)

        let entries = CalendarEntry.scheduledTasks(
            [task],
            in: DateInterval(start: TestClock.date(2026, 11, 17), end: TestClock.date(2026, 11, 18))
        )

        #expect(entries.map(\.meetingLink?.provider) == [.zoom])
    }
}

@Suite("New Teams meeting")
struct TeamsMeetingStarterTests {
    @Test func opensTheTeamsAppWhenItIsInstalled() {
        #expect(TeamsMeetingStarter.destination(appInstalled: true).absoluteString == "msteams:")
    }

    @Test func opensTeamsOnTheWebOtherwise() {
        #expect(TeamsMeetingStarter.destination(appInstalled: false).absoluteString == "https://teams.live.com/")
    }

    @Test func aPastedTeamsLinkIsAJoinableTeamsMeeting() throws {
        let meeting = try #require(MeetingLink("https://teams.live.com/meet/9312345678901?p=AbCdEf"))
        #expect(meeting.provider == .teams)
        #expect(meeting.joinTitle == "Join Teams")
    }
}
