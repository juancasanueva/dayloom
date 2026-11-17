# Slice 3 — Notes editor

Objective: block-based notes that can hold tasks and calendar events, plus a daily note. Branch: `feat/slice-3-notes` (from slice 2 head `95d6d52`).
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests -derivedDataPath <scratch>` (Swift Testing).

## Specs

Agreed scope (assistant proposal accepted by the user, L1): "the notes editor (block-based pages that can hold tasks and events)".
Everything below is detail derived from that line. Assumptions are marked as such.

### S1 — Notes and blocks (domain)
- S1.1 A note has a title, created/updated dates, a pinned flag, an optional daily date, and ordered blocks. Deleting a note deletes its blocks.
- S1.2 Block kinds: text, heading, bullet, checklist (checked or not), divider, task (linked to a `TaskItem`), event (snapshot of a calendar event).
- S1.3 Markdown shortcuts typed at the start of a text block convert it (assumption on the set): `# ` → heading, `- ` or `* ` → bullet, `[] ` or `[ ] ` → checklist, `[x] ` → checked checklist, `---` → divider.
- S1.4 Editing operations, pure and tested:
  - Return splits the block at the caret. The new block below continues bullet and checklist (unchecked); after a heading it is text. Return in an empty bullet or checklist turns it into text instead.
  - Backspace at the start of a non-text block turns it into text. At the start of a text block it merges the text into the previous text-like block; the caret goes to the join point.
  - A block moves up or down by one.
  - Slash commands: `/` in an empty block lists the kinds, filtered by the typed word.
- S1.5 A checklist or text block converts into a task block: it creates a `TaskItem` with the block's text as title. Inside a daily note the task is due that day; otherwise it goes to the Inbox. Deleting the task leaves the block as a checklist with the last known title.
- S1.6 An event block stores the event's id, title, start, end and all-day flag, so it still renders when the event is gone or access is denied.
- S1.7 Daily note: one per day, found or created on demand, titled with the date. If duplicates exist (sync), the oldest wins.
- S1.8 Note list: pinned first, then most recently updated. Search matches title and block text, case- and diacritic-insensitive.

### S2 — Notes UI
- S2.1 Sidebar item "Notes" (Go menu ⌘7). "New Note" in the File menu (⇧⌘N).
- S2.2 The Notes screen shows a searchable note list and the selected note's editor. A toolbar button opens today's note.
- S2.3 The editor has a title field and the blocks. ↑/↓ at the first/last line move between blocks; ⌥⌘↑/↓ move the block. A new note starts with one empty text block.
- S2.4 Task blocks show a completion button, the editable task title and its due date; clicking the info button selects the task in the inspector.
- S2.5 Event blocks show time and title; when the event no longer exists they are marked unavailable. Inserting an event opens a picker of one day's events, starting on the note's day (daily note) or today.
- S2.6 Pin, and delete with confirmation, from the list's context menu.

### S3 — Carry-over
- S3.1 Original design and copy; no reference to any other product in code or docs.
- S3.2 Schema changes stay CloudKit-compatible: defaults on every attribute, optional relationships, no unique constraints.

### Out of scope (assumption)
Launcher search of notes, nested/indented blocks, rich inline formatting, images.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1, S3.2 | inline | done | RED (missing types) → GREEN 156 tests; commit 2b54ff0 |
| T2 | S2, S3.1 | inline | done (UI unverified) | RED→GREEN `events(on:)`; 158 tests, 0 warnings; commit 8dbf773 |

Route evidence: no Writer trigger. T2 depends on T1, so they aren't independent units; the parent writes both inline.

## Log

- L1 (2026-11-17, user): "go with slice 3" (answer to "Want to do the notes editor as Slice 3?").
- L2: T1 committed 2b54ff0 (39 domain tests). T2 committed 8dbf773 (UI + `WeekCalendarModel.events(on:)`, 2 tests).
- L3: Migration: app launched on the slice-2 store with the new schema, no crash or log errors.
- L4: UI not verified: the Mac screen was locked during the run, so screenshots were black and synthetic keystrokes went to the lock screen. Pending checks: typing flow (Return/Backspace/arrows/shortcuts), caret placement after programmatic focus, slash menu, task and event blocks, list pin/delete.
