# Functional audit — 2026-10-14

## Scope and working state

User requested a functional audit across professional iPhone workflows and client web workflows, including realistic routines, interrupted flows, redundant actions, misleading controls and consistency across app/web/server. Preserve the current visual design. Diagnose first; production fixes are not part of this audit. Prioritize economical testing and preserve progress across model changes. User monitors plan usage and changes models manually.

Status: first automated functional-audit delivery complete. No production code changed. Repository was clean at start. Audit fixtures and two stale UI-test setups were changed, plus this report. This is diagnostic evidence, not a release approval or an assertion that every possible screen interaction is correct.

## Evidence collected

- `scripts/test-firebase.sh unit`: 1,005 tests passed. Log: `build/logs/firebase-unit-20261014-010118.log`.
- `scripts/test-web.sh quick`: passed lint, types, localization, contrast, privacy, unit tests and production build. Initial JavaScript 51 KB gzip / 80 KB budget. Log: `build/logs/test-web-quick-20261014-010118.log`.
- Selected iOS suites: 53 tests in six suites passed. NewAppointmentViewModel, RescheduleViewModel, AppointmentService, ClientLinkService, BookingSyncService, AgendaDigestService. Log: `build/logs/test-Fast-20261014-010134.log`. Four existing SwiftLint warnings; no production edits to resolve unrelated lint in this diagnostic task.
- `scripts/e2e-local.sh`: 9 passed, real functions on local demo emulators. Booking, move, sealed intake, cancellation, smart slots and verification fallback. Log: `build/logs/e2e-local-20261014-010215.log`.
- `LIGHTHOUSE=0 scripts/test-web.sh full`: 230 passed, 15 skipped, 3 failed (same Arabic-digit journey in Chromium, WebKit and low-end Chromium). Mock-backed browser coverage; Lighthouse deliberately omitted. Log: `build/logs/test-web-full-20261014-010214.log`.
- New Swift characterization probes: 2 passed. They demonstrate duplicate import after successful manual registration and silent registration failure when offline. Log: `build/logs/test-Fast-20261014-010546.log`.
- New isolated server guarantee probes: 7 failed / 2 control cases passed, as expected for the defects below. The control cases verify that public booking concurrency and public cancellation behave correctly. Log: `build/logs/functional-audit-server-20261014.log`. These probes are deliberately outside default regression discovery. Run from `firebase/`: `firebase emulators:exec --config firebase.test.json --project demo-bellohub --only firestore,auth,storage 'cd functions && npx vitest run --config test/audit/vitest.config.ts'`.
- Functions typecheck and lint of new audit fixtures: passed.
- Entire iOS Fast plan: 2,532 tests in 378 suites passed. Log: `build/logs/test-Fast-20261014-010702.log`. Four existing SwiftLint warnings and non-failing CloudKit teardown messages; real iCloud synchronization is not established by this run.
- Firestore rules and backend integration: 67 rule tests and 332 integration tests passed. Log: `build/logs/firebase-rules-and-use-cases-20261014-010724.log`.
- Initial twelve selected professional UI scenarios under XCUITest on iOS 26.5: 10 passed, 2 failed on stale client-creation fixtures (see test-maintenance finding). Photo-first treatment, draft preservation, services/add-ons, agenda, booking settings, approval, rescheduling, cancellation, locked-record correction and private-note-free export passed. Log: `build/logs/test-Full-20261014-010856.log`.
- The two corrected client UI scenarios passed: creation/search/profile/name edit, and export-before-delete with disappearance from the list. Log: `build/logs/test-Full-20261014-011913.log`. In total, all 12 selected professional UI scenarios are verified, with the stale-fixture failures documented rather than hidden.

## Findings and hypotheses

### F01 — Manual scheduling allows conflicting professional time (confirmed)

`NewAppointmentViewModel.canBook` does not reject scheduling conflicts, and `bookAsync` saves the visit. `AppointmentService.book` saves without overlap validation. `RescheduleViewModel.canConfirm` also allows conflict. Existing test `overlapIsHerDecision` explicitly verifies that conflicting visits are saved; this test passed in this audit. This conflicts with the user's stated requirement that one professional cannot perform two services simultaneously. Non-overlapping processing time may be a valid exception; inspect `VisitTiming` before recommending indiscriminate full-interval blocking.

