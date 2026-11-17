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
| T3 | S3.1 board | delegated | done | commit c32416b; 206 tests; shared `TimeEmphasis.color` |
| T4 | S3.1 calendar | delegated | done | commits c349fbd, 973fa8f; week shortcuts verified in app |
| T5 | S3.1 habits | delegated | done | commit 9daf2b5; RED→GREEN 4 tests (210) |
| T6 | S3.1 notes | delegated | done | commit a64d04d; RED→GREEN 6 tests (216); search moved in-panel, ⌘F verified |
| T7 | S3.1 sidebar, details panel, launcher, Settings | delegated | done | commit cb63cec; RED→GREEN 4 tests (220) |

Route evidence: one visual language needs one hand; screens share the running app for screenshot checks, so parallel writers would collide on builds and app state. No Writer trigger. Checkpoint with the user after T2 (design direction is a product decision).
Forecast: ~1,200–1,800 authored changed lines → over 400; chain strategy asked before the first PR.
Risk: item 6 (visual changes; no test catches a layout regression) → independent verifier at the feature's end for S4.

## Log

- L1 (2026-11-17, user): "ok, the app was a lot of functionality which is great. But the design is not as nice as [the reference]. For ecample, our Upcoming list view is this: [screenshot] and [the reference] has this: [screenshot]" (reference name redacted per the standing rule).
- L2 (2026-11-17, user): "Whole app" (answer to: task lists only / task lists + events in Upcoming / whole app).
- L3: T1–T2 done. Palette is original (warm stone canvas, paper panel, linen cards; adaptive light/dark). Removing the toolbar title left toolbar items on the leading edge; a principal spacer restores the trailing inspector button, and the List/Board switch moved into the page header. Lists moved from `List` to cards in a `ScrollView`, so arrow-key selection and Delete are reimplemented (`ListNavigation`, tested). Checkpoint: design direction shown to the user before T3–T7.
- L4 (2026-11-17, user): "go ahead with the rest of the app".
- L5: T3–T7 routed to one bounded writer each, sequentially (Writer trigger: long-session context backstop; sequential because screenshot checks share one running app). Writers ran under a real-data safety rule (navigate, hover, select, screenshots only). Parent reviewed each diff surface, re-ran the suite, and fixed seams: shared `TimeEmphasis.color` (T3), shared `PageControlStyle` in the calendar (after T5), notes search moved from the toolbar into the panel because `.searchable` pushed the inspector toggle to the middle (T6). Known pre-existing issue: calendar day headers drift from grid columns when scroll bars are always visible.
- L6: Calendar header drift fixed (grid scroll bar hidden), commit 4e5618e.
- L7: Independent verifier ran every S4.1 action in a sandbox (app binary launched with `XCTestConfigurationFilePath` set → in-memory store, no iCloud): S1.1–S1.4, S2.1–S2.3, S3.1 PASS; S4.1 PASS except the hover-only subtask × (synthetic hover never fires here, same at baseline). No blockers. Change-caused advisories fixed: Settings row focus ring, quick add no longer focused at launch (now focused on appear). Left as advisories: launcher field focus is unreliable (also at baseline), board cards cramped with the details panel open, calendar grid lines reach the panel edges, details panel width shifts slightly, Escape in quick add keeps focus, `DayColumnLabel` today accent can't show in Upcoming. Incident: one verifier Return keystroke may have reached another frontmost app; helpers now check the frontmost app first.
