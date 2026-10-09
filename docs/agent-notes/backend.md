# Agent notes: backend (stage S8, server half)

Branch `worktree-agent-a243edc65aa8fcdad`, based on `build/v1` at `d3bcc5c`. Owned: everything under `firebase/`, `scripts/test-firebase.sh`, a
5-line opt-in in `scripts/test.sh`, this file. Not touched: `web/`, any iOS file, `docs/PROGRESS.md`, `DESIGN.md`, `docs/14-HUMAN-TASKS.md`.
The iOS half of S8 (`RemoteBookingRepository`, `MailboxService`, outbound queue, `FirebaseAuthProvider`) is NOT started, as instructed.

## 1. State at checkpoint: green

Last full run of `scripts/test-firebase.sh` (2026-10-09, ~7 min): **all green**.

| Stage | Result |
|---|---|
| lint (ESLint strict-type-checked, `--max-warnings 0`) | 0 problems |
| typecheck (`tsc`, strict, `noUncheckedIndexedAccess`) / build | ok |
| `npm audit --audit-level=high` | 0 vulnerabilities (needs `overrides` of `@grpc/grpc-js`, kept in package.json) |
| unit (no emulator) | **739** passed |
| Firestore + Storage rules (emulator) | **65** passed |
| use cases on Firestore/Auth/Storage emulators | **258** passed (13 of them in `securityReview.test.ts`) |
| transport (Functions emulator, callable protocol) | **17** passed |

