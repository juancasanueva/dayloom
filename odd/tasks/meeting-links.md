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
- S3.7 Teams (T4): Microsoft Graph creates Teams meetings only for work or school accounts; the user's account is personal. So "New Teams Meeting" opens Teams (the desktop app when installed, otherwise https://teams.live.com), where the user creates a meeting link and pastes it into the task; no Microsoft sign-in in the app.
- S3.8 Zoom (T3): "Create Zoom Meeting" in the task's Video Call section signs in to Zoom (public-client OAuth with PKCE, no client secret, public client ID) and creates a meeting with `POST /v2/users/me/meetings`: the task's title as topic; its scheduled start and duration when it has one (type 2), otherwise a meeting with no fixed time (type 3). The join link is stored on the task. Settings shows Zoom's connection with Disconnect, like Google (S3.5). Zoom only accepts HTTPS or loopback redirects (L13), so sign-in opens in the default browser and returns to `http://127.0.0.1:47823/callback`, served by a listener bound to 127.0.0.1 only while signing in (sandbox: incoming connections enabled). Giving up after 3 minutes counts as cancelling.
- S3.9 The Google and Zoom sign-ins share one OAuth implementation; Google's existing behavior and saved sign-in are unchanged.
- S3.6 Until a Google OAuth client ID is set in the build, the button explains that Google sign-in isn't set up (assumption: the client ID is a public identifier kept in source, as Google documents for native apps).

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1.1–S1.3, S2.1–S2.3 | inline | done (260 tests green; app opened on existing data) | a75190d |
| T2 | S3.1–S3.6 Google Meet | inline | done (278 tests green, independent verifier: no blockers); live use waits on the user's client ID | 6353854 |
| T3 | S3.8–S3.9 Zoom | inline | done in code (295 tests green, independent verifier: no blockers); verified live (L17) | 96f2ae3 |
| T4 | S3.7 Teams (open Teams, paste link) | inline | done (285 tests green) | b1bdd99 |

## Log

- L1 (2026-11-18) User: "For I given task, I want to be able to indicate that its a video call, and for those, be able to join a meeting using GoogleMeet, Teams, Zoom, etc. Is that possible to implement?"
- L2 (2026-11-18) User, asked whether creating meetings is needed or pasting a link is enough: "I want both"
- L3 Plan: T1 (joining) first, it has no outside dependencies; T2–T4 wait on provider credentials only the user can register.
- L4 T1 done in a75190d: RED observed (missing types, then a mailto link accepted), GREEN with 260 tests; the app opened on the existing store with the new field.
- L5 (2026-11-18) User: "start with google meet"
- L6 T2 done in 6353854: RED observed (missing types; then the 401 case), GREEN with 278 tests. Risk item 2 (auth, credentials): independent verifier found no blockers and met S3.3–S3.6; fixed its advisories on a 401 after access removal, a possible double resume of the sign-in sheet, whitespace-only link fields, and a visible not-set-up hint. Next: the user creates the Google Cloud OAuth client (iOS type, bundle ID com.juancasanueva.agenda) and sends the client ID for GoogleOAuthConfig.app.
- L7 Native review (lenses risk, resilience, reliability) of b8be2e0..6353854: granted by the user, approved and acknowledged; 6 non-blocking follow-ups: sign-in sheet callback thread, `host:port` pastes, Keychain test uses the real Keychain, per-task create state, zoomgov app link host, one link detector per event.
- L8 (2026-11-18) Live check by the user: Google sign-in first failed with "Error 403: access_denied" (account not yet a test user); after adding it under Audience → Test users, Create Google Meet returned https://meet.google.com/tou-jwvw-cmw and Join Google Meet appeared. User: "it worked. It gave me a link". T2 verified live. Next: T3 Zoom, T4 Teams.
- L9 (2026-11-18) User: "go, lets do Teams now". Graph docs: creating online meetings is "Not supported" for personal Microsoft accounts. User, asked which account: "a personal one". Fallback chosen: open Teams and paste the link (S3.7).
- L10 (2026-11-18) User, asked whether to do Zoom next: "yes". Zoom docs: public-client PKCE needs no secret; custom-scheme redirects unconfirmed (examples use loopback).
- L11 T3 in 96f2ae3: RED observed (missing shared OAuth and Zoom types), GREEN with 295 tests. Risk item 2 (shared sign-in code): independent verifier found no blockers, Google unchanged (requests, refresh, Keychain item); fixed its wording advisory (service-named sign-in and Keychain errors, pinned by a test) and restored the Teams button's always-enabled state. Open: whether Zoom accepts the custom-scheme redirect and public-client refresh/revoke without Basic auth.
- L12 Native review (risk, resilience, reliability) of bd4ee2b..9fb9ec5: granted by the user, approved and acknowledged; 6 non-blocking follow-ups: disconnect/revoke handling (OAuthSession 76-81), Teams hint carrying across tasks, a Zoom 401 forcing an interactive sign-in, Zoom revoke unproved, a time-zone-dependent Zoom test, concurrent Zoom refreshes.
- L13 (2026-11-18) Zoom Marketplace rejected `dayloom://oauth/zoom`: "A secure URL using HTTPS is required. For local testing, you may use http://127.0.0.1 or http://[::1] (localhost is not allowed)." Its PKCE redirect field supports loopback IPs. Switched Zoom to a loopback redirect on port 47823 and the public client ID.
- L14 Loopback sign-in in 073cc7f: RED observed (missing LoopbackAuthorizer; then a stray /callback ending sign-in), GREEN with 302 tests (real sockets in the sandbox). Risk item 2 (sandbox incoming connections, sign-in): independent verifier found no blockers (loopback-only bind, no port takeover, clean overlap failure); fixed its advisories on stray callbacks and listener handlers. Waiting on the user's live Zoom sign-in.
- L15 Native review (risk, resilience, reliability) of 0c0b6ab..f329a4e: granted, approved and acknowledged; 10 non-blocking follow-ups, notably an abandoned sign-in holding port 47823 until the 3-minute timeout, single-read requests, untested listener failure paths, and task cancellation not stopping the listener. First live Zoom attempt reached Zoom's consent page and failed with "Invalid scope" (no scopes added to the Zoom app yet).
- L16 (2026-11-18) User's live attempt failed: "Zoom sign-in failed (couldn't listen for the sign-in reply (The operation couldn't be completed. (Network.NWError error 48 - Address already in use)))". lsof: Dayloom itself held 127.0.0.1:47823 from an earlier waiting sign-in. Fixed in 9d36868 (RED reproduced the same error; GREEN 303 tests, listener suite stable over 3 runs).
- L17 (2026-11-18) Zoom live check: with the PKCE redirect registered as `http://127.0.0.1:47823/callback` Zoom answered "Invalid redirect URL"; registered as `http://127.0.0.1/callback` (no port, RFC 8252 loopback) it showed the consent page while the app sent port 47823. After Allow, the task got https://us04web.zoom.us/j/75508105239 with Join Zoom. User: "it worked". T3 verified live.
- L18 Review assessment of f329a4e..fd5bfc5 (port fix 9d36868): risk medium, review_due false (under_budget); stays pending in the slice.
