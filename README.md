# Dayloom

A native macOS planner that keeps your tasks, calendar, habits and notes in one window, synced across your Macs through iCloud.

## Features

- **Tasks**: Inbox, Today, Upcoming and Completed lists, tags, and a status board.
- **Calendar**: a week view with your calendar events next to your scheduled tasks.
- **Quick Launcher**: capture tasks from anywhere with a global hotkey.
- **Habits**: daily habits with streaks, plus recurring tasks.
- **Notes**: block-based notes with headings, lists, checklists, linked tasks and calendar events, plus a daily note.
- **iCloud sync**: all data syncs through your private iCloud database. Settings (⌘,) shows the sync status.

## Keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| New task | ⌘N |
| New note | ⇧⌘N |
| Quick Launcher (in app) | ⌘K |
| Quick Launcher (anywhere) | ⌃⌥Space |
| Show or hide the inspector | ⌥⌘I |
| Calendar, Inbox, Today, Upcoming, Completed, Habits, Notes | ⌘1 to ⌘7 |
| Previous week, next week, back to today | ⌘←, ⌘→, ⌘T |

## Requirements

- macOS 27.2 or later
- Xcode 27 to build

## Building

Open `agenda.xcodeproj` in Xcode and run the `agenda` scheme. The project and its folders keep their original `agenda` name; the app itself is called Dayloom.

iCloud sync needs a build signed with a team that has the iCloud container `iCloud.com.juancasanueva.agenda`. Without that entitlement the app still runs and keeps your data on this Mac only.

## Tests

```sh
xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests
```

## License

MIT. See [LICENSE.md](LICENSE.md).
