# Task note links — link notes to a task and jump to them

Objective: a task's details list the notes linked to it, by hand or because the note contains the task, and clicking one opens it in Notes. Branch: `feat/task-note-links`.
Delivery: ask-on-risk (forecast ~350 authored lines, string catalog excluded). Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests` (Swift Testing).

## Specs

- S1 "I want to be able to link one or more notes to a task": from a task's details, the user links any number of existing notes and can unlink them. A note is linked at most once. The link is stored and syncs through iCloud (new many-to-many relationship `TaskItem.linkedNotes` ↔ `Note.linkedTasks`); deleting either side removes only the link.
- S2 "clicking on that link will take you to the note": clicking a listed note switches to Notes with that note selected and open.
- S3 "both, show them automatically too": notes that contain the task as a task block are listed too, without linking them by hand, and can't be unlinked (they leave the list when the block goes). A note listed both ways appears once.
- S4 Assumption: merging duplicate daily notes after sync keeps their links on the surviving note.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1, S3, S4 | inline (model, domain, merger, tests) | done (RED: missing API; merger test fails without the fix; review approved) | d901e41 |
| T2 | S1–S3 | inline (Linked Notes section, note picker, navigation, strings) | done (checked by the user in the Debug build) | see L6 |

## Log

- L1 (2026-11-19) User: "I want to implement a new funcionality. I want to be able to link one or more notes to a task, and clicking on that link will take you to the note. do you understand what I mean?"
- L2 (2026-11-19) Asked whether notes that already contain the task as a block should show up too. User: "both, show them automatically too"
- L3 Exploration: `TaskItem.noteBlocks` already records task blocks in notes but no UI shows it. `AppState.selectedNoteID` drives the Notes screen; changing `selection` clears the task inspector. `TaskPickerSheet` is the pattern for the note picker; `NoteQuery.notes(from:matching:)` is the existing note search. `Tag` ↔ `TaskItem` is the many-to-many precedent for CloudKit. Risk: item 1 (persisted format: new relationship) — needs the CloudKit production schema deployed before release.
- L4 T1: `TaskItem.linkedNotes` ↔ `Note.linkedTasks`, `TaskItem.relatedNotes` / `link` / `unlink` / `linkableNotes` (TaskNoteLinks.swift, ordered with `NoteQuery`), `AppState.open(note:)`, daily-note merge moves links. 397 tests pass. Commit: `feat(tasks): link notes to tasks`.
- L5 Review of d901e41 (risk + reliability lenses): approved and acknowledged; one informational note (the merge test compares links by `mergeKey`).
- L6 (2026-11-19) T2: Linked Notes section in task details (`LinkedNoteRow`, `NotePickerSheet` in LinkedNotes.swift), 8 new strings in eight languages, README. 397 tests pass. User, after running the Debug build: "it works. commit". Pending before release: deploy the CloudKit production schema (new relationship).
