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
- S3.3 Google Meet (T2): a "Create Google Meet" button in the task's Video Call section, shown while the task has no link, creates a Meet space (Meet REST API `spaces.create`, scope `meetings.space.created` only, no calendar event) and stores its link on the task.
- S3.4 The first time, the user signs in to Google in a system browser sheet (OAuth with PKCE, no client secret); later meetings reuse or refresh the saved sign-in. Cancelling sign-in changes nothing and shows no error.
- S3.5 Settings shows whether Google is connected and offers Disconnect, which revokes the sign-in and forgets it.
- S3.6 Until a Google OAuth client ID is set in the build, the button explains that Google sign-in isn't set up (assumption: the client ID is a public identifier kept in source, as Google documents for native apps).

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1.1–S1.3, S2.1–S2.3 | inline | done (260 tests green; app opened on existing data) | a75190d |
| T2 | S3.1–S3.6 Google Meet | inline | done (278 tests green, independent verifier: no blockers); live use waits on the user's client ID | 6353854 |
| T3 | S3.1–S3.2 Zoom | inline | blocked: needs a Zoom OAuth app | |
| T4 | S3.1–S3.2 Teams | inline | blocked: needs an Azure app registration and account type | |

## Log

- L1 (2026-11-18) User: "For I given task, I want to be able to indicate that its a video call, and for those, be able to join a meeting using GoogleMeet, Teams, Zoom, etc. Is that possible to implement?"
- L2 (2026-11-18) User, asked whether creating meetings is needed or pasting a link is enough: "I want both"
- L3 Plan: T1 (joining) first, it has no outside dependencies; T2–T4 wait on provider credentials only the user can register.
- L4 T1 done in a75190d: RED observed (missing types, then a mailto link accepted), GREEN with 260 tests; the app opened on the existing store with the new field.
- L5 (2026-11-18) User: "start with google meet"
- L6 T2 done in 6353854: RED observed (missing types; then the 401 case), GREEN with 278 tests. Risk item 2 (auth, credentials): independent verifier found no blockers and met S3.3–S3.6; fixed its advisories on a 401 after access removal, a possible double resume of the sign-in sheet, whitespace-only link fields, and a visible not-set-up hint. Next: the user creates the Google Cloud OAuth client (iOS type, bundle ID com.juancasanueva.agenda) and sends the client ID for GoogleOAuthConfig.app.
- L7 Native review (lenses risk, resilience, reliability) of b8be2e0..6353854: granted by the user, approved and acknowledged; 6 non-blocking follow-ups: sign-in sheet callback thread, `host:port` pastes, Keychain test uses the real Keychain, per-task create state, zoomgov app link host, one link detector per event.
