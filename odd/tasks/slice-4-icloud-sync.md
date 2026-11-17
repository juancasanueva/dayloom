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
- S3.2 It also shows the last successful sync time, and a problem state with the error while the latest sync step failed (L4).

### S4 — Carry-over
- S4.1 Original design and copy; no reference to any other product in code or docs.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S2 | inline | done | RED→GREEN 8 tests; commit e36bf62 |
| T2 | S1 | inline | done | RED→GREEN 4 tests; commits c97968e, 079356e; signed entitlements read back; app log: setup succeeded, 31 objects exported |
| T3 | S3, S2 wiring | inline | done | RED→GREEN 11 tests; commits c3b46d2, 9b9f485; Settings shows status + last synced in app |

Route evidence: no Writer trigger; T2 and T3 build on each other and the parent owns the project file. Risk: T1 deletes stored records while merging (item 1), T2 changes entitlements and provisioning (items 2, 5) → independent verifier at the feature's end.

## Log

- L1 (2026-11-17, user): "go with slice 4" (answer to "The main piece left is iCloud sync. Want me to do it as Slice 4?").
- L2 (2026-11-17, user): "use that one, go ahead" (container `iCloud.com.juancasanueva.agenda`; registration is permanent).
- L3: First signed build failed: Xcode's account login was rejected; the user re-signed in. Provisioning then registered the container; signed entitlements include iCloud/CloudKit, aps development, network client.
- L4: CloudKit first returned CKError 5 (bad container) while the new container activated; ~3 min later setup succeeded in the Development (Sandbox) environment and exported the 31 existing objects. Settings showed "Syncing" during the failure, so S3.2 adds sync-event tracking (SwiftData posts `NSPersistentCloudKitContainer.eventChangedNotification`, verified in app).
- L5: Found and fixed: the test host opened the real on-disk store (now in-memory under tests, and a local-only fallback when CloudKit can't start), and `makeInMemoryContext()` used a bare configuration defaulting to `.automatic`, which attached CloudKit to test stores once the entitlement existed. Logs show that run never finished CloudKit setup (no import/export); the next run made no CloudKit calls.
- L6: Not verified: a second Mac receiving the data (no second device here); CloudKit production schema deployment is a release step for later.
