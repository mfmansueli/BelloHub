# Agent notes: S9, the client web app closed against the real app and backend

Branch `build/v1`, from `1300fac`. One agent (plus one read-only audit sub-agent). Scope: `web/`, the iOS mailbox and
publishing code, the shared vectors, docs. Earlier notes this builds on: `web.md` (first build), `web-decisions.md`
(D45 to D52, supersedes `web.md` where they differ), `d55-web-backend.md`, `backend-web-integration.md`.

## 1. Gap audit (rows 8.1 to 8.11, 9.1 to 9.9)

Against `docs/10-WEB-BOOKING.md`, `docs/06` section 3 and the prototype (`design/prototype/screens/Bk-*`, `Cl-*`,
`design/screenshots/08-*`, `09-*`). Prototype elements removed by an owner decision (D45 first-visit chips, D46 SMS,
D48 guest names, D49/D55 consent and signatures, D50 manage link in the calendar, D52 portal links) are not gaps.
"Before" is the state found at `1300fac`; "S9" is what this stage changed.

| Row | Screen | Route / files | Before | S9 | Tests |
|---|---|---|---|---|---|
| 8.1 | Bk-1-Page | `/{slug}` `routes/booking/BookingHome.tsx`, `LanguageSheet`, `RuleList`, `Legal` | partial: profile, credentials, services with price, rules, pause notice, per-page language chooser, "Find my appointment", privacy notice; no approval notice | approval notice when she confirms new clients (`booking.requiresApproval`), D42 wording | booking (pause, approval), languages, a11y, security, perf |
| 8.2 | Bk-2-Service | `/{slug}/service` `ServiceStep.tsx`, `summary.ts` | done: services, add-ons (+minutes, price text), guest count 0 to 2 (D48), bottom bar name + total time + summed price | none | booking @core (add-on + guest), interaction, rtl |
| 8.3 | Bk-3-Professional | `/{slug}/professional` `App.tsx` redirect | done: redirects to service (one professional in v1) | none | none (a redirect) |
| 8.4 | Bk-4-DateTime | `/{slug}/time` `TimeStep.tsx`, `Calendar.tsx`, `WaitlistSheet.tsx` | partial: calendar + slots in the business zone, zone warning, soft hold, "just taken" alternatives, waitlist; **no waiting-list offer link** | `/{slug}/time?offer=<key>`: `getHold` fills service, add-ons, guests and time and goes to Bk-5; `createBooking` converts her hold; ended/unknown offer page (`OfferStep.tsx`) | booking (offer converts the hold, ended offer, unknown key), unit (machine, key parser) |
| 8.5 | Bk-5-Info | `/{slug}/you` `YouStep.tsx`, `Field.tsx` | done: name, phone with country picker, e-mail (required, D46), "Good to know" rules | none | booking flows, rtl, interaction |
| 8.6 | Bk-6-Verify | `/{slug}/verify` `VerifyStep.tsx`, `useVerification.ts` | done: 6-digit e-mail code, resend countdown, errors (D46) | none | booking (wrong code, e-mail only, no SMS origin), rtl |
| 8.7 | Bk-7-Questions | `/{slug}/first-visit` `FirstVisitStep.tsx` | done: optional note only (D45) | none | booking flows, unit |
| 8.8 | Bk-8-Confirmed | `/{slug}/booked` `ConfirmedStep.tsx`, `CalendarSheet`, `PersonalLink`, `BookingRules` | partial: channel copy (D31), card, personal link, ICS + Google (D50), rules snapshot (D47); health-form card shown whenever a form exists | the card shows only when the booking's `intakeRequired` says so (first visit or > 12 months) | booking (ICS/Google, health card on/off) |
| 8.9 | Bk-9-Appointment | `/m/{token}` `ManagePage.tsx` | done: status chip, time in zone, confirm presence, running late 10/15/20/30, reschedule/cancel rows per mode, calendar, message, my data, health form when required, check-in after the visit, rules snapshot (D47) | none (see 2: the rules list, price, "her reply to late") | manage, languages, a11y, perf |
| 8.10 | Bk-10-Review | `/{slug}/review` `ReviewStep.tsx` | done: approval (no reason, D42), paused-for-her with message | none | booking (approval, no-show approval, no-show pause) |
| 8.11 | Bk-11-Find | `/{slug}/find` `FindPage.tsx` | done: e-mail + code (D46), list, same answer either way | none | booking |
| 9.1 | Cl-1-Reminder | WhatsApp picture; destinations `/{slug}`, `/m/{token}`, `/m/{token}/cancel`, `/p/{token}` | done (all destinations exist) | none | n/a |
| 9.2 | Cl-2-Portal | `/p/{token}` `PortalPage.tsx` | done: tabs, next session, upcoming, past, journey, aftercare, products, book again; no form links (D52) | none | portal, a11y |
| 9.3 | Cl-3-Rebook | `/p/{token}/rebook`, `/m/{token}/rebook` `RebookPage.tsx` | done: day strip with the recommended day, slots, outcomes confirmed / approval / paused / taken | none (price, see 2) | portal |
| 9.4 | Cl-4-Intake | `/m/{token}/form` `IntakePage.tsx`, `payload.ts`, `crypto/*` | done on the page, **but no real professional published a form**: the iOS app never sent `intake`, so `getFormContext` answered NOT_FOUND for everyone | iOS publishes `profile.intake` (section 3) | sealed (D55, adult @core, minor, retry, key mismatch, 12 months), security, vectors |
| 9.5 | Cl-5-CheckIn | `/m/{token}/checkin` `CheckInPage.tsx`, `lib/image.ts` | done: four feelings, safety notice, note, photo re-encoded (EXIF stripped) with preview and remove | iOS read the sent time wrong (section 3) | sealed (photo + padding, no photo, missing feeling) |
| 9.6 | Cl-6-Cancel | `/m/{token}/cancel` `CancelPage.tsx` | done: free / late with honest warning / message, reason, "reschedule instead" | none | manage, e2e-local |
| 9.7 | Cl-7-MyData | `/m/{token}/data` `MyDataPage.tsx` | partial: rows, copy/delete requests sealed; row label "Health form and consent" (D55 residue) | label "Health form" in 14 localizations | sealed (copy, delete) |
| 9.8 | Cl-8-Reminder | WhatsApp picture; destination `/m/{token}` | done | none | n/a |
| 9.9 | Cl-9-Reschedule | `/m/{token}/reschedule` `ReschedulePage.tsx` | done: direct / request / message modes, current time, slots | none | manage, e2e-local |

