# Publishing the Google Meet and Zoom integrations

Today both integrations run in development/testing mode: only the developer's own accounts (and Google test users) can create meetings. This is the checklist to let any user create Google Meet and Zoom meetings from Dayloom.

Users never set anything up. They click **Create Google Meet** or **Create Zoom Meeting**, sign in with their own account, and approve. The work below is done once, by the developer, per service.

Status: not started. Researched on 2026-11-18; re-check the linked docs before starting, as the services change their rules.

## 1. Prerequisites for both

A public website on a domain you own, with:

- [ ] **Homepage** describing Dayloom (publicly accessible, clearly about the app).
- [ ] **Privacy policy** on the same domain. It should state that Dayloom only creates meetings, stores just the meeting link on the task (synced through the user's own iCloud), and keeps sign-ins in the Mac's Keychain, never on a server.
- [ ] **Support/contact** address.

## 2. Google Meet

The scope `https://www.googleapis.com/auth/meetings.space.created` is classed as **sensitive**, so Google requires app verification.

- [ ] **Branding**: in Google Auth Platform → Branding, add the app logo, homepage, privacy policy and terms links, and the authorized domain.
- [ ] **Domain ownership**: verify the domain in Google Search Console.
- [ ] **Publish**: Audience → **Publish app** (Testing → In production).
- [ ] **Submit for verification** in the Verification Center:
  - Scope justification: it is the narrowest scope that creates meetings; Dayloom never reads meetings, calendars or mail.
  - An unlisted YouTube **demo video** showing the full sign-in, the consent screen in English, and a meeting being created and used.
- [ ] **Wait for review**: 3–5 working days is typical for sensitive scopes, up to about 10 days.

Code changes: none. The same client ID (`GoogleOAuthConfig.app`) keeps working.

Until verified: unverified apps in production show an "unverified app" warning and are capped at 100 users; in Testing, only accounts listed under Audience → Test users can sign in, and their sign-in expires every 7 days.

## 3. Zoom

- [ ] **Move to Production** in the Zoom App Marketplace. Zoom issues **production credentials**, including a different **public client ID**.
- [ ] **Update the code**: put the production public client ID in `ZoomOAuthConfig.app` (`agenda/Features/Meetings/Domain/ZoomOAuth.swift`).
- [ ] **Production redirect**: register the PKCE redirect `http://127.0.0.1/callback` (without a port) in the Production tab too, plus the allow list. Zoom's docs confirm loopback works for PKCE public clients and that the port is ignored when matching, but don't say whether a published app keeps that permission. **Confirm this before submitting**; if it's not allowed, the app needs an HTTPS redirect on your domain (associated domains) instead.
- [ ] **Listing details**: description, screenshots, privacy policy, support URL, and how the `meeting:write:meeting` scope is used (creates one meeting for a task the user picks; stores only its join link).
- [ ] **Submit for review**. Choose **Unlisted** to keep Dayloom out of the Marketplace listing; it's still usable by anyone and still reviewed. Zoom reviewers test with the production credentials. Zoom doesn't publish review times.

## 4. Teams

Nothing to do. Microsoft only lets apps create Teams meetings for work or school accounts, so Dayloom's **New Teams Meeting** just opens Teams and the user pastes the link. No sign-in, no review.

## What Claude can prepare

- Privacy policy and homepage text.
- Scope justifications for Google and Zoom.
- A script for the Google demo video.
- The Zoom client ID switch once production credentials exist.

## Sources

- [Google: Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Google: Verification requirements](https://support.google.com/cloud/answer/13464321?hl=en)
- [Google: Demo video](https://support.google.com/cloud/answer/13804565?hl=en)
- [Google: Submitting your app for verification](https://support.google.com/cloud/answer/13461325?hl=en)
- [Google Classroom review process (3–5 day estimate)](https://developers.google.com/workspace/classroom/add-ons/developer-guides/review-process-overview#complete_oauth_verification)
- [Google Meet API: scopes and their sensitivity](https://developers.google.com/workspace/meet/api/guides/authenticate-authorize)
- [Zoom: Enabling publishing for private and beta apps](https://developers.zoom.us/docs/distribute/app-submission/enabling-publishing-for-private-and-beta-apps/)
- [Zoom: Before you start (unlisted apps)](https://developers.zoom.us/docs/build-flow/before-you-build/)
- [Zoom: App credentials](https://developers.zoom.us/docs/build-flow/basic-info/app-credentials/)
- [Zoom: OAuth 2.0 (loopback and PKCE)](https://developers.zoom.us/docs/rooms/oauth/)
- [Zoom forum: localhost and 127.0.0.1 only for PKCE public flow](https://devforum.zoom.us/t/zoom-marketplace-oauth-url-localhost/144392)
- [Microsoft Graph: Create onlineMeeting (personal accounts not supported)](https://learn.microsoft.com/en-us/graph/api/application-post-onlinemeetings?view=graph-rest-1.0)
