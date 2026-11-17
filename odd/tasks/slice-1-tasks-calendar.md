# Slice 1 — Tasks + Calendar core

Objective: first usable slice of a native macOS daily planner (tasks + week calendar). Branch: `feat/slice-1-tasks-calendar`.
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests` (Swift Testing).

## Specs

- S1 — Sidebar with "Inbox / Today / Upcoming / Tags" (plus Calendar entry and Completed list).
- S2 — "tasks with subtasks, due dates, priorities and status".
- S3 — "a week view that shows your Apple Calendar events (EventKit) next to scheduled tasks".
- S4 — Own original design, naming, and copy; no reference to any other product in code or docs.
- S5 — Data stored locally with SwiftData; models kept CloudKit-compatible (optional/defaulted attributes, optional relationships) so a later slice can add iCloud sync. (Assumption: forward-compatibility only, no sync in this slice.)
- S6 — Out of scope for this slice: notes editor, Kanban, habits, Quick Launcher, iCloud sync, AI features.

Smart list rules (assumptions derived from S1):
- Inbox: open top-level tasks with no due date and no scheduled time.
- Today: open top-level tasks due today or overdue, or scheduled today.
- Upcoming: open top-level tasks whose due/scheduled day is after today, grouped by day.
- Completed: done tasks, most recently completed first.
- Tag: open top-level tasks carrying that tag.
- Ordering inside a list: priority (high first), then earliest date, then creation order.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S2, S5 | inline | done | RED: missing PlannerSchema; GREEN: 17 tests pass |
| T2 | S1, S2 | inline | done | build green; app run: quick add, ⌘N focus, Today badge verified on screen |
| T3 | S3 | inline | done | RED: missing WeekCalendar/CalendarEntry; GREEN: 31 tests; app run: week grid, double-click creates scheduled task |
| T4 | S1–S4 | inline | done | app run: inspector opens from calendar block; 0 reference-name mentions |

- T1 — Domain: `TaskItem`, `Tag`, status/priority, completion rules, smart-list query (tests first).
- T2 — Tasks UI: sidebar, task list with quick add, inspector detail with subtasks/tags.
- T3 — Calendar: EventKit provider + entitlements, week layout math (tests first), week view with events and scheduled tasks.
- T4 — App shell wiring, commands, template cleanup, full build + suite.

Route evidence: no Writer trigger (units share `TaskItem` and the root view; not independent), parent writes inline.

## Log

- L1 (2026-11-17, user): "I want to create a MAcOS app that is an exact copy of this app [reference app URL redacted] but do not mention [reference app] in any docs or code." → agreed scope: similar feature set, original design (S4).
- L2 (2026-11-17, user): "go with slice 1" (Slice 1: Tasks + Calendar core).
- L3: Baseline `dccc66a` on `master`; unit test baseline green.
- L4: T1–T4 implemented. Bugs found by running the app and fixed: inspector missed freshly saved tasks (registeredModel → fetch by ID); weekday headers wrapped; zero-padded hour labels; toolbar drifted over inspector.
- L5: Not verified: real EventKit events (needs the user to grant calendar access interactively); tag and subtask UI flows driven only through domain tests.
