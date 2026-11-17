# Slice 4 — iCloud sync

Objective: sync all planner data across the user's Macs through iCloud (CloudKit private database). Branch: `feat/slice-4-icloud-sync` (from slice 3 head `6ad9b4f`).
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests -derivedDataPath <scratch>` (Swift Testing).

## Specs

Agreed scope (assistant proposal accepted by the user, L1): "iCloud sync". Container (L2): "use that one, go ahead" → `iCloud.com.juancasanueva.agenda`.
Everything below is detail derived from those lines. Assumptions are marked as such.

### S1 — Sync
- S1.1 The on-disk store syncs through the CloudKit private database of container `iCloud.com.juancasanueva.agenda`. In-memory stores (tests, previews) never sync.
- S1.2 Data already on the Mac uploads on the first launch with sync; the app keeps working offline and when not signed in to iCloud.
- S1.3 Entitlements: iCloud (CloudKit) with that container, push notifications (development) for change pushes, outgoing network connections in the sandbox.
- S1.4 Sync is always on; there is no toggle (assumption).

### S2 — Duplicates created by sync (no unique constraints in CloudKit)
Run after each successfully finished iCloud import, never mid-import (rewritten, L8). The survivor is chosen the same way on every Mac (oldest `createdAt`), so two Macs merging at once agree.
- S2.1 Tags with the same name (ignoring case and surrounding spaces) merge into the oldest: it gains every task of the others, which are deleted.
- S2.2 Daily notes for the same day merge into the oldest: the others' non-empty blocks are appended in order, the note stays pinned if any copy was pinned, and the others are deleted.
- S2.3 Same-day habit completions are not deleted (rewritten, L7): copies have no key every Mac agrees on, so deleting could lose the tick. Readings count each day once.
- S2.4 Un-ticking a habit day removes every completion for that day.

### S3 — Sync status
- S3.1 Settings (⌘,) shows the iCloud status: syncing on, not signed in, restricted, or unavailable/checking, with a one-line explanation. It updates when the iCloud account changes.
- S3.2 It also shows the last successful sync time, and a problem state with the error while the latest sync step failed (L4). When the store had to open without iCloud, it shows unavailable (L7).

### S5 — Review follow-ups (L10: "yes, fix all six")
- S5.1 Survivor ties: notes and tags get a random merge key at creation; ties on `createdAt` break on it, so every Mac keeps the same copy.
- S5.2 Daily notes merge only when their stored day is identical, never because they fall on the same local day of the merging Mac (time-zone travel).
- S5.3 Sync status and the merge trigger run for the app's lifetime, not a window's: closing the main window doesn't freeze Settings or stop merges; extra windows don't add observers.
- S5.4 When the store had to open without iCloud, Settings says sync is off on this Mac until Agenda is reopened, with the reason, instead of promising an automatic retry.
- S5.5 Store-open and merge-save errors log their domain and code publicly and their description privately (paths can contain the user name).
- S5.6 Tests cover the observation wiring, the app's store under tests being in-memory and non-syncing, and the fallback when the iCloud store can't open.

### S4 — Carry-over
- S4.1 Original design and copy; no reference to any other product in code or docs.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S2 | inline | done | RED→GREEN 8 tests; commit e36bf62 |
| T2 | S1 | inline | done | RED→GREEN 4 tests; commits c97968e, 079356e; signed entitlements read back; app log: setup succeeded, 31 objects exported |
| T3 | S3, S2 wiring | inline | done | RED→GREEN 11 tests; commits c3b46d2, 9b9f485; Settings shows status + last synced in app |
| T4 | S5.1, S5.2 | inline | pending | |
| T5 | S5.3–S5.6 | inline | pending | |

Route evidence: no Writer trigger; T2 and T3 build on each other and the parent owns the project file. Risk: T1 deletes stored records while merging (item 1), T2 changes entitlements and provisioning (items 2, 5) → independent verifier at the feature's end.

## Log

- L1 (2026-11-17, user): "go with slice 4" (answer to "The main piece left is iCloud sync. Want me to do it as Slice 4?").
- L2 (2026-11-17, user): "use that one, go ahead" (container `iCloud.com.juancasanueva.agenda`; registration is permanent).
- L3: First signed build failed: Xcode's account login was rejected; the user re-signed in. Provisioning then registered the container; signed entitlements include iCloud/CloudKit, aps development, network client.
- L4: CloudKit first returned CKError 5 (bad container) while the new container activated; ~3 min later setup succeeded in the Development (Sandbox) environment and exported the 31 existing objects. Settings showed "Syncing" during the failure, so S3.2 adds sync-event tracking (SwiftData posts `NSPersistentCloudKitContainer.eventChangedNotification`, verified in app).
- L5: Found and fixed: the test host opened the real on-disk store (now in-memory under tests, and a local-only fallback when CloudKit can't start), and `makeInMemoryContext()` used a bare configuration defaulting to `.automatic`, which attached CloudKit to test stores once the entitlement existed. Logs show that run never finished CloudKit setup (no import/export); the next run made no CloudKit calls.
- L6: Not verified: a second Mac receiving the data (no second device here); CloudKit production schema deployment is a release step for later.
- L7: Independent verifier: S1.1, S1.3, S1.4, S2.1, S2.2, S2.4, S3.1, S3.2, S4.1 PASS; S1.2 unverified (no launch allowed). Blocker B1: same-day completion survivor depended on local array order, so two Macs could delete different copies and lose the tick → S2.3 rewritten to never delete completions. Advisories fixed in the same batch: A3 (Settings said "Syncing" on a local-only fallback store), A5 (merge save errors were swallowed, now logged). Left as advisories: A1 (an edit made on another Mac to a daily-note copy after it was merged away is lost with the copy), A2 (blank non-text blocks are moved), A4 (status observation is tied to the main window's lifetime).
- L8: Native review (lenses risk, resilience, reliability; user granted): CRITICAL R4 — merging on app activation could run mid-import and delete a duplicate whose blocks or task links hadn't arrived, then sync that deletion back. Correction: merge only after an import event finishes successfully (`NSPersistentCloudKitContainer.Event` type import); no merge at launch/activation, none on a local-only store.
- L9: Native review approved after the R4 correction (commit f0e613c; targeted validator approved; acknowledged, lineage review-1795ef78a7ba95c8). Non-blocking follow-ups recorded: daily-note survivor tie when createdAt and title match; daily notes grouped by the merging Mac's local day (time-zone travel could merge two days); status observation tied to the main window (A4); fallback "unavailable" text promises a retry that only happens on relaunch; store-open/merge errors logged with privacy public (may include the user name in paths); missing tests for observeChanges wiring, the test host's in-memory store, and the CloudKit-failure fallback path.
- L10 (2026-11-17, user): "yes, fix all six" (the six review follow-ups in L9).
