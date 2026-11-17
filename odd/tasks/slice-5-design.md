# Slice 5 — App-wide design pass

Objective: make every screen look as polished as the reference the user showed, with an original visual language. Branch: `feat/slice-5-design` (from main `5e33d53`).
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests -derivedDataPath <scratch>` (Swift Testing); visual checks by screenshots of the running app.

## Specs

User request (L1): "the app was a lot of functionality which is great. But the design is not as nice as [the reference]." Scope (L2): "Whole app".
The design points below are the assistant's comparison the user answered with "Whole app"; they are the agreed direction. Everything else is unchanged behavior.

### S1 — Shared visual language
- S1.1 One set of design tokens (spacing, corner radii, surfaces, type styles) and shared components, used by every screen.
- S1.2 "A real page title": each main screen opens with a large bold title and a short subtitle, instead of a small toolbar label.
- S1.3 "A sensible width": content sits on a rounded panel with margins and a capped reading width, not edge to edge.
- S1.4 Original design: no copied branding, colors or layout signature of the reference; never name it in code or docs (carry-over).

### S2 — Task lists (Inbox, Today, Upcoming, Completed, tags)
- S2.1 "Days are anchors": grouped lists show the day as a prominent label in a left column (today highlighted, date below), its tasks beside it.
- S2.2 "Tasks as cards": rows become soft rounded tiles with spacing, no divider lines.
- S2.3 "Clearer details": times that matter are colored (overdue, today), tags are soft colored pills, details readable.

### S3 — Other screens
- S3.1 Board, Calendar, Habits, Notes, the sidebar, the task details panel, the quick launcher and Settings adopt the same language (S1, card surfaces, pills, titles where they apply).

### S4 — No regressions
- S4.1 Every existing action stays reachable (select, complete, drag on the board, context menus, keyboard shortcuts, quick add); the test suite stays green.

Not in scope (not chosen): calendar events inside the task lists ("Events alongside tasks").

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1 | inline | done | commit 6e02ad8; light + dark screenshots |
| T2 | S2, S1.2–S1.3 | inline | done | RED→GREEN 8 tests (206 total); commit a6b7073; app: select by click, ↓ moves across days, board still works |
| T3 | S3.1 board | inline | pending | |
| T4 | S3.1 calendar | inline | pending | |
| T5 | S3.1 habits | inline | pending | |
| T6 | S3.1 notes | inline | pending | |
| T7 | S3.1 sidebar, details panel, launcher, Settings | inline | pending | |

Route evidence: one visual language needs one hand; screens share the running app for screenshot checks, so parallel writers would collide on builds and app state. No Writer trigger. Checkpoint with the user after T2 (design direction is a product decision).
Forecast: ~1,200–1,800 authored changed lines → over 400; chain strategy asked before the first PR.
Risk: item 6 (visual changes; no test catches a layout regression) → independent verifier at the feature's end for S4.

## Log

- L1 (2026-11-17, user): "ok, the app was a lot of functionality which is great. But the design is not as nice as [the reference]. For ecample, our Upcoming list view is this: [screenshot] and [the reference] has this: [screenshot]" (reference name redacted per the standing rule).
- L2 (2026-11-17, user): "Whole app" (answer to: task lists only / task lists + events in Upcoming / whole app).
- L3: T1–T2 done. Palette is original (warm stone canvas, paper panel, linen cards; adaptive light/dark). Removing the toolbar title left toolbar items on the leading edge; a principal spacer restores the trailing inspector button, and the List/Board switch moved into the page header. Lists moved from `List` to cards in a `ScrollView`, so arrow-key selection and Delete are reimplemented (`ListNavigation`, tested). Checkpoint: design direction shown to the user before T3–T7.
