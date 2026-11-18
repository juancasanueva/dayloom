# Configurable keyboard shortcuts — keys.toml and a Shortcuts tab

Objective: the user changes Dayloom's keyboard shortcuts by editing `~/.config/dayloom/keys.toml`, and Settings shows every shortcut and what it does. Branch: `main` (as the user has been committing).
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests` (Swift Testing).

## Specs

User request (L1): "I want the app to create a keys.toml file in .config/dayloom with the keyboard shortcuts for this app, so that the user can change them it needed. Also, in the Settings, I want to add a new tab called Shortcuts with the keys and what it does."

- S1 "create a keys.toml file in .config/dayloom": on launch, when `~/.config/dayloom/keys.toml` doesn't exist, Dayloom writes it with every shortcut at its default, each with a comment saying what it does. An existing file is never overwritten.
- S2 "so that the user can change them": the shortcuts in the file replace the defaults. Saving the file applies the changes without restarting (assumption: live reload, proposed in the reply to L1).
- S3 Format (assumption, proposed in the reply to L1): one `action = "keys"` line per shortcut, e.g. `new_task = "cmd+shift+n"`; modifiers `cmd`, `shift`, `option`, `ctrl`; keys are letters, digits, punctuation, arrows, `space`, `return`, `escape`, `tab`, `delete`. A line that can't be read keeps that action's default and is reported. In-app shortcuts must include ⌘ or ⌃ so they never take over plain typing; the system-wide launcher shortcut needs at least one modifier. Unknown action names and two actions on the same keys are reported.
- S4 "in the Settings, I want to add a new tab called Shortcuts with the keys and what it does": a Shortcuts tab lists every action, what it does, and its current keys, grouped; it shows the file's path with Open and Show in Finder, and any problems found in the file.
- S5 The app sandbox gains an exception limited to `~/.config/dayloom/`; nothing else outside the container becomes reachable.
- S6 Configurable actions (16): new task, new note, Quick Launcher (in app), Quick Launcher (anywhere), show/hide inspector, go to Calendar/Inbox/Today/Upcoming/Completed/Habits/Notes, calendar today/previous/next, search notes. Dialog keys (Return/Escape) stay fixed.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S3, S6 | inline | done (model, parser, defaults, file text) | fc5dba7 |
| T2 | S1, S2, S5 | inline | done (file creation, live reload, sandbox exception; missing ~/.config explained) | fc5dba7 |
| T3 | S2, S6 | inline | done (menus, calendar, notes, launcher pill, inspector and system-wide hotkey) | fc5dba7 |
| T4 | S4 | inline | done (Shortcuts tab) | fc5dba7 |
| T5 | S1–S4 | inline | done (README) | fc5dba7 |

## Log

- L1 (2026-11-18) User: "I want the app to create a keys.toml file in .config/dayloom with the keyboard shortcuts for this app, so that the user can change them it needed. Also, in the Settings, I want to add a new tab called Shortcuts with the keys and what it does."
- L2 Mapped 16 configurable shortcuts in AgendaApp (menus), WeekView (calendar), NotesView (search) and GlobalHotKey (⌃⌥Space). The app is sandboxed, so ~/.config needs a home-relative-path exception.
- L3 Live checks in the running app: keys.toml created in ~/.config/dayloom through the sandbox exception; editing go_inbox to cmd+i changed Go > Inbox to ⌘I without a restart; an invalid new_note = "n" kept ⇧⌘N and was reported in the Shortcuts tab; quick_launcher_anywhere = "ctrl+option+l" worked from Finder and ⌃⌥Space was released.
- L4 Independent verifier (risk item 2, sandbox exception): S2–S6 met; blockers: S1 fails when ~/.config doesn't exist (the sandbox can't create a parent), and hard-coded hints (launcher pill, inspector, new note). Fixed: missing ~/.config is explained with the mkdir command instead of a permission error (exception stays limited, S5); hints read the configured shortcuts; also CRLF line numbers, BOM, repeated actions, section message, unregistered system-wide shortcut reported, FSEvents stopped on deinit. 340 tests green.
- L5 (2026-11-18) User: "commit". Committed as fc5dba7. Native review (risk, resilience, readability, reliability) granted by the user: its only blocker said the per-list layout commit (ccb763e, in the same range) was unrequested, because that request lived only in conversation; corrected by recording it in odd/tasks/per-list-layout.md (72b1a26). The successor review was approved and acknowledged with 13 non-blocking follow-ups (notably: remaps onto reserved keys like ⌘Q aren't flagged, a failed system-wide re-registration has no fallback to the previous keys, and a reload error briefly drops custom shortcuts to the defaults).
