# 11 · Backend (Firebase)

Scope: operational data for booking, the sealed mailbox, push, plan mirroring and deletion. **It never holds clinical data** (`06-PRIVACY-SECURITY.md`). Everything is in `firebase/` in the repo and runs on the **Firebase Emulator Suite** with no cloud project (a human creates the real projects, H4). The iOS app reaches it only through `BookingRepository`; the web app only through HTTPS functions.

## 1. Projects and environments

Three Firebase projects (created by the owners with Auth, billing, APNs and App Check already set up, H4): `bellohub-dev`, `bellohub-staging`, `bellohub-prod`, selected with `firebase use`/`.firebaserc` aliases (read `.firebaserc` and `firebase projects:list` for the real ids). **Region (cannot change later), decided in D29**: Firestore multi-region `eur3`, Functions `europe-west1`, Storage `EU`. **The Firestore database is not created yet: you create it in S0** (see `03-BUILD-PLAN.md`). Config per environment lives in `firebase/config/<env>.json` (non-secret) and Secret Manager (secrets). Remote Config holds the feature flags (`whatsAppAutomation`, minimum app version).

Repo layout:

```
firebase/
  firebase.json  .firebaserc  firestore.rules  firestore.indexes.json  storage.rules
  functions/ (TypeScript, Node 22, ESM) src/{public,owner,triggers,jobs,lib,messaging}/ test/
  test-rules/ (emulator tests for rules)
  scripts/ (seed.ts for emulator demo data from the prototype fixtures)
```

## 2. Data (collections; field lists in `05-DATA-MODEL.md` §2)

All writes by Functions with the Admin SDK except where "owner" is stated. Documents carry `schemaVersion`. Dates are Firestore `Timestamp` (UTC); the business `timeZoneID` is stored where times are shown.

- `accounts/{uid}`: `phone`, `slug`, `countryCode`, `locale`, `plan {state, expiresAt, source}`, `inboxKeyring [{keyId, pub, createdAt, retiredAt?}]`, `deletion {requestedAt?}`, `createdAt`. Owner may update only `locale` and device-related non-sensitive fields; plan and deletion are function-only.
- `slugs/{slug}`: `ownerUid` (unique claim; created in a transaction by `claimSlug`).
- `publicProfiles/{slug}`: published snapshot (see `05`). Owner writes through `publishProfile` (validated and sanitized, size-limited, rule texts per locale, `inboxKey`). Public read.
- `availability/{uid}`: weekly rules, breaks, days off, `bufferMinutes`, `minNoticeHours`, `maxDaysAhead`, `blocks [{startsAt, endsAt}]`, `timeZoneID`, `updatedAt`. Function-only read (the page calls `getSlots`).
- `bookings/{bookingId}`: `ownerUid`, `serviceId`, `serviceName`, `durationMinutes`, `addOns`, `guestCount`, `startsAt`, `endsAt`, `status` (`confirmed`, `pendingApproval`, `cancelledByClient`, `cancelledByPro`, `declined`, `completed`, `noShow`), `client {name, phone, email?, locale}`, `manageTokenHash`, `origin`, `clientConfirmedAt?`, `lateByMinutes?`, `rescheduleCount`, `createdAt`, `purgeAt` (= `endsAt` + 7 days). Owner reads through query by `ownerUid`; the client only via functions with the token.
- `holds/{id}`: `ownerUid`, `startsAt`, `endsAt`, `expiresAt` (5 min), `sessionKeyHash`. Firestore TTL on `expiresAt`.
- `inbox/{uid}/items/{itemId}`: envelope metadata + inline `envelope` (≤ 200 KB) or `storagePath`, `kind`, `bookingId`, `createdAt`, `expiresAt` (30 days), `sizeBytes`. Firestore **TTL policy** on `expiresAt`; Storage lifecycle rule deletes objects after 31 days as a backstop. Owner may read; no client writes.
- `portal/{tokenHash}`: `ownerUid`, `clientRef` (opaque id), `next`, `past[]`, `aftercare[]`, `products[]` (only what she published), `expiresAt`, `revokedAt?`.
- `rescheduleRequests/{id}`, `waitlist/{id}`: operational request data.
- `contacts/{ownerUid}_{phoneHash}`: `phoneHash` (HMAC-SHA256 with a server pepper from Secret Manager), `lastIntakeAt?`, `bookingCount`, `noShowCount?`. Used for "ask the health form again after 12 months" and the optional no-show limit; **no names, no content**. The no-show count is computed from the professional's own markings pushed by the app (`NoShowMark`), scoped per owner only.
- `devices/{uid}/tokens/{tokenId}`: FCM token, platform, `lastSeenAt`.
- `rate/{key}`: counters for rate limiting with TTL.
- `audit/{id}`: security events without PII (key changes, deletions, token revocations), TTL 400 days.