Server `createBookingCore` checks availability under a shared calendar lock for web bookings. `moveBookingByOwner` intentionally bypasses scheduling checks. `registerManualBooking` checks neither other visits nor the calendar lock. Need isolated emulator probes covering those entry points and cross-origin races.

### F02 — Manual manage-link registration duplicates visits and disconnects their updates (reproduced)

`NewAppointmentViewModel.bookAsync` saves a local appointment, then calls `ClientLinkService.registerManualBooking`. The latter creates a server booking using the local appointment UUID, caches its link, but does not write `bookingID` onto the local appointment. `BookingImporter` finds existing mirrors solely by `bookingID`. The new Swift probe executes the real view model and importer with injected repository fixtures: successful registration leaves the original unlinked, import creates another appointment with a different UUID, raises a conflict with the original, and moving the original generates no server change. This reproduces the orchestration/pure-import defect, not physical-device network delivery.

### F03 — Manual appointment is published as anonymous busy AND as server booking (reproduced)

`PublishPayloads.busy` includes manual appointments with `bookingID == nil`. F02's manual appointment qualifies even after successful registration. Server `loadOccupied` unconditionally includes `availability.busy`, while `excludeBookingId` only excludes BookingDocs. Two real-emulator probes confirm that the own current interval remains blocked during rescheduling and that cancellation does not free the anonymous busy interval. The old local copy can keep publishing the interval even after the linked copy follows cancellation.

### F04 — Manual registration silently fails offline with no durable retry (reproduced)

`ClientLinkService.registerManualBooking` catches all errors and returns nil. The Swift probe injects `.unreachable`: booking returns true, `didBook` is true, no save error is shown, no exclusive link exists, and the visit stays unlinked. Outbound queue has no register-manual-booking action. Local booking success is legitimate offline, but web management is missing and registration is not automatically retried. Confirmation falls back to the general booking page. Valid clients without phones cannot satisfy server E164 contract either.

### F05 — Manual registration drops service identity, add-ons, guests and policy snapshots (partly reproduced)

`registerManualBooking` stores `serviceId: 'manual'`, `addOns: []`, `guestCount: 0`, and does not store extra/processing timing, `rulesText` or `noShowPolicy`. Local appointment has these details. Total interval is preserved. The emulator probe confirms missing no-show snapshot; metadata omissions are visible directly in the write and schema. Manual services with processing time are consequently treated differently in web availability. Detailed late-cancellation counts after policy changes have not been separately exercised.

### F06 — Web rescheduling for a manual booking sends an invalid service identifier (reproduced)

Manual registration returns `service.id = 'manual'` on the manage page. `ReschedulePage` sends this exact identifier to `getSlots`, whose input contract requires UUID even when a valid `rescheduleToken` is supplied. The emulator probe reproduces refusal before the handler can use the booking's duration. The page advertises direct rescheduling but cannot load its free times. Manual rebooking has the same invalid-identity risk; not separately browser-tested.

### F07 — Rebooking an appointment with guests silently loses the guests (reproduced)

`RebookPage` loads `guestCount` from the old booking and asks `getSlots` using this count. Its submit call sends `serviceId` and `addOnIds`, but not guests. Server `rebook` explicitly resets guests to zero whenever either offer selector is provided. Emulator replay of the web's actual payload, after an appointment for client + one guest, creates a one-person booking (60 minutes instead of 120). Availability selection and the submitted appointment disagree.

### F08 — Arabic-Indic phone digits are valid in normalization but rejected by double-entry validation (reproduced in three browser projects)

`YouStep.submit` first accepts `normalizePhone(...)`, then compares `phone.replace(/\D/g, '')` with the confirmation field. JavaScript `\d` is ASCII-only, so two matching Arabic-Indic numbers yield empty `confirmDigits` and a mismatch error. The client never reaches the code step. Existing RTL end-to-end case fails in Chromium, WebKit and throttled Chromium. This is a product bug rather than a missing wait: failure state remains on the contact screen and the validation code explains it.

### Explicitly unfinished features (not automatically bugs)

Team is a static future-feature screen (D5); AI settings have disabled controls and voice availability stub (D53); Google Calendar is marked coming soon. Distinguish communicated product limitations from broken controls.

### Test maintenance finding — client setup no longer matches validation

