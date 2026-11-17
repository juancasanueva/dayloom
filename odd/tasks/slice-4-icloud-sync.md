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
Run at launch and whenever the app becomes active. The survivor is chosen the same way on every Mac (oldest `createdAt`), so two Macs merging at once agree.
- S2.1 Tags with the same name (ignoring case and surrounding spaces) merge into the oldest: it gains every task of the others, which are deleted.
- S2.2 Daily notes for the same day merge into the oldest: the others' non-empty blocks are appended in order, the note stays pinned if any copy was pinned, and the others are deleted.
- S2.3 A habit keeps one completion per day; extra completions for the same day are deleted.
- S2.4 Un-ticking a habit day removes every completion for that day.

### S3 — Sync status
- S3.1 Settings (⌘,) shows the iCloud status: syncing on, not signed in, restricted, or unavailable/checking, with a one-line explanation. It updates when the iCloud account changes.

### S4 — Carry-over
- S4.1 Original design and copy; no reference to any other product in code or docs.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S2 | inline | pending | |
| T2 | S1 | inline | pending | |
| T3 | S3, S2 wiring | inline | pending | |

Route evidence: no Writer trigger; T2 and T3 build on each other and the parent owns the project file. Risk: T1 deletes stored records while merging (item 1), T2 changes entitlements and provisioning (items 2, 5) → independent verifier at the feature's end.

## Log

- L1 (2026-11-17, user): "go with slice 4" (answer to "The main piece left is iCloud sync. Want me to do it as Slice 4?").
- L2 (2026-11-17, user): "use that one, go ahead" (container `iCloud.com.juancasanueva.agenda`; registration is permanent).