## 3. Functions (one per use case, input validated with `zod`, generic error codes, no PII in logs)

**Public (App Check required, no auth)**
`getPublicPage(slug)`, `getSlots`, `holdSlot`, `createBooking`, `joinWaitlist`, `sendEmailCode`, `verifyEmailCode`, `findBookings` (needs a verified phone credential or an email code), `getFormContext(token)`, `submitSealed(token, envelope)`, `getPortal(tokenOrPortalToken)`.

**By manage token**
`getBooking`, `confirmPresence`, `reportLate`, `rescheduleBooking`, `requestReschedule`, `cancelBooking`, `rebook`.

**Owner (Auth + App Check)**
`isSlugAvailable`, `claimSlug`, `publishProfile`, `publishAvailability`, `publishPortal`, `updateInboxKey`, `respondBookingRequest`, `respondRescheduleRequest`, `offerWaitlistSlot`, `markNoShow`, `acknowledgeMailboxItem`, `registerDevice`, `deleteClientServerData(phoneHash | bookingIds)`, `deleteAccount`.

**Triggers and jobs**
- `onBookingWritten`: pushes (generic) to the owner's devices; enqueues the confirmation email when an email exists; updates `contacts`.
- `onInboxItemCreated`: silent push `content-available` to the owner's devices.
- `cleanupJob` (every 10 min): expired holds; confirms Firestore TTL deleted inbox items, deletes the corresponding Storage objects; purges `bookings` past `purgeAt`; revokes expired portal tokens.
- `sendReminders` (every 5 min; **only when `whatsAppAutomation` is on**): due reminders through `ClientMessenger`.
- `appStoreNotifications` (HTTPS): App Store Server Notifications V2: verify the signed payload (JWS chain) and update `accounts.plan`.

**`ClientMessenger`** (interface in `functions/src/messaging/`): `sendEmail(template, to, locale, vars)`, `sendWhatsApp(template, to, locale, vars)`. Providers: `EmailProvider` (transactional email through an HTTP API; provider chosen by Mateus, H7; the code depends only on the interface and a `FakeEmailProvider` for tests), `WhatsAppCloudProvider` (Meta Cloud API; implemented and tested against a mock; **disabled** unless the flag and credentials exist; message templates must be pre-approved by Meta, see H13). Template content: booking facts only. Per-locale text from `functions/src/messaging/templates/<locale>.json` generated from `docs/strings/message-templates.json`.

## 4. Booking rules inside `createBooking` and friends (D11–D13, D15, D19, D32)

In one Firestore transaction: verify the professional accepts bookings (not paused), the slot is free for the **total duration**, no overlap with confirmed bookings, blocks, holds by others, breaks, days off, and respects notice/horizon; create the booking; if the client is new and `confirmNewClients` is on, or the no-show limit is reached with action `approveNewBookings`, set `pendingApproval`; if action `pauseOnline` and the limit is reached, return `paused`. Generate the manage token (128-bit, base64url), store only its SHA-256. Idempotency key from the client prevents duplicates on retry. The same rules, written as **pure functions in `functions/src/lib/rules.ts`**, are unit-tested with table tests; the iOS pure rule types (`CancellationEvaluator`, `FreeSlotsCalculator`) have the **same test tables** (copy fixtures to `web/test`/`firebase/functions/test/fixtures` from one JSON file generated once; both sides read it) so the two implementations cannot drift.

Cancel/reschedule by token evaluate the stored policy snapshot **as of the booking** (store a copy of the policy values on the booking) so later policy edits do not retroactively change a client's rights.

