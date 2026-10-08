# Agent notes: backend (stage S8, server half)

Branch `worktree-agent-a243edc65aa8fcdad`, based on `build/v1` at `d3bcc5c`. Owned: everything under `firebase/`, `scripts/test-firebase.sh`, a
5-line opt-in in `scripts/test.sh`, this file. Not touched: `web/`, any iOS file, `docs/PROGRESS.md`, `DESIGN.md`, `docs/14-HUMAN-TASKS.md`.
The iOS half of S8 (`RemoteBookingRepository`, `MailboxService`, outbound queue, `FirebaseAuthProvider`) is NOT started, as instructed.

## 1. State at checkpoint: green

Last full run of `scripts/test-firebase.sh` (22:19, 6 min): **all green**.

| Stage | Result |
|---|---|
| lint (ESLint strict-type-checked, `--max-warnings 0`) | 0 problems |
| typecheck (`tsc`, strict, `noUncheckedIndexedAccess`) / build | ok |
| `npm audit --audit-level=high` | 0 vulnerabilities (needs `overrides` of `@grpc/grpc-js`, kept in package.json) |
| unit (no emulator) | **725** passed |
| Firestore + Storage rules (emulator) | **65** passed |
| use cases on Firestore/Auth/Storage emulators | **245** passed |
| transport (Functions emulator, callable protocol) | **17** passed |

Commits (all on this branch, none pushed): `37b5f79` config split, `d803bc2` API.md, `8452eee` functions package + pure rules + Swift fixture,
`23bb1d7` rules + rules tests, `67d1abe` use cases + first suites, `f7691b4` owner/mailbox/retention/deletion/logging suites,
`a41a41a` unit tests + schemas, `9180a76` transport tests + wrapper + indexes + seed + sms script, `3716d98` READMEs, gate and race tests.

## 2. Commands

```
scripts/test-firebase.sh              all (lint, types, build, audit, unit, rules+use cases, transport). ~6 min. Logs: build/logs/firebase-*.log
scripts/test-firebase.sh static|unit|emulator|transport      one stage (unit takes ~4 s)
RUN_FIREBASE=1 scripts/test.sh fast   iOS fast plan + the server suites (opt in)
cd firebase/functions && npm run lint | typecheck | build | test:unit | gen:schemas | seed | emulators
cd firebase && firebase emulators:exec --config firebase.test.json --project demo-bellohub --only firestore,auth,storage "npm --prefix functions run test:integration -- <file filter>"
node firebase/scripts/sms-regions.mjs [--json]                  SMS allow-list for H4
firebase/scripts/rules-fixtures/generate.sh                      regenerate rules.fixture.json from the Swift sources (needs swiftc)
```
Requirements: Node (ran on 26, `engines` says 22), Java 21, firebase-tools 15. `functions/.secret.local` (fake pepper) is created by the wrapper; it and
`.env.local` (written by the CLI) are git-ignored. Tests use ports 14400/14500/15001/18080/18085/19099/19199 (`firebase.test.json`), not the defaults.
Hard safety rules were respected: only `demo-bellohub`, no deploy, no gcloud, nothing written to `bello-hub`.

## 3. What was built (paths under `firebase/`)

- **Config split**: `firebase.json` (dev target, default ports), `firebase.test.json`, `firebase.prod.json` + `rules/prod/*` (deny-all, the only thing that may touch
  `bello-hub`), `.firebaserc` (default `demo-bellohub`; `bello-hub-deny-all` alias). `firestore.rules`, `storage.rules`, `firestore.indexes.json` (1 composite index +
  TTL overrides), `storage-lifecycle.json`. `README.md` has the exact human deploy steps for dev/staging.