Commits (all on this branch, none pushed): `37b5f79` config split, `d803bc2` API.md, `8452eee` functions package + pure rules + Swift fixture,
`23bb1d7` rules + rules tests, `67d1abe` use cases + first suites, `f7691b4` owner/mailbox/retention/deletion/logging suites,
`a41a41a` unit tests + schemas, `9180a76` transport tests + wrapper + indexes + seed + sms script, `3716d98` READMEs, gate and race tests,
`be05846` these notes, `b0a1aaa` security review fixes + tests, `f6c4655` Apple verifier adapter (H14), `af14857` Resend email adapter (H7).

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
Requirements: Node (ran on 26, `engines` says 22), Java 21, firebase-tools 15. `functions/.secret.local` (fake pepper + `EMAIL_API_KEY=unset`) is created/completed by the wrapper; it and
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
  - `src/messaging/` (ClientMessenger, email templates in 14 localizations x 7 kinds, `ResendEmailProvider` (H7, on when `EMAIL_FROM` + secret `EMAIL_API_KEY` are set), disabled WhatsApp + tested Cloud API provider),
    `src/push/` (interface, FCM payload builder, FCM + emulator senders), `src/auth/`, `src/billing/` (`AppleAppStoreVerifier` on `@apple/app-store-server-library`, on when `certs/apple/*.cer` exist, H14).
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
3. **Apple verifier (H14), human part only**: drop Apple's root `.cer` files in `functions/certs/apple/` (README there), set `APPLE_ENVIRONMENT=Production` + `APPLE_APP_ID` for the
   production project, then verify one sandbox purchase end to end (`syncPlan`) and one App Store Server Notification (the library's signature check is not exercised by any test).
4. **Email (H7), human part only**: Resend account in the EU region with a signed DPA, verified sender domain, `EMAIL_FROM` parameter and the `EMAIL_API_KEY` secret
   (`firebase functions:secrets:set EMAIL_API_KEY`; the secret must exist for any deploy, a placeholder is fine while `EMAIL_FROM` is empty). Vendor swap = replace `ResendEmailProvider.ts`.
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

## 7. Security review 2026-10 (the list of the previous section 7, item by item)

Tests: `test/integration/securityReview.test.ts` (13), plus a CORS test in `test/unit/libraries.test.ts`. Each "fixed" line had a failing test first.

- **Rules**: fine. No client write to `plan`, `registrations`, `inboxKeyring`, `slug`, `deletion`, bookings or inbox (only `accounts.locale` and own `devices/*/tokens`); `publicProfiles` get-only;
  collection-group queries on `items`, `tokens`, `registrations` denied (`test/rules/firestore.rules.test.ts`). Storage: deny all.
- **D42 counter**: fine. Every increment (`writeRegistration`, `applyRegistrations`) runs in a transaction that read and bumps `calendarLocks/{uid}`; a phone is keyed by `contacts.registered`
  so it never counts twice; `needsSubscription` returns before any write in `respondBookingRequest`; `deleteClientServerData` never touches the counter (test "never lowers the count").
- **Double booking**: fine. All seven writers of `startsAt` read + bump the lock (createBooking, holdSlot, rescheduleBooking, respondRescheduleRequest, offerWaitlistSlot,
  moveBookingByOwner, registrations); test "moving a booking races a new booking". Residual by design: `moveBookingByOwner` skips the free-slot check (she may work outside her hours).
- **Sealed mailbox, Storage race**: **fixed**. Two different ciphertexts under one `itemId` shared one object name; the loser's clean-up deleted the winner's bytes. Object names now
  carry the ciphertext hash (`inbox/{uid}/{itemId}.{ctHash16}.json`); `reconcileBlobs` deletes any object the item does not point at.
- **Sealed mailbox, volume**: **fixed**. 5/hour per booking let one link store ~120 x 3 MB a day for 30 days; now at most 20 unacknowledged items per booking (`RATE_LIMITED`, `details.maxItems`).
- **Sealed mailbox, key ring / caps / server never decrypts**: fine (`isKnownKey`, size caps per kind, source grep for decryption primitives). Residual: a retired key is still accepted for
  new envelopes (the app keeps old private keys; after a compromise-driven rotation the owner may want `updateInboxKey` to drop keys, not implemented).
- **Manage tokens**: fine. SHA-256 with `manage:` prefix, 5 per booking, expiry = `purgeAt`, 22-char base64url. **Idempotent replay: fixed**: the key + same request alone minted a new
  token; a replay now needs the same email proof (hash stored on the idempotency record) or a fresh valid one, phone tokens are re-verified on every call.
- **Verification**: fine. Phone: provider `phone`, `auth_time` <= 10 min; email proof single use (`usedAt`), 30 min, bound to the email hash; codes hashed, 5 attempts, 10 min, 30 s resend;
  `findBookings` mints links only after proof. **Rate allowance: fixed**: made-up proofs no longer spend the phone's, the address's or the professional's counters, only the caller's IP.
- **Logging**: fine. Closed field list with shape checks; a rejected input whose field NAME is a phone never reaches the logs (test).
- **Rate limits**: fine, and now ordered IP -> proof -> others. Residual: fixed windows, one trusted proxy hop (set `trustedProxyHops: 2` behind Hosting rewrites, untested outside the emulator).
- **App Check**: residual (unchanged): enforcement is the runtime param `ENFORCE_APP_CHECK` (default off) checked in `invokeUseCase`; `consumeAppCheckToken` replay protection unused.
- **CORS**: **tightened**. `*.web.app` / `*.firebaseapp.com` allowed any Firebase site; now only `bellohub*` / `bello-hub*` site ids (preview channels included). If the web agent's
  Hosting site id does not start with one of those, add it to `ALLOWED_ORIGINS` in `src/http/callable.ts` (and the unit test).
- **Input edges**: fine (impossible dates, unknown zones, huge numbers, oversized envelopes, bidi/invisible characters in names: tested).

### API.md changes in this round (for the web agent)
1. Section 1, CORS: the exact allow-list (`bellohub*`/`bello-hub*` Hosting sites only).
2. 5.8 `createBooking`: a replay with the same `idempotencyKey` must carry the same verification (same email `proof`, or a fresh one); phone tokens are checked every time.
3. 5.15 `submitSealed`: new cap, at most 20 unacknowledged items per booking -> `RATE_LIMITED` with `details.maxItems`.
No request or response shape changed; `contracts/schemas.json` is unchanged.

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
- A `defineSecret` that is bound to a function must exist in Secret Manager for the deploy to pass; an unset one reads as `""` (with a warning) at run time, so `createDeps` reads
  `EMAIL_API_KEY` only after `EMAIL_FROM` is set. `@apple/app-store-server-library@3.1.0` (CJS) imports fine from ESM; `SignedDataVerifier` requires `appAppleId` in Production and
  checks bundle id + environment itself (the adapter checks them again before a plan can unlock).