## 5. Security rules (sketch; the emulator tests are the spec)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function isOwner(uid) { return request.auth != null && request.auth.uid == uid; }
    match /{document=**} { allow read, write: if false; }
    match /publicProfiles/{slug} { allow read: if true; allow write: if false; }   // writes only via function (validated)
    match /accounts/{uid} { allow read: if isOwner(uid);
      allow update: if isOwner(uid) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['locale']); }
    match /bookings/{id} { allow read: if request.auth != null && resource.data.ownerUid == request.auth.uid; allow write: if false; }
    match /inbox/{uid}/items/{item} { allow read: if isOwner(uid); allow write: if false; }
    match /rescheduleRequests/{id} { allow read: if request.auth != null && resource.data.ownerUid == request.auth.uid; allow write: if false; }
    match /waitlist/{id} { allow read: if request.auth != null && resource.data.ownerUid == request.auth.uid; allow write: if false; }
    match /devices/{uid}/tokens/{t} { allow read, write: if isOwner(uid); }
    // availability, holds, portal, contacts, rate, audit, slugs: no client access
  }
}
```
Storage rules: deny all client access (Functions and Admin SDK only; the app downloads large sealed items through a signed URL returned by a function). Tests (`firebase/test-rules`): another uid cannot read; no authenticated or anonymous client can write to function-only collections; public profile is readable but not writable; every rule above is covered by an allow case and a deny case.

## 6. Abuse and limits

App Check enforced on all public functions; per-IP and per-token limits (token bucket in `rate/`); body size limits (functions `maxRequestSize` plus app-level checks); `submitSealed` also checks the booking is within its valid window; bot protection on verification endpoints; per-owner daily caps on emails/SMS to protect cost; budget alerts configured by a human (H4). Never reveal whether a phone belongs to an existing client.

## 7. Push

FCM from Functions to the owner's `devices` tokens. **Notification payloads contain only a type and ids** (`{kind:"booking", id}`), with a generic alert title/body localized by the **app** (the app registers its locale; the function sends `loc-key` and no args that include names). Silent pushes for the mailbox. APNs auth key uploaded by a human (H4).

## 8. Deletion and retention

`deleteClientServerData` removes bookings, waitlist items, requests, portal docs, mailbox items and `contacts` rows for that phone hash (owner-scoped). `deleteAccount` deletes everything under the uid, the slug claim, tokens, devices; marks `deletion.requestedAt`, completes within 30 days (document: PITR/backup windows). Scheduled purge per D30. A test seeds data, runs the delete and asserts nothing remains in any collection or Storage path.

## 9. Observability without PII

Structured logs with ids, kinds, sizes and durations only; a test greps all function sources for `console.log` of request bodies. Error reporting is Cloud Error Reporting with scrubbed messages. Metrics: function latency, error rate, booking creations, TTL deletions.

## 10. Local development and CI

`npm run emulators` starts Auth, Firestore, Functions, Hosting, Storage; `scripts/seed.ts` loads the prototype's demo professional (Maria, services, availability) so the web app and the iOS app can be exercised end to end. Tests: `vitest` for rules/lib, `@firebase/rules-unit-testing` for rules, Playwright for the web e2e against the emulators (`scripts/e2e-local.sh`). Lint and type-check in CI; `npm audit` fails on high severity.

## 11. Swapping the backend later

Everything the iOS app needs is expressed by `BookingRepository`. A different backend (managed Postgres with an API, for example) requires only a new `RemoteBookingRepository` and a new server implementing the same function contracts (the web app also calls these by name). Keep the function contracts documented in `firebase/functions/README.md` (request and response schemas generated from the `zod` schemas) to make that possible.

## 12. Region policy (markets)

- `accounts/{uid}.countryCode` and `publicProfiles.regionCode` come from the region preset (`16-MARKETS.md`). The server never infers legal treatment from them; they only choose defaults (language, phone format, messaging channel).
- **SMS region allow-list (D37):** the Auth phone-verification SMS policy allows only the calling codes of the presets in `regions.json`. `firebase/scripts/sms-regions.mjs` prints the list for H4 and a test checks the script output against the file. Block premium and unknown routes. Budget alert on SMS.
- **E-mail code is always available** (`sendEmailCode` / `verifyEmailCode`) and is the fallback when SMS fails or the country is not in the allow-list.
- Message templates for the WhatsApp provider are keyed by localization (`firebase/functions/src/messaging/templates.ts`), kept in step with `message-templates.json` by a test.
- Firestore region: `eur3` (D29, decided). `RemoteBookingRepository` reads the Functions region from config (`FUNCTIONS_REGION`), and `accounts/{uid}` carries `dataRegion` (`eu` today). A future second database for Brazilian professionals (`southamerica-east1`) would need a slug-to-region lookup; do not build it now, but do not scatter region names through the code either (one `DataRegion` type, one config).