Initial selected UI runs failed in `ClientsUITests` and `ClientDataDeletionUITests` immediately after saving a new client. The tests supply name only, or name + phone, whereas `ClientFormRules` and its passing unit tests require phone, email and confirmation of both for new clients. Neither failure established a defect in deletion or profile navigation. Updated only the two test fixtures to enter valid contacts; production validation is unchanged. Both complete journeys passed on rerun.

### Capacity follow-up — anonymous busy publication silently truncates

`PublishPayloads.busy` keeps the nearest 600 intervals, and its existing `busyCap` unit test confirms this behavior. The booking window can reach 365 days. A professional with more than 600 manual visits/blocks in that window can lose later busy intervals from the published schedule. This is a code-based capacity risk, not a separately reproduced 601-visit browser story. Prefer aggregation/partitioning or explicitly reduce the offered horizon to complete coverage; never advertise omitted busy time as free.

## Journey coverage

| Journey | Realistic variations | Evidence / next action |
|---|---|---|
| Set up professional | different beauty categories, missing profile/service/hours/address | Complete unit/static checks; booking-settings UI; all-category physical routines not covered |
| Configure catalog | disable/delete service already booked; change duration/timing; add-ons and guests | Complete unit plan; services/add-on UI; F05/F07 metadata inconsistency |
| Configure agenda | lunch, days off, blocks, buffer, processing time, DST/business zone | Complete unit/integration plans; real-server smart-slot story; settings/calendar UI |
| Make manual appointment | different client overlapping, registration, missing phone, offline | Existing conflict test + new server/Swift probes; F01–F06 |
| Client books | code failure, trusted device, unavailable time, duplicate click, simultaneous requests | Public concurrency integration tests; real-browser stories; mock browser projects; F08 |
| Approve/decline | stale request, unavailable time, pending approval expiry | Backend integration/unit plans; approve and accept-reschedule UI |
| Manage existing visit | presence, running late, move, cancel, max moves, deadline | Integration and browser plans; manual parity probes F03/F05/F06 |
| Professional changes visit | move/cancel offline, relaunch, sync after stale read | Complete unit plan; calendar/cancel UI; owner/manual probes F01/F02/F04 |
| Waitlist | no availability, offer hold, expiry, competing bookings | Existing backend integration and mock browser plans; no physical WhatsApp send |
| Client records | duplicate identity, archive/merge, import, interrupted edit | Complete unit plan; new/edit-client UI; bulk-import UI not separately replayed |
| Treatment and return | start/register, discard/save draft, complete, next session, photos | Complete unit plan; photo-first finalization/draft UI; rebook probe F07 |
| Forms and privacy | intake, repeat intake, check-in, request data/deletion | Real sealed-intake story; unit/integration/browser coverage; record export/client-delete UI |
| Messaging and settings | reminder vs opened chat, manage link vs page, permissions, sign-out | Complete unit and mock browser plans; code review of fallbacks; no real provider delivery |

## Priority and recommended implementation order

| Priority | Finding | User-facing consequence | Economical correction |
|---|---|---|---|
| P1 | F02 duplicate/unlinked manual visit | One real appointment becomes two; editing the original does not update its web booking | Persist the returned booking identity on the same local visit; recover old copies using the known appointment UUID while preserving records and notes |
| P1 | F03 duplicate busy interval | Cancelled time stays unavailable; moving a visit can leave old time blocked | Publish each occupied interval from one authoritative source; link registration and remove anonymous busy together, with reconciliation for existing records |
| P1 | F06 manual reschedule cannot load | A promised client action fails before available times appear | Let token rescheduling resolve its own offer without requiring a catalog UUID; retain actual service identity when known |
| P1 | F01 professional can double-book | Two clients are promised overlapping hands-on time | Apply one occupancy validation at save/move and server registration/move; serialize all reservation mutations with the existing calendar lock |
| P1 | F07 returning guest disappears | Wrong headcount and shorter booked duration than the availability search | Make rebooking offer explicit and consistent across getSlots and submit, including guest count; test duration and headcount |
| P2 | F04 offline registration has no retry | A locally saved appointment never receives its personal management link automatically | Durable, idempotent registration queue plus visible pending-link state; keep offline local work available |
| P2 | F05 manual metadata/snapshots lost | App and web describe different details and can apply different rules | Register the same service/add-on/guest/timing and policy snapshots used by the local visit |
| P2 | F08 Arabic digit double entry | Valid contact cannot advance to verification | Normalize both confirmation fields with the shared digit/phone normalizer before comparing |

