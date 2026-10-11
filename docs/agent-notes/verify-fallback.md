# Agent notes: verify-fallback (the e-mail code that does not come, returning clients)

Branch `verify-fallback`, from `origin/build/v1` at `7a44150` (2026-10-10). One helper agent in its own worktree,
while S12 owned `build/v1`. Owner-approved scope: three items, server + web + app + strings + tests + docs. Nothing
was deployed (the owner deploys after the merge: functions, Hosting rewrites, the Firestore TTL policy).

Context: v1 verifies a client on the web page only by a 6-digit e-mail code (D46, strict CSP, no SDK); no SMS and
no WhatsApp API (D57). When the code does not arrive the client was stuck.

## 1. What changed

### Item 1: "I didn't get the code" -> "Confirm on WhatsApp" (an unverified request)

- **Web, Bk-6** (`VerifyStep.tsx`): "Change email" right on the step (the code goes to the corrected address; the
  old address could not be fixed before except by going back). After the first 30 s wait, or after a resend, a quiet
  "I didn't get the code" opens a sheet: spam/junk advice with the address, the resend control, "Change email", and,
  **only when her public page has `whatsappE164`**, "Confirm with <Name> on WhatsApp".
- That button calls `createBooking` with `verification: { method: "whatsapp" }` and only what was already collected
  (no first-visit note). **Bk-10** then shows the reference, the time, when the request is released, and a primary
  link to `wa.me/<her number>` with a message in the page language (client's first name, service, date, time,
  reference; key `wa.unverified`). WhatsApp opens on the client's own tap: an automatic jump after the network call is
  blocked by in-app browsers and would lose the page with the reference.
- **Server** (`bookingCreate.ts`, `unverifiedRequests.ts`): always `pendingApproval`, whatever else applies;
  `verification: 'whatsapp'`, `reference` (5 chars of `23456789ABCDEFGHJKMNPQRSTUVWXYZ`), `pendingExpiresAt` =
  min(now + 24 h, visit start). The server reason (`pendingReason`) is kept when one applies. `NOT_ALLOWED` without
  her WhatsApp number. Needs `client.email`. **No e-mail when it is made** (the address is not proven); approving it
  (`respondBookingRequest`) adds a new manage token and sends `bookingConfirmed` with the personal link.
- **Limits**: 5/day per IP, 3/day per e-mail, 3/day per phone, 50/day per professional, and at most **2 waiting
  unverified requests per phone and per e-mail** with one professional (`RATE_LIMITED`, `retryAfterSeconds` until the
  first is released). The cap is read inside the booking transaction.
- **Expiry**: no pending-approval expiry existed, so a new cleanup step `jobs/steps/expireRequests.ts` (every 10 min
  with `cleanupJob`): a still-pending request past `pendingExpiresAt` becomes `declined` with `expiredAt`, the time is
  free, nobody is e-mailed. Single-field query on `pendingExpiresAt` (no index); answered requests have the field
  removed by `respondBookingRequest` (and by the step if any is left).
- **Replay**: the same `idempotencyKey` must use the same kind of proof (a WhatsApp request cannot be "upgraded" to a
  verified one by replaying it with an e-mail proof, nor the other way round).
- **App, 2.10** (`BookingRequestContentView`, rule `UnverifiedRequestBadge` in `Support/`): coral "Not verified"
  notice, "The client could not receive the code. Check that the WhatsApp message came from <phone> and quotes the
  reference <ref>.", and the release time. No guessed "new client" reason when the server gave none. Approve/Decline
  unchanged. `IncomingBooking` reads `verification`, `reference`, `pendingExpiresAt`.

### Item 2: returning clients skip the code (trusted device)

- **Server** (`lib/trustedDevices.ts`): a booking **confirmed** with a fresh **e-mail proof** returns `deviceToken`
  (22-char random token) and `deviceTokenExpiresAt`. Stored only as SHA-256 (`trustedDevices/{sha256("device:"+token)}`
  with `ownerUid`, `slug`, `emailHash`, `phoneHash`, `createdAt`, `expiresAt`, `lastUsedAt`). 90 days, never renewed,
  at most 5 per e-mail and page (a sixth deletes the oldest). Issued outside the booking transaction: a failure never
  undoes a booking (the page just asks for a code next time).
- `createBooking` accepts `verification: { method: "device", token }`: same page, same `client.email`, unexpired, or
  `VERIFICATION_FAILED`. It is **refused with `VERIFICATION_REQUIRED`** whenever the booking would not be confirmed at
  once: her new-client switch, the free registrations used (D42), the no-show limit (any action; "pause" still answers
  `paused` first). Never issued for `whatsapp`, `device` or `phone` bookings.
- **Web**: `lib/trustedDevice.ts` keeps `{v, email, token, expiresAt}` under `bh.device.<slug>` in `localStorage`,
  every access in try/catch (`lib/storage.ts`); blocked storage = always the code. Bk-5 with a matching token goes
  straight to Bk-7; on `VERIFICATION_REQUIRED` the page returns to Bk-6 (token kept), on `VERIFICATION_FAILED` it drops
  the token and returns to Bk-6.
