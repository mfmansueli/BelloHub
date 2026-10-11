# Native review: English (United States) (`en`)

Read in this order: the screens a professional meets first come first. Every string is `needs_review` until a native reader approves it (D41: no reviewer is planned; this file is ready for when one exists). How to read, correct and send back: [README.md](README.md).

## Points to check first (decisions made in S11)

- American English: *color*, *organize*, *authorize*; *cancelled* is kept (both spellings are used in the US).
- Counted sentences now read *Not back in 2+ months: 3 clients* (the count noun follows each language's plural rules).

## The app, screen by screen

Export: `scripts/export-strings.sh en` writes `build/strings-en.csv`; the keys start with the batch's area (`onb.`, `clients.`, `calendar.`...). Screenshots of the key screens: `TEST_RUNNER_SCREENSHOT_LOCALES=en TEST_RUNNER_SCREENSHOT_DIR=$PWD/build/screenshots/s11 ONLY_TESTING=BelloHubUITests/LocalizationScreenshotUITests scripts/test.sh full` (files `en-<screen>.png`).

| Order | Area | Batch files (`Config/Locale/strings/`) | Strings | What it covers |
|---|---|---|---|---|
| 1 | Welcome, sign in and permissions | `s3-entry.json` | 63 | Screens 1.1 to 1.4; the first thing she reads. |
| 2 | Setup | `s3-setup.json` | 68 | Onboarding steps: name and region, professions, services, terms for the people she serves, tags, record fields, ready. |
| 3 | The shell and Home | `s3-shell.json`, `s3-region.json`, `s6-home.json`, `s1-design-system.json` | 134 | Tabs, Home, the lock screen, empty states. |
| 4 | Clients | `s4-clients-ui.json`, `s4-import.json`, `s4-tags-record-template.json`, `s4-contract.json` | 290 | Clients list, a client's profile, edit, merge, import, tags, record fields. |
| 5 | Health and consents | `s4-health-forms.json` | 103 | The health form she fills in at the visit, consent status records (no consent text exists, D55). |
| 6 | Calendar and appointments | `s6-calendar.json`, `s6-appointment.json`, `s6-policy-note.json`, `d56-smart-slots.json` | 345 | Calendar, new appointment, reschedule, cancel, running late, no-show, before you start, smart slots. |
| 7 | Booking page and services | `s5-booking.json`, `s5-services.json`, `s5-contract.json` | 442 | Booking settings, cancellation and no-show rules (the rule text clients read), quick replies, services, add-ons, products, credentials. |
| 8 | Treatment and records | `s7-flow.json`, `s7-record.json` | 341 | Voice and form records, photos, record history, incidents, export of a record. |
| 9 | Requests and publishing | `s8-inbox.json`, `s8-publish.json` | 94 | Booking and reschedule requests, waiting list, going online. |
| 10 | Account and settings | `s10-account.json`, `s10-account-apple.json`, `s2-registration-limit.json`, `s11-localization.json` | 349 | Account, language and region, plan and paywall, notifications, integrations, privacy, export all, recovery key, help, AI settings; counted nouns. |
| 11 | Messages to clients | keys `quickReplies.default.*.text`, `appointment.message.*`, `clientMessage.birthday`, `policy.rule.*`, `shareLink.*.text` | | What her clients receive; polite register where the language has one. |
| 12 | Permission texts | `Config/Locale/infoplist/infoplist.json` | 5 | The system dialogs for camera, contacts, Face ID and microphone. |

## Outside the app

1. **Booking pages**: `build/web-strings-en.csv` (from the same export) or `web/src/i18n/en.json`; read them on a phone at the dev site with the page language set to this one.
2. **Message templates**: `docs/strings/message-templates.json`, locale `en` (sixteen kinds).
3. **Emails**: `firebase/functions/src/messaging/emailTemplates.ts`, section `en` (seven emails).
4. **Profession catalog**: `BelloHub/Resources/Professions/professions-en.json` (names, suggested services, tags).
5. **Legal texts** (for a lawyer, not for the language review): `legal/terms-dpa/en/2026-10-2.md`, `legal/privacy-policy/en/2026-10-2.md`, `legal/client-notice/en/2026-10-2.md`, `legal/data-requests/en/2026-10-2.md`.

## Glossary

`docs/strings/glossary.csv`, column `en`: one term, one translation, everywhere. A change of term is made there first, then in the strings.

