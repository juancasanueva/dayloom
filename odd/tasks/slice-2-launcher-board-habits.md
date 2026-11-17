# Slice 2 — Quick Launcher, Board, Habits

Objective: keyboard-first capture, a status board for tasks, and habits/recurring tasks. Branch: `feat/slice-2-launcher-board-habits` (from slice 1 head `50f2ec9`).
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests -derivedDataPath <scratch>` (Swift Testing).

## Specs

Agreed scope (assistant proposal accepted by the user, L2): "Slice 2, the ⌘-shortcut Quick Launcher plus Kanban and habits".
Everything below is detail derived from that line. Assumptions are marked as such.

### S1 — Quick Launcher (search, create tasks, schedule events)
- S1.1 Opens with ⌘K inside the app. It also opens system-wide with ⌃⌥Space while the app runs: the app activates and the launcher appears (assumption on the key combo). The global hotkey uses Carbon `RegisterEventHotKey`, which is sandbox-safe.
- S1.2 It's a centered overlay card over the main window: a text field on top and a result list below. ↑/↓ moves the selection, ↩ runs it, esc closes.
- S1.3 Results, in order:
  1. "New Task" built from the parsed input. It always appears when the text has a title.
  2. "New Event" built from the parsed input. It appears only when calendar access is granted and a date or time was parsed. An event without a time is all-day. With a time, it lasts the parsed duration, or 1 hour by default.
  3. Up to 8 existing tasks whose title contains the query (case- and diacritic-insensitive), open tasks first. Picking one selects it in the inspector.
- S1.4 The input parser is pure, deterministic, and English only (assumption). It recognizes:
  - Dates: `today`, `tomorrow` (also `tmr`), weekday names full or as 3-letter abbreviations (the next occurrence strictly after today), `next week` (next Monday per calendar), `in N days`, `in N weeks`.
  - Times: `3pm`, `3:30pm`, `15:00`, `noon`, `midnight`, optionally preceded by `at`.
  - Duration: `for 30m`, `for 45min`, `for 1h`, `for 1.5h`, `for 90 minutes`.
  - Priority: `!high` / `!!!`, `!medium` / `!med` / `!!`, `!low` / `!`.
  - Tags: `#word`. A missing tag is created when the task is created.
  - The title is the remaining text with recognized tokens removed and whitespace collapsed.
  - A time without a date means today.
- S1.5 Creating a task: time present → `scheduledStart` (+ `scheduledDuration` if given). Date only → `dueDate` (start of day). Priority and tags are applied.
- S1.6 Creating an event writes to the default calendar through EventKit, then the week view reloads.

### S2 — Kanban board
- S2.1 Inbox, Today, Upcoming and tag lists (not Completed) get a toolbar toggle "List / Board". The choice is remembered app-wide.
- S2.2 The board has three columns: To Do, In Progress, Done.
  - To Do and In Progress hold the scope's open tasks, grouped by status, in the same order as the list.
  - Done holds top-level done tasks that would match the scope if they were open, completed within the last 7 days, most recent first.
- S2.3 Dragging a card to another column sets that status (via `TaskItem.updateStatus`). Clicking a card selects it in the inspector. Quick add stays on top and creates To Do tasks.
- S2.4 Cards show the title, due date (red when overdue), scheduled time, a priority flag, subtask progress, and tags.

### S3 — Habits and recurring tasks
- S3.1 Recurring tasks: a task has a repeat rule, one of None, Daily, Weekdays, Weekly, Monthly. When a repeating task with a due date and/or scheduled start becomes done:
  - The app creates the next open occurrence with each date advanced by the rule, copying title, notes, priority, tags, duration, repeat, and subtasks (as open).
  - The completed task's repeat is cleared, so toggling it again never spawns twice.
  - A repeating task with no date spawns nothing.
  - "Weekdays" advances to the next Monday–Friday day.
  - The inspector's Repeat picker is disabled while the task has no date. Rows show a repeat icon.
- S3.2 Habits are their own model with these fields: name, SF Symbol, color (`TagColor`), scheduled weekdays, created date, and completions (one per day).
- S3.3 Habit rules, pure and tested:
  - `isScheduled(on:)`; `isCompleted(on:)`; `toggle(on:)`.
  - `currentStreak(asOf:)` counts consecutive scheduled days completed, going backwards. Unscheduled days are skipped. If today is scheduled but not done yet, counting starts from yesterday instead of resetting to 0.
  - `completionRate` over the last 30 days = completed scheduled days ÷ scheduled days, excluding days before the habit was created.
- S3.4 The Habits screen lists habits. Each row shows the icon, name, a streak (flame + count), and the current week's 7 day circles: toggleable when scheduled and not in the future. There's a create/edit sheet (name, symbol from a small set, color, weekdays with "Every day" / "Weekdays" presets) and delete.
- S3.5 The Today list shows a compact strip of today's scheduled habits with check toggles above the tasks.

### S4 — Carry-over
- S4.1 Original design and copy; no reference to any other product in code or docs.
- S4.2 Schema changes stay CloudKit-compatible: defaults on every attribute, optional relationships, no unique constraints.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1 | delegated (writer A, worktree) | done | RED→GREEN, 69 tests in worktree; merged 5065aca; app run: ⌘K parse+create, search |
| T2 | S2 | delegated (writer B, worktree) | done | RED→GREEN, 44 tests in worktree; merged 9049e20; app run: toggle + real drag To Do→In Progress |
| T3 | S3.1–S3.4 | delegated (writer C, worktree) | done | RED→GREEN, 65 tests in worktree; merged 3375850; app run: create habit, toggle, streak 1 |
| T4 | S1.1, S3.4, S3.5 wiring | inline (parent) | done | 117 tests; app run: ⌃⌥Space from Finder opens launcher; Today habits strip toggles |

Route evidence: Writer trigger (a). T1–T3 are independent units with disjoint edit surfaces, each a few hundred lines, launched together. They use isolated worktrees because each `xcodebuild` compiles the whole target and would break on another writer's half-written files. Shared files (`AppState`, `RootView`, `SidebarView`, `AgendaApp`) are owned by the parent and wired in T4.

## Log

- L1 (2026-11-17, user): "go with slice 1" → slice 1 delivered on `feat/slice-1-tasks-calendar`.
- L2 (2026-11-17, user): "go with slice 2".
- L3: Slice 1 verifier: entitlement change PASS. Finding: commit `9af9968` doesn't compile alone (WeekView needs AppState from `50f2ec9`). Reported to the user, history not rewritten.
- L4: Merged T1–T3 without conflicts. Parent changes: launcher search now uses the parsed title ("dentist fri" finds "Dentist"; RED→GREEN test); Habits menu shortcut is ⌘6 so existing ⌘1–⌘5 keep their meaning; habit sheet name field left-aligned.
- L5: Schema migration checked by launching on the slice-1 store: existing tasks loaded intact.
- L6: Risk review: writer C named items 1 and 3, writer A named item 3. Parent assessment: no shipped data, dev store only (item 1 exclusion); updateStatus spawn is the requested S3.1 behavior with defaulted parameter (not item 3); CalendarEventSource is an internal protocol with both conformers updated (not item 3).
- L7: Not verified in the app: New Event creation (needs calendar permission), repeating-task spawn by clicking (covered by domain tests), sheet icon/color clicks (synthetic clicks did not reach the sheet; keyboard submit worked).
