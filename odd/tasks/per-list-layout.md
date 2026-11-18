# Per-list layout — List or Board chosen separately for Inbox, Today and Upcoming

Objective: each task list remembers its own List or Board choice instead of one app-wide setting. Branch: `main`.
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests` (Swift Testing).

## Specs

User request (L1): "I want the list/3 columns settings to be independent for the Inbox, Today, Upcomming view, so I can choose how to see it in each view independently"

- S1 "independent for the Inbox, Today, Upcomming view": Inbox, Today and Upcoming each keep their own List or Board choice, remembered across launches.
- S2 Tag lists share one choice, and Completed always shows the list (assumption, stated in the reply to L1).
- S3 Each list starts from the previous app-wide choice (`taskLayout`), so nothing changes until a list is switched (assumption, stated in the reply to L1).

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1–S3 | inline | done (TaskLayoutStore, 6 tests; checked in the running app: Inbox List while Today and Upcoming stayed Board) | ccb763e |

## Log

- L1 (2026-11-18) User: "I want the list/3 columns settings to be independent for the Inbox, Today, Upcomming view, so I can choose how to see it in each view independently"
- L2 (2026-11-18) User, after testing the running build: "commit." Committed as ccb763e.
- L3 This document records the request in the repository; the review of the shortcuts work read only odd/tasks/configurable-shortcuts.md and flagged ccb763e as unrequested.
