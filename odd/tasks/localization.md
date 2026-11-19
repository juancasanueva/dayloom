# Localization — a Language tab with flags and nine languages

Objective: Settings gains a Language tab with one flag per language (as in Matchday), and Dayloom is translated into all of them. Branch: `feat/localization`.
Delivery: ask-on-risk. Test runner: `xcodebuild test -project agenda.xcodeproj -scheme agenda -destination 'platform=macOS' -only-testing:agendaTests` (Swift Testing).

## Specs

User request (L1): "I have added 9 flag images to the assets. In the settings add a Language tab with the falgs like we did in /Users/juancasanueva/programming/swiftUI/matchday and translate the app to those languages."

- S1 "In the settings add a Language tab with the falgs like we did in … matchday": a Language tab in Settings shows the 9 flags (UK, Spain, France, Germany, Italy, Portugal, Japan, South Korea, China) as round flags in a 3 × 3 grid, each named in its own language; the selected one has a ring and a checkmark. Until one is picked, Dayloom follows the Mac's language (English when the Mac's language isn't one of the nine).
- S2 Picking a flag switches the app's windows to that language at once, dates and times included (as in Matchday). Assumption: the system-drawn menus (File, Edit, Window…) and other AppKit text follow the choice from the next launch, through the app's `AppleLanguages` preference.
- S3 "translate the app to those languages": every user-facing string Dayloom draws — windows, menus it defines, Settings, accessibility labels, notifications, errors — is translated into English, Spanish, French, German, Italian, Portuguese (Portugal), Japanese, Korean and Simplified Chinese, in `Localizable.xcstrings`. User content (task titles, notes, tags), theme names and product names (Google Meet, Zoom, Teams, iCloud) are not translated. Demo data stays English.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1, S2 | inline | done (AppLanguage, AppLocalization, LanguageStore, Language tab, `appLanguage()` on both scenes, menus) | dc549b5 |
| T2 | S3 | inline (code: make String-typed UI text localizable) | done (328 keys; dates in `Locale.app`) | dc549b5 |
| T3 | S3 | delegated (4 parallel translators, 2 languages each, merged inline) | done (8 × 324 keys, placeholders validated) | df6c114 |
| T4 | S1–S3 | inline (tests, README) | done | df6c114 |

## Log

- L1 (2026-11-19) User: "I have added 9 flag images to the assets. In the settings add a Language tab with the falgs like we did in /Users/juancasanueva/programming/swiftUI/matchday and translate the app to those languages."
- L2 Matchday: `AppLanguage` (9 cases, `.lproj` raw values, flag asset, native name, `matching(_:)`), `AppLocalization` (bundle of the chosen `.lproj` for strings built outside SwiftUI, `String(appLocalized:)`), `\.locale` on the SwiftUI roots, `LanguageCard` (3 × 3 flag grid). Dayloom has no string catalog yet; a build extracts 185 SwiftUI literals, and ~150 more UI strings are `String`-typed (enum titles, helpers) and render verbatim. Dates use `.formatted()` (process locale), so they need the app locale passed to switch at once.
- L3 Decisions: the whole window tree is re-identified on a language change (`.id(language)`) so text built in code redraws; model state lives in the environment and survives. keys.toml keeps English comments (`summary(bundle:)` with the English bundle). Composite phrases replaced by whole ones where languages inflect ("Previous Day/Week/Month", "Repeats every day"). Plurals use catalog plural variations. Launcher input parsing (today, tomorrow, next week) stays English: it is input syntax, not drawn text. `InfoPlist.xcstrings` translates the calendar permission prompt.
- L4 Verification: `xcodebuild test -only-testing:agendaTests` passed 382 tests in 43 suites, the new Localization suites among them (every language carries every key, placeholders match, plurals, keys.toml stays English, store saves and applies the pick). The existing English assertions still pass. Running the app to check visually did not work: the window opened on another Space and no screenshot was taken. Review assessment: medium, not due (under_budget). Next: the user tries the Language tab; PR strategy is the user's call.