- **Revocation**: "Forget this device" on Bk-9 (only when this browser keeps a token for the page) removes it locally
  and calls the new public function **`forgetDevice`** (`{token}` -> `{ok:true}`, 20/hour per IP, same answer for an
  unknown token). Also removed: by `deleteClientServerData` (by her phone and by the e-mail of every booking deleted),
  by `deleteAccount`, by the cleanup job after 90 days, and by the Firestore TTL policy (`trustedDevices.expiresAt`).

### Item 3: small fixes

- `sendEmailCode` takes an optional `holdKey`; a booking code stretches a **live soft** hold under that key to
  now + 10 min (never shortens, never revives an expired hold, never touches an offer hold). The page sends it.
- `docs/10-WEB-BOOKING.md` section 3 (and section 1, the route table) no longer speak of SMS or a Firebase SDK in the
  browser.
- `docs/14-HUMAN-TASKS.md` H7: SPF, DKIM and DMARC are required, with why (spam folder) and how to check.

## 2. Security review

- **Unverified requests can be made in anyone's name** (that is their nature). What limits the harm: they are always
  requests (nothing is confirmed without the professional), they are labelled "Not verified" with the phone to compare
  against the WhatsApp sender and a reference, they e-mail nobody until she approves, they hold the slot at most 24 h,
  and they are capped per IP, e-mail, phone, professional and per waiting contact. A determined attacker with many IPs
  can still hold up to 50 slots a day per professional for up to 24 h; she can decline them in one tap each. If abuse
  appears, the per-owner cap is the knob (`RATE.unverifiedOwnerDay`).
- **The approval e-mail goes to an unproven address.** A typo means a stranger gets the personal link of that one
  booking (view, cancel, move). The professional matched the client on WhatsApp first, and Bk-5 and Bk-6 both show the
  address (Bk-6 lets her correct it). Accepted by the owner's item 1 ("the e-mail is still stored so the personal
  link can be e-mailed on approval").
- **Trusted-device token theft** (shared computer, XSS): it only lets someone book on that page with that address
  while the professional does not need to look; it opens no booking, reveals nothing, and cannot approve itself into a
  request. The page has no third-party script and a strict CSP, so XSS is the remaining vector; the token is not in a
  cookie, URL or log. Scope: one slug, one e-mail hash; 90 days hard; revocable. The IP, phone and owner booking
  limits still apply to device bookings.
- **Enumeration**: `VERIFICATION_REQUIRED` tells a device holder that this booking would need approval. Only someone
  who already proved the address on this page gets that answer, and the page already says "she will confirm this one"
  in that case. `forgetDevice` answers the same for known and unknown tokens. The page never learns why.
- **Storage**: no token in a URL, cookie or log (`log.ts` only takes ids). The server stores hashes only. The
  `bh.device.*` key is the only new browser storage; the e2e guards allow exactly it.
- **Server authority (D32)**: every decision is in the booking transaction; the page's choice of path is only a hint.

## 3. Tests

- Functions: `test/integration/verifyFallback.test.ts` (unverified request shape, release at the visit start, no
  e-mail, kept reason, NOT_ALLOWED without a number, per-contact cap, cap freed by an answer, IP limit, cleanup expiry
  with the time freed, no expiry after approval and the approval e-mail with a link, replay rules; device issue/hash/
  90 days, not issued for pending or phone, accepted on same page and e-mail, refused for another e-mail/page/made-up/
  expired, VERIFICATION_REQUIRED for approval and no-show limit, pause still paused, at most five, forgetDevice, removed
  with client data and by cleanup; hold extension and its limits), `test/unit/unverifiedRequests.test.ts`, index TTL.
- Web: `test/unit/verify-fallback.test.ts` (storage, blocked storage, machine `needsCode`, the WhatsApp request),
  `api.test.ts` (new error code), Playwright `test/e2e/verify-fallback.spec.ts` (help sheet, WhatsApp request with
  the prefilled message, no number, corrected address, hold key, Arabic RTL at 320 px, German at 320 px, device skip,
  other address, VERIFICATION_REQUIRED back to the code, blocked storage, Forget this device), mock server in step,
  e2e-local `verifyFallback.spec.ts` against the real functions.
- App: `UnverifiedRequestBadgeTests`, two cases in `BookingRequestViewModelTests`, UI test
  `InboxUITests.testAnUnverifiedRequestShowsItsBadgeAndCanBeApproved` on the new `-uiInbox unverified` scenario.

## 4. What the owner must know

- **Deploy all three together** after the merge: functions (new `forgetDevice`, changed `createBooking`,
  `sendEmailCode`, `respondBookingRequest`, `cleanupJob`), Hosting (the `/api/forgetDevice` rewrite) and the
  Firestore indexes file (TTL on `trustedDevices.expiresAt`). An old page against new functions keeps working
  (every new field is optional); a new page against old functions would fail on the new `holdKey` field of
  `sendEmailCode` (strict input), so functions first, then Hosting.
- **H7 now says SPF, DKIM and DMARC are required.** Most "no code" reports will be the spam folder.
- The WhatsApp way shows only for professionals with a public WhatsApp number on their page.
- An unanswered unverified request disappears from her requests after 24 hours (or at the visit's start) and the
  client is not told by e-mail (her address was never proven); the review page told her when it would happen.
- Strings: 18 web keys and 4 app keys in all fourteen localizations, `needs_review` like every non-English string (D41).
