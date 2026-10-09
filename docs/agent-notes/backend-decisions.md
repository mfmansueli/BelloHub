# Agent notes: backend, owner decisions D44 to D52 applied

Branch `backend-decisions`, created from `build/v1` at `31ba797`. Touched only `firebase/`, `docs/agent-notes/` (this
file). Not touched: `web/`, any iOS file, `docs/PROGRESS.md`, `docs/02-DECISIONS.md`, `docs/06-PRIVACY-SECURITY.md`.
Nothing was pushed, deployed, or run against a real project; every emulator run used `demo-bellohub` on the ports of
`firebase.test.json` (none was busy) and the e2e port block of `scripts/e2e-local.sh`. App Check enforcement untouched.

## 1. Commits

| Commit | Decision | What |
|---|---|---|
| `ef71e07` | D44 | Sign in with Apple as owner identity; `deleteAccount` revokes the Apple grant |
| `5c93a25` | D51 | Retired inbox keys: 24 h grace, `compromised` stops at once, cleanup drops dead keys |
| `a7325de` | D47 | Policy snapshot on every booking (`policy`, `rulesText`, `noShowPolicy`), returned by `getBooking` |
| `1ca082a` | D45, D48, D46 | Closed-input proof for `createBooking`, e-mail code per-caller limit test, API.md + schemas |
| (this) | | These notes |

## 2. What changed, per task

### D44: owner sign-in with Apple
- Audit: no owner use case, `lib/account.ts` or `firestore.rules` line ever required a phone. `newAccount` copies
  `phone_number` onto `accounts/{uid}.phone` only when the token has one (phone sign-in); the gate (`invoke.ts`) needs
  a `uid` and nothing else. The only place that demands the `phone` provider is `FirebasePhoneVerifier`, which is for
  CLIENTS (`createBooking`/`findBookings` phone verification), not owners.
- New: `src/auth/AppleTokenRevoker.ts` (interface: `configured`, `revoke(code) -> 'revoked' | 'failed' | 'skipped'`,
  never throws), `src/auth/UnconfiguredAppleTokenRevoker.ts` (default, `skipped`), `src/auth/AppleSignInTokenRevoker.ts`
  (real adapter: ES256 client-secret JWT `{iss: X5392U638Q, sub: com.bellohub, aud: https://appleid.apple.com, iat, exp +5 min}`
  signed with the `.p8` via `node:crypto` (`ieee-p1363`), `POST /auth/token` `grant_type=authorization_code` then
  `POST /auth/revoke` with the refresh token (access token as fallback); logs outcomes and HTTP status only).
- `config/params.ts`: `APPLE_SIGNIN_TEAM_ID` / `APPLE_SIGNIN_CLIENT_ID` constants, `APPLE_SIGNIN_KEY_ID` (string param,
  default empty), `APPLE_SIGNIN_PRIVATE_KEY` (`defineSecret`, added to `FUNCTION_SECRETS`). `createDeps` builds the real
  adapter only when the key id is set (the secret is read then), else the unconfigured one. `Deps.appleRevoker` added.
- `deleteAccount`: input `appleAuthorizationCode?: string` (10 to 2048 chars), output `{ ok: true, appleRevocation }`.
  Revocation runs before the cascade; its outcome never blocks the deletion.
- Tests: `test/unit/appleRevoker.test.ts` (7: JWT header/claims/signature verified with the public key, exchange +
  revoke bodies, access-token fallback, every failure mode -> `failed`, nothing sensitive in logs, `ifConfigured`,
  unconfigured default); `test/integration/ownerIdentity.test.ts` (5: `{uid}` alone runs ensureAccount, claimSlug,
  publishProfile, publishAvailability, updateInboxKey, registerDevice, reserveRegistration; phone kept only for a
  phone sign-in; deletion with code -> `revoked` and the fake saw the code; `failed` still deletes; no code -> `skipped`;
  a too-short code is `INVALID_ARGUMENT`); `test/rules/firestore.rules.test.ts` (+1: an `apple.com` provider token with
  no `phone_number` reads/updates her own account and bookings, not another's); `test/transport/callable.test.ts` (+2:
  a real Apple-provider ID token minted by the Auth emulator's `signInWithIdp` runs `ensureAccount`, `claimSlug`,
  `registerDevice`, `deleteAccount` (`skipped` in the emulator) and the Auth user is gone; a phone-provider owner token
  works too and records the phone). `test/support/transport.ts` gained `signInWithApple`.