Treat F02/F03/F05/F06 as one manual-booking integration repair. Fixing only a button label or hiding duplicate rows would leave the underlying split state intact. None of these corrections requires a paid service, new SDK, or frontend redesign.

### Guarantee boundary when offline

The app can create and move visits locally while the client site continues accepting bookings on the server. A phone without connectivity cannot know a booking made elsewhere or reserve a new server interval atomically. A strict cross-channel guarantee therefore needs a clear pending/confirmed distinction for offline scheduling, followed by server confirmation and conflict handling. Records and other local work can stay offline-first. This is a product decision required for the user's absolute single-professional scheduling rule, rather than something a local warning alone can guarantee.

### Scheduling nuance across professions

Existing `VisitTiming` supports processing time (for example, a product acting while the professional is free). Validate the occupied hands-on segments and buffers, not blindly every minute of the full service envelope. Whether another service for the same client is physically compatible during processing is a separate rule; exact duplicate bookings for the same client/professional should not be accepted as an accidental second visit.

## Flow improvements, distinct from confirmed bugs

- Distinguish “saved on this iPhone”, “confirmed on the booking page”, and “personal link pending” in the existing confirmation area.
- Keep outside-hours warnings separate from impossible occupied-time conflicts; they represent different decisions.
- For rebooking after a removed service, offer the active catalog or contact path rather than a generic failed slot load. This is code-based follow-up, not a separately reproduced browser scenario.
- Keep shared entry points (Home, Calendar, client profile, return after treatment) routed to the same booking implementation. Multiple useful entry points are not themselves redundant; F02's duplicated appointment is actual redundant state.
- Team, Google Calendar and on-device AI availability should stay clearly labelled as future/unavailable functionality. They were not counted as broken buttons where the limitation is already communicated.

## Realistic routine scenarios behind the audit

1. A professional adds a telephone appointment, sends the client's personal link, and the phone synchronizes. There must still be one visit, and both parties must change the same visit. This directly exposed F02/F03/F06.
2. A returning client books the same service for herself and an accompanying person. The duration used to offer the time must match the duration booked. This exposed F07.
3. A fully occupied professional receives a second request while making a manual booking or moving a visit. One client must receive an alternative rather than a conflicting confirmation. Existing public concurrency controls passed; owner/manual paths exposed F01.
4. The professional loses connectivity while creating a visit, resumes work, and later reconnects. Local work should remain available, while pending web registration should become visible and retry safely. This exposed F04.
5. A client cancels before the deadline while the professional's phone is locked or offline. The server should release the time immediately; a second anonymous copy must not keep blocking it. Public cancellation controls passed; manual publication exposed F03.
6. A professional registers a treatment, leaves midway, resumes the draft, finalizes it, corrects an old record with a reason and exports the client's copy. Selected UI scenarios and the complete unit plan cover these actions.
7. A client uses a different numeral system on the contact form. Matching contact input should remain matching after normalization. This exposed F08 in three browser projects.

The interactive fixtures use an esthetician named Maria. Profession catalogs, defaults and health-form rules for all supported categories are included in the existing unit/static checks, but this audit does not claim a complete physical-day simulation for each profession.

## Test fixture interpretation

The dedicated TypeScript audit cases express desired product guarantees and currently fail. They are isolated under `test/audit`, excluded from the four normal Vitest projects, and intentionally runnable only with their explicit config. Their failed assertions are reproduction evidence; they are not a passing release gate. The new Swift cases characterize the current defects and pass when the observed split behavior exists; they must be inverted or replaced with repaired-behavior regression checks when the fixes are implemented.

## Handoff and remaining verification

The next engineering action is to repair the manual-booking identity and scheduling guarantees together, then turn the opt-in failing cases into normal regression checks. Production fixes were not implemented during this audit.

Real physical WhatsApp/Instagram browser checks, real email/push delivery, iCloud two-device sync and App Store transactions cannot be claimed verified by local tests. A complete exploratory click-through of every screen, real camera permissions and every profession's physical workflow remains additional coverage. Bulk imports, archival/merge and broader settings have unit coverage here, not a newly replayed UI journey for every variation.

Four pre-existing SwiftLint warnings remain recorded in the build logs. The 3 existing web failures and 7 failing isolated server guarantees remain open defects, not successful checks.
