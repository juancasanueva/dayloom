# Meeting links — mark tasks as video calls, join and create meetings

Objective: a task can be a video call with a meeting link; Join opens it in the right app, and meetings can be created from the app. Branch: `feat/meeting-links` (from main `b8be2e0`).
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests` (Swift Testing).

## Specs

User request (L1): "For I given task, I want to be able to indicate that its a video call, and for those, be able to join a meeting using GoogleMeet, Teams, Zoom, etc. Is that possible to implement?" Scope (L2): "I want both" — joining and creating meetings.

### S1 — A task can be a video call (phase 1)
- S1.1 A task holds an optional meeting link; having a link is what makes it a video call (assumption: no separate toggle, proposed in the reply to L1).
- S1.2 The app recognizes "GoogleMeet, Teams, Zoom, etc." from the link (Google Meet, Microsoft Teams, Zoom, Webex); any other web link is a generic video call.
- S1.3 The new field keeps the CloudKit rules: it has a default and syncs.

### S2 — Join (phase 1)
- S2.1 "be able to join a meeting": a Join button, named after the service, opens the link — in the service's desktop app when one is installed (Zoom, Teams), otherwise in the browser.
- S2.2 Join is offered from the task details and from the task's block on the calendar.
- S2.3 Calendar events whose link, location or notes hold a meeting link get the same Join (proposed in the reply to L1).

### S3 — Create meetings (phase 2, waits on provider app registration)
- S3.1 From a task, create a new Google Meet, Zoom, or Teams meeting and store its link on the task.
- S3.2 Each service needs the user's sign-in (OAuth); tokens live in the Keychain, never in the synced store.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1.1–S1.3, S2.1–S2.3 | inline | in progress | |
| T2 | S3.1–S3.2 Google Meet | inline | blocked: needs a Google Cloud OAuth client | |
| T3 | S3.1–S3.2 Zoom | inline | blocked: needs a Zoom OAuth app | |
| T4 | S3.1–S3.2 Teams | inline | blocked: needs an Azure app registration and account type | |

## Log

- L1 (2026-11-18) User: "For I given task, I want to be able to indicate that its a video call, and for those, be able to join a meeting using GoogleMeet, Teams, Zoom, etc. Is that possible to implement?"
- L2 (2026-11-18) User, asked whether creating meetings is needed or pasting a link is enough: "I want both"
- L3 Plan: T1 (joining) first, it has no outside dependencies; T2–T4 wait on provider credentials only the user can register.