- `deletion.test.ts` expectations updated to the new response shape.

### D47: policy snapshot
- Already stored: `bookings/{id}.policy` (the cancellation policy at booking time) and every client action was already
  evaluated from it. Missing: the rule TEXT (`getBooking` read the live profile) and the no-show setting that concerns the
  client. Added to `BookingDoc` (`lib/bookingCreate.ts`, the single writer, so `rebook` and waitlist offers get it too):
  `rulesText` (the published map, every booking language, <= 2000 chars each) and `noShowPolicy: { isOn, lateCancelCounts }`.
- `getBooking`: `rulesText` comes from the booking (the profile only for bookings made before this change), new field
  `lateCancelCounts: boolean`. `policy` was already the snapshot. The portal has no server-side bookings (its `upcoming`
  is app-published content, and D52 keeps forms/check-in off the portal), so nothing to add there.
- `cancelBooking`: a late cancellation writes the `lateCancel` mark only when the booking-time policy said it counts
  (bookings without the snapshot keep the old "always record" behaviour). `markNoShow` (the professional's own action)
  still counts under her current policy, as before.
- Tests: `test/integration/policySnapshot.test.ts` (4: publish A, book, publish B (profile + availability), read back A
  and the new booking reads B, stored doc checked; `actions` evaluated per snapshot at the same instant: A -> free/direct,
  B -> askByMessage/message and `cancelBooking` is `NOT_ALLOWED` for B only; the late-cancel mark follows booking-time
  `lateCancelCounts`; a legacy booking without the snapshot falls back to the page texts). `manageBooking.test.ts`:
  the existing late-cancel test now sets `lateCancelCounts` BEFORE booking.

### D51: inbox keys
- `lib/keyring.ts` rewritten: `KEY_GRACE_MS` (24 h), `acceptsUntil(entry)` (= `retiredAt` + 24 h, or `retiredAt` when
  `compromisedAt` is set), `acceptsKey(ring, keyId, now)`, `isDead` / `pruneKeyring` / `nextPruneAt` (dead = `acceptsUntil` +
  30 days, the envelope TTL, so nothing in the mailbox can reference the key), `applyInboxKey(ring, key, now, { compromised })`
  which now returns `{ failure: 'compromisedKey' }` when a key retired as compromised is sent again. `keyringView` adds
  `acceptsUntil` and `compromisedAt`.
- `InboxKeyringEntry.compromisedAt`, `AccountDoc.inboxKeyringPruneAt` (written by `lib/keyringUpdate.ts` on every ring
  change; `FieldValue.delete()` when nothing is retired).
- `updateInboxKey`: input `compromised?: boolean`; output entries gain `acceptsUntil?`, `compromisedAt?`; a compromised
  key as `inboxKey` -> `INVALID_ARGUMENT` (`fields: ['inboxKey']`), also through `publishProfile` (`profile.inboxKey`).
- `submitSealed`: `acceptsKey` instead of `isKnownKey` (`KEY_MISMATCH` after the grace or at once when compromised).
- Cleanup: new step `jobs/steps/pruneKeyrings.ts` (query `accounts.inboxKeyringPruneAt <= now`, 50 per run, transaction
  per account), `CleanupReport.keyrings`.
- Tests (fixed `now` everywhere): `test/unit/libraries.test.ts` keyring block (5: grace boundary at exactly 24 h,
  compromised closes at once and can never return, prune/death instants); `mailbox.test.ts` (2: accepted at +24 h - 1 ms,
  refused at +24 h, new key accepted; compromised refused at once); `profile.test.ts` (2: `acceptsUntil`/`compromisedAt`
  in the response and `inboxKeyringPruneAt` = retired + 31 d; a compromised key cannot come back through either path);
  `retention.test.ts` (1: `runCleanup` keeps the key at +31 d - 1 ms, drops it at +31 d, reports 0 the second time).

### D45 / D48 check
- `createBooking`'s input was already a `strictObject` with `note` (<= 300, `looseText`) and `guests: 0 | 1 | 2`; the
  booking document never held names beyond `client.name`. Proof added to `createBooking.test.ts` (2 tests): `heardFrom`,
  `hadBefore`, `firstVisit`, `guests: [names]`, `guestNames`, `client.heardFrom`, `client.firstVisit` are rejected with
  exactly those paths and no values echoed; a valid request stores `guestCount` (number) and `note`, and the stored
  document's key set is asserted as a closed list (`client` = `name`, `phone`, `locale` only); a 301-char note is
  `INVALID_ARGUMENT` on `note`, an empty one is dropped. The web client (`web/src/api/types.ts`, read only) already does
  not send `heardFrom`/`hadBefore`.

### D46 check
- The e-mail path is complete: `sendEmailCode` (hashed code, 10 min, 30 s resend, 5/h per address, 10/h per IP, 300/day
  per professional) -> `verifyEmailCode` (5 tries, single-use 30 min proof bound to the address) -> `createBooking` /
  `findBookings` with `{ method: 'email', proof }`. No client code path requires the phone provider. Added the missing
  per-caller (IP) limit test to `emailVerification.test.ts`. The phone verifier is kept (SMS through our own API later)
  and API.md 5.7 now says it is **not used by the page**.

## 3. API.md diff summary (for the web and iOS agents)

1. Section 2 access table: owner = Sign in with Apple or phone, **no phone number required on the token** (D44).
2. Section 4 conventions: the policy snapshot paragraph (D47).
3. 5.5 `sendEmailCode`: the only verification the page uses (D46). 5.7 retitled "**not used by the web page**".
4. 5.8 `createBooking`: `guests` documented as a count, `client` closed, a note that unknown fields are rejected by path (D45, D48).
5. 5.11 `getBooking`: `policy` and `rulesText` documented as the booking's snapshot; **new field `lateCancelCounts: boolean`** (D47).
6. 5.12: late cancellation recorded only when `lateCancelCounts` was on at booking time.
7. 5.15 `submitSealed`: `KEY_MISMATCH` rule (current key, or retired < 24 h and not compromised) (D51).
8. 6.2 `updateInboxKey`: **input `compromised?: boolean`; output entries gain `acceptsUntil?`, `compromisedAt?`**; the grace,
   compromise and pruning rules (D51).
9. 6.7 `deleteAccount`: **input `appleAuthorizationCode?: string`; output `{ ok: true, appleRevocation: "revoked" | "failed" | "skipped" }`** (D44).
10. Section 8: `accounts.phone?` (phone sign-in only), `inboxKeyring[]` entry fields, `inboxKeyringPruneAt?`;
    `bookings.rulesText?`, `bookings.noShowPolicy?`.
11. Section 10: the cleanup job also drops dead retired keys. Section 1: `APPLE_SIGNIN_KEY_ID` listed among the parameters.
`contracts/schemas.json` regenerated (`deleteAccount`, `updateInboxKey`, `getBooking`).

Response shapes that CHANGED for existing callers: `deleteAccount` (new required `appleRevocation` field),
`updateInboxKey` (two optional fields), `getBooking` (new required `lateCancelCounts`). Inputs only gained optional fields.

## 4. Results

`scripts/test-firebase.sh` (all, 2026-10-09, Node 26, Java 21, firebase-tools 15): **green**.

| Stage | Result |
|---|---|
| lint (ESLint `--max-warnings 0`), typecheck, build, `npm audit --audit-level=high` | 0 problems |
| unit (no emulator) | **755** passed (739 before: +7 Apple revoker, +4 keyring, +5 rewritten keyring block net) |
| Firestore + Storage rules | **66** passed (65 + the Apple-provider rule test) |
| use cases on the emulators | **274** passed (258 + 5 owner identity, 4 policy snapshot, 2 createBooking D45/D48, 1 e-mail IP limit, 1 mailbox, 2 profile, 1 retention) |
| transport (Functions emulator) | **19** passed (17 + Apple-provider owner token, phone-provider owner token) |

`scripts/e2e-local.sh`: first run **failed** on "she cancels for free" (the page showed the late-cancellation warning).
Cause, in the web story (not the server): `chooseDayAhead(page, ZONE, 2)` clicks a day two days out, but `slots.first()`
resolved on the slot list of the initially selected day (today, a Friday at 04:52 in Sao Paulo, which still had free
times), so Helena booked a visit a few hours away and the later cancellation was correctly late. The earlier green run
of the integration agent happened later in the day, when today had no slots left. The second run, minutes later,
**succeeded, 6 passed (18 s)** with the same functions. Suggested web-side fix (not applied, `web/` is not mine): after
the day click, wait for the slot list to show a slot whose `data-testid` starts with `slot-<that day>` before reading
`slots.first()`. The web client needed no change for the API changes (it never sent `heardFrom`/`hadBefore`, and it
ignores the new optional response fields).

One thing the first e2e run surfaced: a new `defineSecret` makes the Functions emulator ask Secret Manager for it (403 on
`demo-bellohub`, harmless but noisy) unless `functions/.secret.local` has a value. Both wrappers now write
`APPLE_SIGNIN_PRIVATE_KEY=unset` there, like `EMAIL_API_KEY`; the second run was clean.

Port handling: `firebase.test.json` ports were free; `e2e-local.sh` took its default block (25080/25001...). Nothing was killed.

## 5. Human tasks (owner)

**H17: Sign in with Apple key for token revocation (D44).**
1. developer.apple.com > Certificates, Identifiers & Profiles > **Keys** > "+" > name it (e.g. `BelloHub Sign in with Apple`)
   > tick **Sign in with Apple** > Configure > primary App ID `com.bellohub` > Save > Continue > Register.
2. Note the **Key ID** (10 characters) and **Download** the `.p8` once (Apple never shows it again; keep it in the
   password manager, never in the repo).
3. For each Firebase project (dev, staging, later prod): `cd firebase && firebase functions:secrets:set
   APPLE_SIGNIN_PRIVATE_KEY --project <alias>` and paste the full PEM (`-----BEGIN PRIVATE KEY----- ... END PRIVATE KEY-----`);
   put `APPLE_SIGNIN_KEY_ID=<the key id>` in `functions/.env.<project>`. The team id `X5392U638Q` and the client id
   `com.bellohub` are constants in `functions/src/config/params.ts`.
   The secret must exist (any placeholder) in every project before a deploy, because every function binds it; the
   adapter only reads it when `APPLE_SIGNIN_KEY_ID` is set.
4. Firebase console > Authentication > Sign-in method > **Apple**: enable it (the Services ID / key fields there are only
   needed for web sign-in; the iOS native flow needs just the toggle). Keep **Phone** enabled as the alternative (D44).
5. Verify once on dev: delete a test account from the app with a fresh authorization code and check that the function
   log shows `account.appleRevocation` with `status: revoked`, and that Settings > Apple ID > Sign in with Apple no longer
   lists Bello Hub.
Also for the iOS agent: `deleteAccount` wants a fresh `ASAuthorizationAppleIDRequest` authorization code taken right
before the call (codes expire in 5 minutes and are single-use); show "revoke in Settings" when the answer is not `revoked`.

## 6. Not done / open

- The iOS half of D44 (Sign in with Apple in the app, passing the code to `deleteAccount`) and of D47 (the policy screens'
  copy is on `build/v1` at `b1ed521`, by another agent) are outside `firebase/`.
- `docs/06-PRIVACY-SECURITY.md` section 3.2 could mention the 24 h grace / compromise rule (D51); not edited (docs are
  not mine here).
- The portal (`getPortal`) carries no policy: its `upcoming` entries are app-published; if the app wants the manage-page
  rules there it must publish them in `PortalContent` (not added, D52 keeps the portal booking-less).
- `markNoShow` keeps counting under the professional's CURRENT no-show policy; only the client-side consequence of a late
  cancellation follows the booking-time snapshot. If the owner wants the count itself frozen per booking, that is an iOS
  + server change (marks would need the booking's policy).
- Node 26 locally vs `engines: 22` (unchanged from the earlier notes).