## 2. Left on purpose (not built, with the reason)

- **Bk-9 "Maria's rules" list.** `getBooking.rulesText` is parsed but not shown: it is the app's generated wording of
  the same policy snapshot that `BookingRules` already words (D47); showing both says everything twice.
- **Price on Bk-9 and Cl-3.** `getBooking` carries no price snapshot; the current price of the service could differ from
  the price at booking time, so the page shows none rather than a possibly wrong one. Needs a backend field.
- **"What she replied" after "running late"** and **"Message <name>" on an expired-link page**: no field in the API
  (an expired token returns no professional by design). Backend work, not S9.
- **Cl-7 portfolio switch**: shown as status text; there is no server field for a client's choice.
- **Bk-1 profession line and tag chips** of the prototype: `PublicProfile` has no such fields.
- **e2e-local offer leg**: the offer link is covered against the mock; walking it against the real functions needs
  the owner's `offerWaitlistSlot` in the seed (left for the next e2e change).

## 3. iOS changes found by closing the stage

- **The app never published her health form.** `PublishPayloads` now sends `profile.intake = {formVersion, template}`
  (API.md 6.2) built by `PublishPayloads+Intake.swift` from `HealthFormPublication` (current template, the catalog
  of each booking language, the localized "None"). `VaultPublishingSource` reads the current template
  (`currentHealthFormTemplate`, which stores her professions' default as version 1 the first time, so a form answered
  from the page always finds its questions). Kinds: `yesNo`, `choices` -> `multiChoice` with the app's option keys
  and `none` last, `text`. Tests: `PublishIntakePayloadTests` (order, labels per language, none, unknown keys,
  missing language, server schema, no consent text, round trip into `IntakePayload`).
- **Check-in and data-request sent times were lost.** `MailboxMessage` parsed `submittedAt` with `.iso8601`, which
  refuses the milliseconds of the browser's `toISOString()`. `PayloadInstant` is now the one parser for both readers.

## 4. Shared vectors, both ways (`web/test/vectors/`)

| File | Sealed by | Opened by |
|---|---|---|
| `inbox-v1.json` | pyhpke (reference) | page (byte-for-byte reseal), iPhone `InboxVectorsTests` |
| `js-sealed.json` (11 cases, 2 new) | the page (`seal.ts`; the `page-*` intakes also through the page's form code, schema 2) | Python `verify_js.py`, iPhone `EnvelopeOpenerTests` (opener + every payload reader) |
| `swift-sealed.json` (new) | Apple CryptoKit (`generate/generate-swift.swift`) | page suite (hpke-js) and Python, `crypto.cross-implementation.test.ts` |

The Python cross-check had been skipped on every run (it looked for a venv next to the generator; `test-web.sh` makes
it at `web/.venv`); it now runs.

## 5. Exit checks (numbers in `docs/PROGRESS.md`, stage log S9)

- Playwright on Chromium, WebKit and the throttled low-end Android profile (`lowend`: 4x CPU, Slow 4G), axe-core.
- Egress: the guard fails any test on a request to another origin; the egress test now books, seals a form and sends
  a data request. Clear text: no typed answer, question key or payload field name appears in any request; the
  `submitSealed` body is exactly `{token, envelope}`.
- Strict CSP without `unsafe-*`, SRI on every script and stylesheet, the published hash list, no third-party script.
- Lighthouse CI (median of 3, mobile): `scripts/test-web.sh` now prints the medians and the initial JS size.
- Flake fixed: the e2e-local story picked `slots.first()` while the previous day's times were still on screen;
  `chooseDayAhead` now waits for the chosen day to be selected and every listed time to fall on it.

## 6. For the owner (H-tasks)

H8 (real phones, in-app browsers) gains: open a waiting-list offer link from WhatsApp; check the health form shows
her questions in her language after she goes online (it now comes from the app).