- **functions/** (TypeScript, Node 22 ESM, zod 4, firebase-functions 7, firebase-admin 14): 43 callables + `getIcs` + `appStoreNotifications` + 2 triggers + 2 scheduled jobs.
  `API.md` is the contract; `contracts/schemas.json` is generated; `README.md` explains the layout and the key ideas.
  - `src/lib/time.ts, freeSlots.ts, rules.ts`: pure mirrors of the iOS `FreeSlotsCalculator`, `CancellationEvaluator`, `RegistrationQuota`.
    **Verified against the real Swift code**: `scripts/rules-fixtures` compiles those Swift files and writes `test/fixtures/rules.fixture.json` (100 slot cases incl. every DST gap/fold
    in Lisbon/Madrid/Rome/Berlin/London/New York, 280 cancellation, 40 late, 180 quota cases); 627 unit tests read it.
  - `src/lib/calendar.ts` (the booking transaction design), `bookingCreate.ts` (the single place a booking is made), `registrations.ts` (D42), `deletion.ts`, `contacts.ts`, `keyring.ts`, `ics.ts`, `log.ts`.
  - `src/{public,token,owner}/*.ts` one use case per file; `src/app/registry.ts` + `src/index.ts` wire them.
  - `src/messaging/` (ClientMessenger, email templates in 14 localizations x 7 kinds, disabled WhatsApp + tested Cloud API provider), `src/push/` (interface, FCM payload builder, FCM + emulator senders), `src/auth/`, `src/billing/`.
  - `src/jobs/` (`runCleanup` steps, `runReminders`), `src/triggers/`, `src/http/` (`invokeUseCase` gate, callable wrapper, ICS and Apple webhook handlers).
  - Tests: `test/{unit,rules,integration,transport}`, helpers in `test/support`. `scripts/seed.ts` loads Maria into running emulators through the public API (idempotent).

Coverage of the task list: public reads, availability, `createBooking` transaction vs double booking (2- and 10-way races, exactly one wins), phone verification (Firebase Auth phone
token; emulator uses the real Auth emulator SMS flow), email codes with fixed `123456` in the emulator, approval / "waiting for approval", manage tokens (hashed, 5 max, expiry =
visit end + 7 d), reschedule request + accept/decline, cancel/confirm/running-late, waitlist (+ offer by one-time hold key), ICS, sealed inbox (size caps, key ring, TTL 30 d,
ack, Storage for > 200 KB), D42 counter, rate limits, cleanup/retention jobs with injected clock, cascade deletes (account and client; test scans every collection, Storage and Auth),
push behind an interface, ClientMessenger (email stub/disabled, WhatsApp disabled), plan sync + App Store webhook behind a verifier interface.

## 4. Remaining work, in priority order

1. **Reconcile with the web client** (`web/` on branch `worktree-agent-ac7ea3c725dfcc9b0`, commit 248bedd). It was written against its own assumptions, not API.md. Differences seen
   in `web/src/api/{transport,types}.ts` (the web notes say "this file is the only thing to change"):
   transport = plain GET/POST + `{error:{code}}` vs ours **callable POST `{data}` -> `{result}`, errors `{error:{status,message:CODE,details}}`, POST even for reads**;
   `getSlots` returns `days:[{date,slots}]` (theirs: flat `slots`); `guests` is a number 0-2 (theirs: array of names; the server stores no guest names); soft hold uses `holdKey`
   (theirs: `sessionKey` -> `holdId`); verification is `{method:'phone'|'email', idToken|proof}`; `createBooking` has no `firstVisit` (see issue 1 below) and returns
   `pendingApproval` **without a reason** and `paused` **without scope** (deliberate privacy); `rules` are `rulesText: {locale: string}` (theirs: `RuleLine[]`); profile fields are
   `booking.requiresApproval/acceptingBookings`, `policy`, flat `credentials`, `price:{display,amount}`; waitlist uses `dayFrom/dayTo`, `serviceId` optional; `getBooking` shape differs
   (`actions` already evaluated by the server); portal has no `forms`/`upcoming.manageToken`; no `proReply`/`movedFrom`.
2. **iOS half of S8** (`RemoteBookingRepository`, `BookingSyncService`, `MailboxService`, outbound queue with idempotent ids, `FirebaseAuthProvider`, FCM + silent push, conflict
   detection). Needs from the iOS side: localized strings for the push `loc-key`s (`push.booking.new`, `push.booking.late`, `push.booking.clientConfirmed`, `push.reschedule.request`,
   `push.waitlist.new`) in 14 localizations; pass `appAccountToken` (from `ensureAccount`) to StoreKit; publish `busy` (manual appointments `kind:"appointment"`, time blocks `kind:"block"`,
   **excluding** appointments that came from the link); keep `timeZoneID` equal in `publishProfile` and `publishAvailability`; add `ClientEdit` "stop online booking" -> `setOnlineBookingStopped`.
3. **Apple verifier adapter** (`src/billing/AppleAppStoreVerifier.ts`, H14): only the interface and `UnconfiguredAppStoreVerifier` exist; `syncPlan` and the webhook are fully tested with a fake.
   Plan: `@apple/app-store-server-library` `SignedDataVerifier` with Apple root certs, bundle id `com.bellohub`, app Apple id, environment.
4. **Email provider adapter** (H7): `DisabledEmailProvider` is wired in `createDeps.ts` with a `TODO(HUMAN-H7)`; the adapter is one small class (HTTP API) plus a `defineSecret`.
5. Scheduled functions are not exercised in the Functions emulator (it ignores them without the Pub/Sub emulator); their logic is tested directly (`runCleanup`, `runReminders`).
   Add `pubsub` to the test emulators if a trigger-level test is wanted.
6. `scripts/e2e-local.sh` (S8 exit criterion) needs the web app's Playwright run: not started (needs `web/`).
7. Hosting config is owned by the web agent (`web/hosting.json`); `firebase.json` has no hosting block. Decide whether Hosting rewrites `/api/<name>` to the functions (same-origin, no CORS) or the web calls
   `https://europe-west1-<project>.cloudfunctions.net` (current CORS allow-list: `bellohub.app`, `*.web.app`, `*.firebaseapp.com`).
8. Human tasks (merge into `docs/14-HUMAN-TASKS.md`): H4 dev/staging projects + exact deploy steps in `firebase/README.md`, Secret `PHONE_HASH_PEPPER` (never rotate), SMS allow-list from
   `sms-regions.mjs`, APNs key, budgets, PITR; H5 App Check then `ENFORCE_APP_CHECK=true`; H6 domain; H7 email provider; H13 WhatsApp token + Meta template approval (names are `bellohub_<kind>_<lang>`;
   keep `WHATSAPP_AUTOMATION` equal to the Remote Config flag); H14 Apple root certs; apply `storage-lifecycle.json`; confirm Firestore TTL (`ttl:true` in indexes — if the CLI rejects it, enable in console).

## 5. Deviations from, and extensions of, API.md / docs (all intentional)

Code and API.md agree (a test enforces function names, error table and schemas). Where code/API.md go beyond `docs/10-11`:

- Everything is a **callable** (docs 10 §3 sketches `GET getSlots?...`); only `getIcs` (GET) and `appStoreNotifications` are plain HTTPS.
- Files: rules tests live in `functions/test/rules` (not `firebase/test-rules/`) to keep one npm package; `manageTokenHashes` is an **array** (docs: one hash) so `findBookings`/reminders can mint
  extra links; the health-form template and consent texts are in `intakeForms/{uid}` (function-only), **not** in the world-readable `publicProfiles`; `publicProfiles` allows `get` but **not `list`**.
- `getPublicPage` replaces direct Firestore reads for the web; `features.smsCallingCodes` comes from it.
- The confirmation email is sent **inside `createBooking`** (the server only has the token at that moment), not by the `onBookingWritten` trigger as docs/11 §3 says. The trigger only pushes.
  Reschedule-request and waitlist pushes are sent directly by their functions (no trigger on those collections).
- `getMailboxItem` returns the envelope **inline** (read from Storage by the function) instead of a signed URL.
- Added functions not in docs/11: `ensureAccount`, `reserveRegistrations` (batch), `syncPlan`, `getHold`, `cancelBookingByOwner`, `moveBookingByOwner`, `removeWaitlistEntry`, `markNoShow`
  (mark/forgive/reset), `setOnlineBookingStopped`, `unregisterDevice`, `rebook`, `getIcs`. `publishAvailability` takes `busy` (appointment|block) and the `noShow` policy.
- Collections added: `calendarLocks`, `intakeForms`, `idempotency`, `emailCodes`, `emailProofs`, `emulatorOutbox` (emulator only). `registrations` docs may have `source:'alias'` (client id linked to an already counted phone; not counted).
- `freeLimit` in responses is `number` (10), not a literal type.
- D42 specifics (ASSUMPTION candidates): a **confirmed** booking from a new phone registers that phone immediately (so the 11th online client cannot slip through before the app syncs);
  a pending request does not count until `respondBookingRequest` approves it (then `needsSubscription` if no plan/limit hit); the app's later `reserveRegistration(clientId, phone)` for a counted phone is
  `alreadyCounted`; deleting a client never touches the counter/ledger; `deleteAccount` deletes the ledger too (consistent with ASSUMPTION-18: no tombstone).
- Total booking time = service + add-ons + guests x service minutes (guests are the same service, no add-ons) — ASSUMPTION candidate, please check against iOS `NewAppointment`.
- `respondBookingRequest` has no `message` field (a free-text reply by email could carry clinical content); the "no-show/online-booking" server state (`contacts`) is pseudonymous (HMAC of the phone) and
  lives until the professional deletes the client or the account: the privacy policy may want one sentence on it (`legal/README.md` fact 5 only lists bookings and envelopes).
- Email texts in 12 languages written by me (es-419 reads es-MX, en-GB reads en), unreviewed (D41). 7 kinds: code, confirmed, pending, approved, declined, cancelled, moved.
- Emulator-only hooks: email code `123456`, `emulatorOutbox` records push kinds/ids and a counter per email (never an address or text).

## 6. Known issues / limits

1. **First-visit answers (Bk-7)**: the web collects `heardFrom / hadBefore / note`; the server stores only `note` (<= 300 chars) on the booking. Either send them sealed, or drop them, or decide to store them.
2. `consumeAppCheckToken` (replay protection) is not used; App Check enforcement is a **runtime** parameter (`ENFORCE_APP_CHECK`, default false) checked by `invokeUseCase`, because the SDK option
   reads a Param while functions are being defined (warning x43) — so the platform-level rejection never happens and an invalid token is just logged by the SDK and treated as missing.
3. Contention: bookings of one professional serialize on `calendarLocks` (25 retries then `TRY_AGAIN`). Fine for one chair; a viral link could see `TRY_AGAIN` under heavy bursts (tested to 10 concurrent).
4. Rate limits are fixed windows keyed by HMAC; the client IP is the last `X-Forwarded-For` entry (1 trusted hop, `trustedProxyHops`). Behind Hosting rewrites this may need `2`. Untested outside the emulator.
5. TTL policies in `firestore.indexes.json` use `"ttl": true`; I could not validate that key against the live CLI (no project). The cleanup job is the guarantee either way.
6. `getSlots` with `rescheduleToken` ignores pause on purpose (a pause does not stop moving a booked visit, D15).
7. Scheduled jobs/`sendReminders` were never run on a real scheduler; `sendReminders` mints a new manage link per reminder (<= 5 valid).
8. Node 26 locally vs `engines: 22`: the emulator warns and runs on the host Node; not run on Node 22.

## 7. Adversarial review wanted (security-relevant)

- `firestore.rules` and `test/rules/*` (can any client write `plan`, `registrations`, `inboxKeyring`, `slug`, `deletion`, bookings, inbox; list profiles; read another uid via collection-group query?).
- D42 counter: `lib/registrations.ts`, `lib/bookingCreate.ts` (registration on confirm), `owner/respondBookingRequest.ts`, `lib/deletion.ts` (never touches counter on client delete). Look for any path that
  increments without the calendar lock, double-counts a phone, or lets `needsSubscription` slip into `confirmed`.
- Double booking: `lib/calendar.ts` lock usage — every writer of occupied time must read+bump `calendarLocks/{uid}` (createBooking, holdSlot, rescheduleBooking, respondRescheduleRequest, offerWaitlistSlot,
  moveBookingByOwner, registrations). Check nothing writes `startsAt` without it.
- Sealed mailbox: `public/submitSealed.ts` (key ring check, size caps, retry/CONFLICT semantics, Storage object ownership on races), `owner/getMailboxItem.ts`, retention of envelopes (`jobs/steps/expireEnvelopes.ts`, `reconcileBlobs.ts`).
  The server never decrypts (a test greps for decryption primitives) and never logs envelope fields.
- Tokens: `lib/bookingAccess.ts` (SHA-256 with `manage:` prefix; 5 max; expiry = `purgeAt`), idempotent replay in `bookingCreate.ts` returns an extra token for anyone holding the idempotency key + same request.
- Verification: `auth/FirebasePhoneVerifier.ts` (provider must be `phone`, <= 10 min), email proofs (`lib/emailProof.ts`, single use), `findBookings` (mints links after proof only).
- Logging: `lib/log.ts` closed field list; `test/integration/logging.test.ts` searches a whole day of logs for personal data.
- Rate limits / abuse: `config/limits.ts`, `lib/rateLimit.ts`; email cost caps per owner.
- App Check handling (item 2 above) and CORS list in `http/callable.ts`.

## 8. API summary (full contract: `firebase/functions/API.md`)

Transport: Firebase callable over HTTPS, region `europe-west1`; `POST <base>/<name>` body `{"data":…}` -> `{"result":…}`; errors `{"error":{"status","message":"<CODE>","details"}}`;
headers `X-Firebase-AppCheck`, `Authorization: Bearer <ID token>` (owner functions).
- Public/token (web): `getPublicPage getSlots holdSlot getHold sendEmailCode verifyEmailCode createBooking findBookings joinWaitlist getBooking confirmPresence reportLate cancelBooking
  rescheduleBooking requestReschedule rebook getFormContext submitSealed getPortal` + `GET getIcs`.
- Owner (iOS): `ensureAccount reserveRegistration reserveRegistrations syncPlan isSlugAvailable claimSlug publishProfile publishAvailability updateInboxKey respondBookingRequest
  respondRescheduleRequest cancelBookingByOwner moveBookingByOwner offerWaitlistSlot removeWaitlistEntry markNoShow setOnlineBookingStopped publishPortal getMailboxItem
  acknowledgeMailboxItem registerDevice unregisterDevice deleteClientServerData deleteAccount`.
- Non-callable: `onBookingWritten onInboxItemCreated cleanupJob sendReminders appStoreNotifications`.
- Outcomes that are not errors: `createBooking` -> `confirmed | pendingApproval | slotTaken{alternatives} | paused{pausedUntil?}`; `respondBookingRequest` -> `confirmed | declined | needsSubscription`.
- Error codes: `INVALID_ARGUMENT UNAUTHENTICATED APP_CHECK_REQUIRED FORBIDDEN NOT_FOUND TOKEN_EXPIRED RATE_LIMITED VERIFICATION_FAILED INVALID_CODE NOT_ALLOWED CONFIRMATION_REQUIRED BOOKING_NOT_ACTIVE
  SLUG_TAKEN KEY_MISMATCH PAYLOAD_TOO_LARGE CONFLICT NOT_CONFIGURED TRY_AGAIN INTERNAL`.

## 9. Findings worth keeping (for PROGRESS.md)

- Foundation's DST semantics were measured, not assumed: a wall time inside a spring-forward gap resolves to the first valid instant after the gap; a repeated time to its first occurrence. `lib/time.ts` mirrors it
  without a library and matches 100 Swift-generated cases.
- `firebase-functions@7` evaluates a boolean Param passed as `enforceAppCheck` while defining each function (warning per function); the CLI writes list Params to `.env` as `a,b` but the SDK parses JSON — use a string Param.
- In Firestore triggers `getApps().length > 0` is not "the default app exists"; use `getApp()` in a try.
- `typescript-eslint@8` does not support TypeScript 7 yet: the package pins `typescript ~6.0.3`.
- The Auth emulator supports headless phone sign-in (`accounts:sendVerificationCode` -> `/emulator/v1/projects/<p>/verificationCodes` -> `accounts:signInWithPhoneNumber`), which the transport tests and the web e2e can use.
- The Functions emulator starts one worker per function on first call (~4 s each), so the transport suite samples functions instead of calling all 43 empty.
