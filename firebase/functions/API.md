# Bello Hub server API (contract v1)

This file is the contract between the server (`firebase/functions`), the web booking app (`web/`, stage S9) and the iOS
`RemoteBookingRepository` (stage S8, second half). It is written first and kept in sync with the code:

- `functions/src/contracts/` holds the zod schemas that the server validates against. They are the source of truth;
  `functions/test/contracts/` checks that **every function below exists, and every exported function is documented here**.
- `functions/contracts/schemas.json` is generated from the same schemas (`npm run gen:schemas`) and committed. Generate
  your Swift or TypeScript types from it if you prefer to not read prose.
- If this file and the code disagree, the code (and its tests) win, and this file is a bug. Tell the backend owner.

Specs: `docs/05-DATA-MODEL.md` (layer B), `docs/06-PRIVACY-SECURITY.md`, `docs/10-WEB-BOOKING.md`,
`docs/11-BACKEND-FIREBASE.md`. Decisions cited as D-numbers are in `docs/02-DECISIONS.md`.

> **Privacy line.** The server never receives a health answer, a note, a photo or an allergy in readable form, and it
> carries no consent text: consents are the professional's own business; the app only records their status (D55). Everything sensitive travels as a sealed envelope (`submitSealed`). The only free text from a client is
> her name, phone, optional email, an optional short note to the professional (<= 300 chars) and a cancel reason
> (<= 200 chars). The page must tell her not to write health information in those two fields.

---

## 1. Transport

All JSON functions are Firebase **callable** functions (2nd gen), region `europe-west1` (D29).

| Environment | Base URL |
|---|---|
| Production / staging | `https://europe-west1-<projectId>.cloudfunctions.net/<name>` |
| Emulator | `http://127.0.0.1:5001/<projectId>/europe-west1/<name>` (the test script uses port 15001) |

**iOS:** `Functions.functions(region: "europe-west1").httpsCallable(name)`. The SDK adds the Auth and App Check tokens.

**Web (plain `fetch`, no Functions SDK, to keep the bundle small):** the callable wire protocol is a plain JSON POST.

```
POST <base>/<name>
Content-Type: application/json
X-Firebase-AppCheck: <App Check token>          (every function; see section 2)
Authorization: Bearer <Firebase ID token>        (owner functions only)

{ "data": <request object> }
```

Success: HTTP 200 and `{ "result": <response object> }`.
Failure: HTTP 4xx/5xx and

```
{ "error": { "status": "FAILED_PRECONDITION", "message": "SLOT_TAKEN", "details": { ... } } }
```

`error.message` is **always a stable machine code from section 3**, never prose and never user data. Do not show it;
map it to your own localized text. `error.details` is optional and never contains personal data.

A function that has several normal outcomes (booked, needs approval, time taken, paused) returns them as a
`status` field of a **successful** response, not as an error. Errors are for things the caller cannot expect.

### Same-origin option (what the web app uses)
`firebase/firebase.json` (`hosting.rewrites`) exposes every public and token function, plus `getIcs`, under
`/api/<name>` of the web origin: no CORS, and the page's CSP stays `connect-src 'self'`. Owner functions have no
rewrite (the iPhone calls them through the Functions SDK). The function names and payloads do not change; the same
list is mirrored in `web/hosting.json` (the mock server and the Playwright suite read it) and a unit test keeps the
two in step. `scripts/e2e-local.sh` runs the real page through the Hosting emulator with these rewrites.

### Local development (emulators, no cloud)
```
cd firebase/functions && npm ci && npm run build        # the emulator runs the compiled code in lib/
printf 'PHONE_HASH_PEPPER=local-dev-pepper\n' > .secret.local   # any value; git-ignored
cd .. && firebase emulators:start --project demo-bellohub       # auth 9099, functions 5001, firestore 8080, storage 9199, UI 4000
cd functions && npm run seed                                     # Maria, her page, her availability and a health form
```
The project id **must** start with `demo-`: such an id can never reach the cloud. Base URL
`http://127.0.0.1:5001/demo-bellohub/europe-west1/<name>`. In the emulator only:
- the **email code is always `123456`** and "sending" an email only counts it (nothing is written down);
- **SMS**: use the Auth emulator's real phone sign-in (`signInWithPhoneNumber`); each code is printed in the emulator log and
  listed at `GET http://127.0.0.1:9099/emulator/v1/projects/demo-bellohub/verificationCodes`;
- App Check is not enforced (a missing token is accepted);
- pushes are not sent; `emulatorOutbox` records `{type: "push", kind, id}` so a test can wait for one.
`ENFORCE_APP_CHECK`, `WEB_BASE_URL`, `WHATSAPP_AUTOMATION`, `PLAN_PRODUCT_IDS`, `APPLE_SIGNIN_KEY_ID` and `TRUSTED_PROXY_HOPS` (how many
proxies append to `X-Forwarded-For`; 1 by default, 2 is expected behind the Hosting rewrites once a staging log confirms
it) are deploy parameters (`functions/.env.<project>`); their defaults suit the emulator.

### CORS
Allowed origins: `https://bellohub.app`, any `https://*.bellohub.app`, and the Hosting domains of our own projects:
`https://bellohub*.web.app`, `https://bello-hub*.web.app` (preview channels included) and the same on `firebaseapp.com`.
A Hosting site whose id does not start with `bellohub` or `bello-hub` is refused. The emulator accepts any origin.

## 2. Access levels and App Check

| Level | Needs | Functions |
|---|---|---|
| `public` | App Check token | no login, no token in the input |
| `token` | App Check token + a secret token in the input | the client's manage link or portal link |
| `owner` | App Check token + Firebase Auth ID token of the professional (Sign in with Apple, or phone; **no phone number is required on the token**, D44) | everything under section 6 |
| `http` | none (see each) | `getIcs`, `appStoreNotifications` |

App Check enforcement is a deploy-time parameter (`ENFORCE_APP_CHECK`, default `false`; a human turns it on after
staging passes, H5). With it off, a missing token is accepted and the call is still rate limited. **The browser sends no
App Check token** (D46: no Firebase SDK, no reCAPTCHA, `connect-src 'self'`), so `ENFORCE_APP_CHECK` must stay off for
the projects the web page calls, or the public/token functions must be exempted before it is turned on.

**Rate limits** (all return `RATE_LIMITED` with `details.retryAfterSeconds`): per IP, per token, per phone or email and
per professional, listed on each function. The numbers are in `functions/src/config/limits.ts`.

## 3. Error codes (`error.message`)

| Code | HTTP | When | `details` |
|---|---|---|---|
| `INVALID_ARGUMENT` | 400 | The input does not match the schema | `{ fields: ["client.phone", ...] }` (paths only, never values) |
| `UNAUTHENTICATED` | 401 | Owner function without a valid ID token | |
| `APP_CHECK_REQUIRED` | 401 | Enforcement is on and the App Check token is missing or invalid | |
| `FORBIDDEN` | 403 | Signed in but not allowed (not the owner of the resource) | |
| `NOT_FOUND` | 404 | Unknown slug, token, id | |
| `TOKEN_EXPIRED` | 404 | The token exists but its time is over (booking + 7 days; portal after 180 idle days; revoked) | |
| `RATE_LIMITED` | 429 | Too many calls | `{ retryAfterSeconds }` |
| `VERIFICATION_FAILED` | 403 | The phone ID token, the email proof or the trusted-device token is missing, wrong, used, expired or for another contact or page | |
| `VERIFICATION_REQUIRED` | 400 | `createBooking` with a trusted-device token (`device`) for a booking that would not be confirmed at once (approval needed, no-show limit): verify by e-mail code instead | |
| `INVALID_CODE` | 400 | Wrong or expired email code (also after 5 wrong tries) | |
| `NOT_ALLOWED` | 400 | The professional's rules do not allow this action now | `{ action: "message" \| "request" \| "direct" }` the path that is allowed instead |
| `CONFIRMATION_REQUIRED` | 400 | A late cancellation needs `acceptLateWarning: true` | |
| `BOOKING_NOT_ACTIVE` | 400 | The booking is cancelled, declined, past or otherwise not in a state for this action | `{ status }` |
| `SLUG_TAKEN` | 409 | `claimSlug`: someone else owns it | |
| `KEY_MISMATCH` | 400 | `submitSealed` used a `keyId` the professional does not hold (refetch `getFormContext`) | |
| `PAYLOAD_TOO_LARGE` | 400 | An envelope or a profile is over its cap | `{ maxBytes }` |
| `CONFLICT` | 409 | An id is already used with different content | |
| `NOT_CONFIGURED` | 503 | A provider (email, App Store) is not set up in this environment | |
| `TRY_AGAIN` | 503 | A transient contention or outage; repeat after a moment | |
| `INTERNAL` | 500 | Anything else. Never carries details | |

The HTTP status is the one the Firebase callable protocol sends for the underlying status (a test checks it); clients
should branch on `error.message`, not on the number.

## 4. Conventions

```ts
type LocaleId = "pt-BR" | "pt-PT" | "es-MX" | "es-419" | "es" | "en" | "en-GB" | "it" | "fr" | "de" | "tr" | "id" | "hi" | "ar";
type Instant   = string;  // ISO-8601, e.g. "2026-10-08T17:30:00.000Z". Responses always use UTC with milliseconds.
                          // Requests accept any ISO-8601 with "Z" or a numeric offset.
type LocalDate = string;  // "YYYY-MM-DD" in the professional's timeZoneID
type E164      = string;  // "+5511987654321" (digits only after "+", 8 to 15 digits)
type Token     = string;  // 22 characters of base64url = 128 random bits
type Uuid      = string;  // lowercase UUID v4
type Slug      = string;  // /^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$/, 3 to 30 chars, not in the reserved list
```

- Slug reserved list: `m p api admin app www help support static assets login auth bookings book status privacy terms legal about`
  (and anything with `--`).
- Phones are normalized by the app (`PhoneNormalizer`) and the browser before they reach the server. The server
  rejects anything that is not E.164 and never "fixes" it.
- Email is trimmed and lower-cased by the server.
- Strings are NFC-normalized and stripped of control characters; lengths are caps (extra is rejected, not cut).
- Times are instants. Calendar days (`LocalDate`) are in the professional's `timeZoneID`. Slots are returned as instants;
  show them in the **business** time zone.
- Start times (D56): the slot grid (`slotStepMinutes` of the availability: 10, **15 by default**, 20, 30, 60, or 0 = match
  the service) from the start of each working stretch, plus starts anchored right after and right before every visit,
  break and block and at both edges of each stretch (rounded inwards to the 5-minute clock). A service's
  `prepMinutes`/`cleanupMinutes` are blocked around the visit and its `processingMinutes` (from `processingStartMinutes`)
  leave her free inside it; none of them change the visible duration or the price.
- **Total duration of a booking** = service minutes + sum of chosen add-on minutes + guests x service minutes
  (guests are the same service, back to back, D19). The server computes it; the client never sends durations.
- **Policy snapshot (D47).** `policy`, `rulesText` and the no-show setting that concerns the client (`lateCancelCounts`)
  are copied onto the booking when it is made; a later `publishProfile` / `publishAvailability` changes only bookings made
  afterwards. `getBooking` returns the booking's own copy, so the manage page shows the rules in force at booking time.

### Shared shapes

```ts
type Money = { display: "show" | "startingFrom" | "onRequest"; amount?: number };   // amount in the profile's currency, <= 2 decimals

type CancellationPolicy = {
  freeWindowHours: 2 | 12 | 24 | 48 | 72;
  clientCanReschedule: boolean;
  maxReschedules?: number;            // omitted = no limit
  afterWindowCancel: "allow" | "message";
  afterWindowReschedule: "request" | "message";
  askConfirmation: boolean;
  graceMinutes: number;               // 5...20
};

type InboxKey = { keyId: string; alg: "hpke-v1"; pub: string };   // pub = base64url of 32 bytes; keyId = base64url(SHA-256(pub)[0..8]); the server checks it

type PublicProfile = {
  schemaVersion: 1;
  slug: Slug;
  displayName: string;                // <= 80
  businessName?: string;              // <= 80
  bio?: string;                       // <= 600, plain text with line breaks
  city?: string;                      // <= 80
  regionCode: string;                 // ISO 3166-1 alpha-2
  photo?: string;                     // "data:image/jpeg;base64,..." <= 120 KB
  timeZoneID: string;                 // IANA id
  currencyCode: string;               // ISO 4217
  locales: LocaleId[];                // booking page languages, first is the default (1...6)
  whatsappE164?: E164;                // shown as "Message <Name>"
  credentials: { title: string; institution?: string; year?: number; registrationNumber?: string }[];   // <= 20, only those she chose to show
  services: {
    id: Uuid; name: string; category?: string; durationMinutes: number; price?: Money;
    prepMinutes?: number; cleanupMinutes?: number;                 // 0...60, D56: blocked before / after, not shown
    processingStartMinutes?: number; processingMinutes?: number;   // D56: she is free inside the visit; start + length <= durationMinutes
  }[];                                                              // active services only, <= 60
  addOns: { id: Uuid; name: string; minutes: number; priceText?: string }[];                          // offered add-ons, <= 30
  booking: { acceptingBookings: boolean; pausedUntil?: Instant; requiresApproval: boolean; maxGuests: 0 | 1 | 2; maxDaysAhead: number };
  policy: CancellationPolicy;
  rulesText: Partial<Record<LocaleId, string>>;   // generated by the app from `policy`, one text per booking language, <= 2000 each
  legalNotice?: string;               // optional "Impressum"-style text, <= 2000
  inboxKey: InboxKey;
  updatedAt: Instant;                 // set by the server
};
```

`intake` (the health-form template: the questions) is published inside `publishProfile` but is **not** part of
`getPublicPage`; it is returned by `getFormContext`. No consent, agreement or guardian text exists anywhere in the
contract (D55); documents written before D55 may still hold a `consent` map, which the server ignores.

---

## 5. Public and token functions (the web app)

### 5.1 `getPublicPage`  (public)
```ts
req: { slug: Slug }
res: {
  profile: PublicProfile;             // without `intake`
  intakeAvailable: boolean;           // the professional published a health form
  features: { whatsAppAutomation: boolean; smsCallingCodes: string[] };   // e.g. ["55","351"]; D31, D37
  serverTime: Instant;
}
```
Errors: `NOT_FOUND`. Limits: 120/min per IP. Paused pages are returned normally (`booking.acceptingBookings` /
`booking.pausedUntil`); render the notice and hide the booking button.

### 5.2 `getSlots`  (public)
```ts
req: {
  slug: Slug; serviceId: Uuid; addOnIds?: Uuid[]; guests?: 0 | 1 | 2;
  from: LocalDate; to: LocalDate;     // inclusive, at most 42 days
  holdKey?: string;                   // your own hold does not block you
  rescheduleToken?: Token;            // moving an existing booking: its own time does not block it, and its service/add-ons/guests are used
}
res: {
  timeZoneID: string;
  durationMinutes: number;            // total duration used to compute the slots
  paused: boolean;                    // the page does not accept bookings now: `days` is empty
  days: {
    date: LocalDate;
    slots: Instant[];                 // shown by default: with compactDay on, the starts that leave no dead gap (D56)
    more?: Instant[];                 // the other free starts, behind "Show all times"; absent when there are none
  }[];                                // one entry per day of the range, `slots: []` when none
}
```
Semantics mirror the iOS `FreeSlotsCalculator`: weekly hours, breaks, days off, buffer (around bookings and holds,
none around blocks), minimum notice, booking window, business time zone, daylight saving (a time that does not
exist moves to the first valid time, a time that happens twice means its first occurrence), and D56: anchored starts,
the extra and processing time of the service and of every booking and hold (snapshotted when they are made), and the
compact-day ranking (a gap shorter than her shortest published offer plus the buffer is dead; per gap the starts that
leave none come first, or the least dead time when none can). `holdSlot`, `createBooking` and the reschedule calls accept
any start of `slots` or `more`. Confirmed and
pending-approval bookings and unexpired holds occupy time. Errors: `NOT_FOUND` (slug, service, token). Limits: 60/min per IP.

### 5.3 `holdSlot`  (public)
Soft hold of 5 minutes while the client types her details.
```ts
req: { slug: Slug; serviceId: Uuid; addOnIds?: Uuid[]; guests?: 0 | 1 | 2; startsAt: Instant; holdKey: string }   // holdKey: 16...64 random chars made by the browser
res: { status: "held"; holdId: string; expiresAt: Instant }
   | { status: "slotTaken"; alternatives: Instant[] }      // up to 5 next free starts
   | { status: "paused" }
```
One hold per `holdKey`: a new hold replaces the previous one. Limits: 20/hour per IP.

### 5.4 `getHold`  (public)
Opens a link the professional sent from the waitlist (`<web>/<slug>/time?offer=<holdKey>`).
```ts
req: { slug: Slug; holdKey: string }
res: { serviceId: Uuid; addOnIds: Uuid[]; guests: number; startsAt: Instant; endsAt: Instant; expiresAt: Instant }
```
Errors: `NOT_FOUND`, `TOKEN_EXPIRED`.

### 5.5 `sendEmailCode`  (public)
Sends a 6-digit code (30 minutes, 5 tries). **The only verification the web page uses (D46):** the page keeps
`connect-src 'self'` and loads no Firebase SDK. SMS (5.7) stays available for a later API-side SMS provider.
```ts
req: { slug: Slug; email: string; locale: LocaleId; purpose: "booking" | "find"; holdKey?: string }
res: { resendAfterSeconds: 30; expiresInSeconds: 1800 }
```
With `purpose: "booking"` and the browser's `holdKey`, a live soft hold under that key is extended to
10 minutes (the code itself lasts 30; never shortened, never revived once expired, offer holds untouched), so waiting for the e-mail does not
lose the time.
Errors: `RATE_LIMITED` (resend before 30 s; 5/hour per email; 10/hour per IP; a daily cap per professional),
`NOT_CONFIGURED` (no email provider in this environment: show SMS only). The response is identical whether or not the
email is known. In the emulator the code is the fixed `123456`.

### 5.6 `verifyEmailCode`  (public)
```ts
req: { email: string; code: string }
res: { proof: string; expiresInSeconds: 1800 }       // single use
```
Errors: `INVALID_CODE`, `RATE_LIMITED`.

### 5.7 Verifying a phone  (**not used by the web page**, D46)
The server still accepts `verification: { method: "phone", idToken }` on `createBooking` / `findBookings`: a Firebase Auth
phone ID token whose provider is `phone`, whose `phone_number` equals the phone in the request, and whose sign-in is at
most 10 minutes old. The booking page does **not** use it (its CSP forbids the Firebase JS SDK and reCAPTCHA); clients
verify by e-mail code (5.5, 5.6). The path is kept for an SMS provider behind our own API later (D37 allow-list); no
client code path requires the phone provider. `features.smsCallingCodes` is still returned for that day.

### 5.8 `createBooking`  (public)
```ts
req: {
  slug: Slug; serviceId: Uuid; addOnIds?: Uuid[]; guests?: 0 | 1 | 2;
  startsAt: Instant;
  client: { name: string /* <= 80 */; phone: E164; email?: string; locale: LocaleId };   // nothing else about her: no first-visit answers (D45)
  guests?: 0 | 1 | 2;                             // a COUNT; guest names are never sent or stored (D48)
  note?: string;                                  // <= 300, shown only to the professional; the only free text
  verification: { method: "phone"; idToken: string }
              | { method: "email"; proof: string }         // requires client.email = the verified one
              | { method: "device"; token: Token }         // trusted device: same page, same client.email (below)
              | { method: "whatsapp" };                    // no proof: an unverified request (below); needs client.email
  idempotencyKey: Uuid;                           // new for each attempt the user starts; reuse it only to retry the SAME request
  holdKey?: string;                               // converts your hold
}
res: { status: "confirmed" | "pendingApproval"; bookingId: string; manageToken: Token; startsAt: Instant; endsAt: Instant;
       timeZoneID: string; serviceName: string; emailSent: boolean;
       reference?: string;                 // "whatsapp" only: 5 characters from 23456789ABCDEFGHJKMNPQRSTUVWXYZ
       requestExpiresAt?: Instant;         // "whatsapp" only: when the request is released if she has not answered
       deviceToken?: Token; deviceTokenExpiresAt?: Instant }   // confirmed + "email" only: a trusted-device token
   | { status: "slotTaken"; alternatives: Instant[] }          // -> Bk-4 with "That time was just taken. Here are the next ones"
   | { status: "paused"; pausedUntil?: Instant }               // -> Bk-1 notice, or Bk-10 "online booking is paused for now" when it is about her
```
- One Firestore transaction (D32) checks the pause switch, the no-show action, the slot against everything that occupies time,
  and creates the booking. **Two simultaneous requests for one slot: exactly one wins, the other gets `slotTaken`.**
- `pendingApproval` (-> Bk-10) when: the professional confirms new clients and this phone is new to her; or this phone
  is new and her **10 free registrations are used and she has no plan (D42)**; or the no-show limit is reached with the
  action "approve new bookings" (D13). The response never says which. A new phone that books and is confirmed is
  registered at once (it counts toward the 10, and the app's later `reserveRegistration` for the same phone does not count twice).
- `manageToken` is returned **once**; the server keeps only its SHA-256. The page stores it nowhere: the URL is the key.
  Retrying with the same `idempotencyKey` and the same request returns the same booking with an **additional** token,
  provided the retry carries the same verification (the same email `proof`, or a fresh valid one for that address; a
  phone ID token is checked on every call). An idempotency key alone opens nothing.
- A confirmation email is sent when `client.email` is given and a provider is configured (`emailSent`).
- The request is **closed** (D45, D48): any field not listed (`heardFrom`, `hadBefore`, guest names, anything inside
  `client` beyond the four fields) is `INVALID_ARGUMENT` with its path. The server stores the note and the guest count only.
- Limits: 10/hour per IP, 5/hour per phone, 300/day per professional.
- **Unverified request (`whatsapp`, "I didn't get the code").** Allowed only when her public page has `whatsappE164`
  (else `NOT_ALLOWED`). The booking is always `pendingApproval` (whatever else applies), stored with
  `verification: "whatsapp"`, a `reference` and `pendingExpiresAt` = the earlier of 24 hours from now and the visit's
  start; the response carries both so the page can prefill the WhatsApp message. No e-mail is sent when it is made (the
  address is not proven); approving it (6.3 `respondBookingRequest`) mints a new manage token and e-mails the personal
  link. If she does not answer, `cleanupJob` sets it to `declined` with `expiredAt` and the time is free again. Extra
  limits: 5/day per IP, 3/day per e-mail, 3/day per phone, 50/day per professional, and at most 2 waiting unverified
  requests per phone and per e-mail with one professional (`RATE_LIMITED` with `retryAfterSeconds` until the earliest
  one is released). A replay with the same `idempotencyKey` must use the same kind of verification.
- **Trusted device (`device`).** A booking confirmed with a fresh `email` proof returns `deviceToken` (90 days, never
  renewed, only its SHA-256 is stored, at most 5 per e-mail and page; a sixth replaces the oldest). The token stands in
  for the proof on a later booking on the **same page** with the **same `client.email`**; any other page, address,
  an expired or forgotten token is `VERIFICATION_FAILED`. It never skips a look by the professional: when the booking
  would wait for approval (her new-client switch, the free registrations, the no-show limit) or the client is at the
  no-show limit, the answer is `VERIFICATION_REQUIRED` and the page asks for the code. A pause still answers `paused`.
  Revocation: 5.18 `forgetDevice`, a client data delete (6.7) and an account delete remove it; it is never issued for
  `whatsapp`, `device` or `phone` bookings.
Errors: `INVALID_ARGUMENT`, `NOT_FOUND`, `NOT_ALLOWED` (`whatsapp` without her number), `VERIFICATION_FAILED`,
`VERIFICATION_REQUIRED` (`device` only), `CONFLICT` (idempotency key reused with a different request), `RATE_LIMITED`.

### 5.9 `findBookings`  (public)  -> Bk-11
The web page calls it with `email` and an e-mail proof from 5.6 (D46); the phone form is kept for a later SMS provider.
```ts
req: { slug: Slug; phone?: E164; email?: string;    // email + an "email" proof (the page), or phone + a "phone" token (not used by the page)
       verification: { method: "phone"; idToken: string } | { method: "email"; proof: string } }
res: { bookings: { bookingId: string; manageToken: Token; serviceName: string; startsAt: Instant; endsAt: Instant;
                   timeZoneID: string; status: "confirmed" | "pendingApproval" }[] }   // upcoming only
```
Each found booking gets a **new additional** manage token (at most 5 per booking; the oldest is replaced), so links she
already holds keep working. An empty list is a normal answer and looks the same whether or not the phone exists.
Limits: 10/hour per IP, 5/hour per phone.

### 5.10 `joinWaitlist`  (public)
```ts
req: { slug: Slug; serviceId?: Uuid; name: string; phone: E164; locale: LocaleId; dayFrom: LocalDate; dayTo: LocalDate }
res: { ok: true }
```
Same person, service and range twice is one entry. Limits: 5/hour per IP, 3/day per phone, 100 waiting per professional.

### 5.11 `getBooking`  (token)  -> Bk-9
```ts
req: { token: Token }
res: {
  bookingId: string;
  status: "confirmed" | "pendingApproval" | "cancelledByClient" | "cancelledByPro" | "declined" | "noShow";
  phase: "upcoming" | "inProgress" | "past";
  slug: Slug;
  professional: { displayName: string; businessName?: string; whatsappE164?: E164 };
  service: { id: Uuid; name: string };
  addOns: { id: Uuid; name: string; minutes: number }[];
  guestCount: number;
  startsAt: Instant; endsAt: Instant; durationMinutes: number; timeZoneID: string;
  serverTime: Instant;                // the server clock: a phone with a wrong clock still shows the right free window
  client: { name: string };
  policy: CancellationPolicy;         // D47: the policy in force when the booking was made (not the page's current one)
  rulesText: Partial<Record<LocaleId, string>>;   // D47: the rule texts published at booking time (the page's current texts only for bookings older than the snapshot)
  lateCancelCounts: boolean;          // D47: under the no-show policy of booking time, a late cancellation counts as a missed visit
  noShowLimit?: number;               // D47: her no-show limit at booking time; present only when that policy was on (say it only then)
  actions: {
    cancel: "free" | "allowedWithWarning" | "askByMessage" | "unavailable";
    reschedule: "direct" | "request" | "message" | "unavailable";
    isInsideFreeWindow: boolean; hoursUntilStart: number; cancellationWouldBeLate: boolean;
    canConfirmPresence: boolean;      // policy asks for confirmation, not confirmed yet, upcoming
    canReportLate: boolean;           // confirmed and starts within 3 hours or already started and not past
  };
  clientConfirmedAt?: Instant; lateByMinutes?: number; rescheduleCount: number;
  pendingReschedule?: { requestedStart: Instant; status: "pending" | "declined" };
  intakeRequired: boolean;            // first visit, or the last sealed form is older than 12 months
  tokenExpiresAt: Instant;            // visit end + 7 days
}
```
Errors: `NOT_FOUND`, `TOKEN_EXPIRED`. Limits: 60/min per token, 120/min per IP.

### 5.12 `confirmPresence`, `reportLate`, `cancelBooking`, `rescheduleBooking`, `requestReschedule`  (token)
```ts
confirmPresence:    req { token }                                     res { clientConfirmedAt: Instant }
reportLate:         req { token; minutes: 10 | 15 | 20 | 30 }         res { lateByMinutes: number; reportedAt: Instant }
cancelBooking:      req { token; reason?: string /* <= 200 */; acceptLateWarning?: boolean }
                    res { status: "cancelled"; isLateCancellation: boolean }
rescheduleBooking:  req { token; startsAt: Instant }                  // "direct" mode only
                    res { status: "moved"; startsAt: Instant; endsAt: Instant; rescheduleCount: number }
                      | { status: "slotTaken"; alternatives: Instant[] }
requestReschedule:  req { token; startsAt: Instant; note?: string /* <= 300 */ }   // "request" mode only
                    res { status: "requested" }
                      | { status: "slotTaken"; alternatives: Instant[] }
```
The rules are the booking's own policy snapshot (D47), evaluated at the server's time (see `actions` in `getBooking`).
A late cancellation is recorded against the client only when `lateCancelCounts` was on at booking time.
`cancelBooking` after the free window: `allowedWithWarning` needs `acceptLateWarning: true` (else `CONFIRMATION_REQUIRED`);
`askByMessage` is `NOT_ALLOWED` with `details.action = "message"`. A cancellation frees the slot and can match the waitlist.
`requestReschedule` leaves the current time reserved until the professional answers (one open request per booking).
Errors: `NOT_FOUND`, `TOKEN_EXPIRED`, `BOOKING_NOT_ACTIVE`, `NOT_ALLOWED`, `CONFIRMATION_REQUIRED`.
Limits: 20/hour per token.

### 5.13 `rebook`  (token)  -> Cl-3
Books the same client again with a manage token (while valid) or a portal token that carries a `rebook` section.
```ts
req: { token: Token; serviceId?: Uuid; addOnIds?: Uuid[]; startsAt: Instant; idempotencyKey: Uuid }
res: same as createBooking
```
The client is a known one (the token proves it): no new verification, no "new client" approval. A pause, the no-show
action and a stopped client still apply.

### 5.14 `getFormContext`  (token)  -> Cl-4, Cl-5, Cl-7
```ts
req: { token: Token }
res: {
  bookingId: string;                  // goes inside the sealed payload
  professional: { displayName: string };
  formVersion: number;
  template: object;                   // opaque to the server: the questions published by the app (docs/10 section 5)
  inboxKey: InboxKey;
  intakeCompletedWithinMonths: boolean;   // a sealed intake was submitted in the last 12 months (a flag, no content)
}
```
Errors: `NOT_FOUND` (no health form published), `TOKEN_EXPIRED`.

### 5.15 `submitSealed`  (token)  -> Cl-4, Cl-5, Cl-7
```ts
req: { token: Token;
       envelope: { v: 1; suite: "hpke-x25519-hkdf-sha256-chacha20poly1305"; keyId: string; kind: "intake" | "checkin" | "datarequest";
                   itemId: Uuid; enc: string /* base64url, 32 bytes */; ct: string /* base64url */ } }
res: { ok: true }
```
Caps on the decoded ciphertext: `intake` 256 KB + 1 KB, `checkin` 3 MB + 1 KB, `datarequest` 8 KB + 1 KB. Bodies over 200 KB are stored in Cloud
Storage. `keyId` must be the professional's current key or one retired less than 24 hours ago and not reported compromised
(`KEY_MISMATCH` otherwise; refetch `getFormContext`, D51). Re-sending the same `itemId` with
the same ciphertext is a success (retry); a different ciphertext is `CONFLICT`. The booking must exist and not be
purged. The server stores ciphertext and metadata (`ownerUid`, `bookingId`, `kind`, `sizeBytes`, `createdAt`, `expiresAt` = +30 days) and
**never** looks inside. Limits: 5/hour per booking, 20/hour per IP, and at most **20 items per booking** waiting in the
mailbox (`RATE_LIMITED` with `details.maxItems`; the count drops when the app acknowledges them).

### 5.16 `getPortal`  (token)  -> Cl-2
```ts
req: { token: Token }                  // portal token
res: {
  slug: Slug;
  professional: { displayName: string; businessName?: string; whatsappE164?: E164 };
  clientName: string;
  upcoming: { serviceName: string; startsAt: Instant; endsAt: Instant; timeZoneID: string }[];
  next?: { serviceName: string; recommendedDate?: LocalDate };
  past: { serviceName: string; date: LocalDate; summary?: string }[];
  aftercare: { title: string; lines: string[]; date?: LocalDate }[];
  products: { name: string; note?: string }[];
  rebook?: { serviceId: Uuid; addOnIds: Uuid[] };
  expiresAt: Instant;                  // slides forward on use: 180 days of inactivity
}
```
Errors: `NOT_FOUND`, `TOKEN_EXPIRED` (a revoked or idle portal; once the cleanup job has removed a revoked one it is `NOT_FOUND`, so treat both as "this link no longer works"). Only what the professional published is returned.

### 5.17 `getIcs`  (http GET)
`GET <base>/getIcs?token=<manageToken>&locale=<LocaleId>` -> `200 text/calendar; charset=utf-8`, `Content-Disposition: attachment; filename="appointment.ics"`,
`Cache-Control: no-store`, `Referrer-Policy: no-referrer`. One `VEVENT` in UTC, `UID` stable per booking,
`SUMMARY`/`DESCRIPTION` in the client's locale (bidi isolates in Arabic), reminder 24 h before. Errors are plain
`404`/`410`/`429` with an empty body.

### 5.18 `forgetDevice`  (public)
"Forget this device" on the management page: the browser sends its trusted-device token (5.8) and the server deletes it.
```ts
req: { token: Token }
res: { ok: true }        // the same whether or not the token existed
```
Limits: 20/hour per IP.

---

## 6. Owner functions (the iOS app)  (owner: Auth + App Check)

All owner calls use the signed-in professional's uid. The app reads her own documents directly from Firestore
(section 8); everything that writes goes through these functions.

### 6.1 Account and the free registrations (D42)

```ts
ensureAccount:  req { countryCode: string; locale: LocaleId }
                res { uid: string; appAccountToken: Uuid /* pass to StoreKit as appAccountToken */; dataRegion: "eu";
                      registrations: { count: number; freeLimit: number /* 10 */ };
                      plan: { state: "none" | "active" | "grace" | "expired" | "revoked"; expiresAt?: Instant };
                      slug?: Slug }
```
Idempotent. Creates `accounts/{uid}` on first call. Call after sign-in and on launch.

```ts
reserveRegistration:  req { clientId: Uuid; phone?: E164 }
                      res { decision: "allowed" | "needsSubscription"; count: number; freeLimit: number /* 10 */; alreadyCounted: boolean }
reserveRegistrations: req { clients: { clientId: Uuid; phone?: E164 }[] /* <= 200, processed in order */ }
                      res { results: { clientId: Uuid; decision: "allowed" | "needsSubscription"; alreadyCounted: boolean }[];
                            count: number; freeLimit: number /* 10 */ }
```
The **server is the authority** for the count; the client only reads it. Rules, in one transaction:
1. `accounts/{uid}/registrations/{clientId}` exists -> `allowed`, `alreadyCounted: true`, nothing changes.
2. `phone` matches a phone already registered for this professional (a booking from the link registered it, or an earlier
   `reserveRegistration`) -> `allowed`, `alreadyCounted: true`, the client id is linked to it. **The same phone never counts twice.**
3. Otherwise a new client: with an active plan or `count < 10` -> count + 1, a ledger document with the client id and the date
   (no personal data), `allowed`. With no plan and `count >= 10` -> `needsSubscription`, **nothing is counted or stored**.
4. **Deleting a client never gives a slot back** (`deleteClientServerData` does not touch the counter or the ledger).
The count keeps rising with a plan. `reserveRegistrations` stops counting at the limit and answers `needsSubscription` for the rest.

```ts
syncPlan:  req { signedTransaction: string /* StoreKit 2 JWS (Transaction.jsonRepresentation / signedTransaction) */ }
           res { plan: { state: "none" | "active" | "grace" | "expired" | "revoked"; expiresAt?: Instant } }
```
Re-verifies the purchase on the server (JWS chain, bundle id, product ids `com.bellohub.pro.monthly|yearly`,
`appAccountToken` = this account's). Unlocking anything in the app waits for this answer or for the mirrored
`accounts/{uid}.plan` (kept up to date by App Store Server Notifications). `NOT_CONFIGURED` until a human installs the
Apple root certificates and App Store settings (H14).

### 6.2 Slug, profile, availability

```ts
isSlugAvailable: req { slug: string }    res { available: boolean; reason?: "taken" | "reserved" | "invalid" }
claimSlug:       req { slug: Slug }      res { slug: Slug }          // errors: SLUG_TAKEN, INVALID_ARGUMENT. Replaces her previous slug (the old public page is removed).
publishProfile:  req { profile: PublicProfileInput }   res { slug: Slug; updatedAt: Instant }
```
`PublicProfileInput` is `PublicProfile` without `slug`, `schemaVersion`, `updatedAt`, plus an optional
```ts
intake?: { formVersion: number; template: object /* <= 200 KB, opaque */ }   // D55: no consent texts; a `consent` field is INVALID_ARGUMENT
```
She must have claimed a slug. The server validates and size-limits everything (whole document <= 700 KB), strips
control characters, checks that `inboxKey.keyId` matches `pub`, registers a **changed** key in the account keyring
(previous keys stay so pending envelopes still open) and writes an audit event without values. The page is replaced as a whole.

```ts
publishAvailability: req {
  timeZoneID: string;
  weekly: { weekday: 1...7 /* 1 = Sunday, as in iOS Calendar */; startMinutes: number; endMinutes: number /* up to 1440 */ }[];   // <= 56
  breaks: { weekday?: 1...7; startMinutes: number; endMinutes: number }[];                                                        // <= 28
  daysOff: { startDate: LocalDate; endDate: LocalDate }[];                                                                        // inclusive, <= 100
  bufferMinutes: number; minNoticeHours: number; maxDaysAhead: number;
  slotStepMinutes?: 0 | 10 | 15 | 20 | 30 | 60;   // D56: default 15; 0 = match the service (its footprint plus the buffer)
  compactDay?: boolean;                           // D56: "Keep my day compact", default true
  busy: { startsAt: Instant; endsAt: Instant; kind: "appointment" | "block";
          prepMinutes?: number; cleanupMinutes?: number; processingStartMinutes?: number; processingMinutes?: number /* appointments only, D56 */ }[];   // her own agenda minus link bookings; "appointment" gets the buffer, "block" does not; no names, no reasons; <= 600; the past is dropped
  noShow: { isOn: boolean; limit: 1...5; action: "tell" | "approveNewBookings" | "pauseOnline"; lateCancelCounts: boolean; countingMonths: 3 | 6 | 12 };
  reminderHourLocal?: number;          // 0...23, default 18, used only when WhatsApp automation is on
}
res { updatedAt: Instant }
```
**Do not** include appointments that came from the link (they have a `bookingID`): the server already holds them.

```ts
updateInboxKey: req { inboxKey: InboxKey; compromised?: boolean }
                res { keyring: { keyId: string; createdAt: Instant; retiredAt?: Instant; acceptsUntil?: Instant; compromisedAt?: Instant }[] }
```
Rotation (D51): the new key becomes current in the account keyring and in the public profile. The key it replaces is
retired and **still accepts new envelopes for 24 hours** (`acceptsUntil` = `retiredAt` + 24 h) so a form that was already
open can finish; afterwards `submitSealed` answers `KEY_MISMATCH` for it. With `compromised: true` the replaced key stops
at once (`acceptsUntil` = `retiredAt`, `compromisedAt` set) and can never be made current again (`INVALID_ARGUMENT`,
also through `publishProfile`). A retired key stays listed until 30 days after its `acceptsUntil` (no envelope can
reference it any more), then the cleanup job drops it; keep the matching private key at least that long. Publishing the
same key again changes nothing; an older, uncompromised key can be made current again (recovery).

### 6.3 Bookings, requests, waitlist

```ts
respondBookingRequest: req { bookingId: string; decision: "approve" | "decline" }
                       res { status: "confirmed" | "declined" | "needsSubscription" }
```
`pendingApproval` -> `confirmed` or `declined`. Approving a **new** phone registers the client (D42): with the free
registrations used and no plan the answer is `needsSubscription` and the booking **stays pending** (show the paywall,
then call again). The client gets an email when she gave one. Approving an **unverified** request (`verification:
"whatsapp"`, 5.8) adds a new manage token and the email carries her personal link (no email went out when it was made);
the app shows such a request with a "Not verified" badge and its `reference` so she checks the WhatsApp message first.

```ts
respondRescheduleRequest: req { requestId: string; decision: "accept" | "decline" }
                          res { status: "accepted" | "declined" | "slotTaken" }
cancelBookingByOwner:     req { bookingId: string; reason?: string /* <= 200 */ }        res { status: "cancelled" }
moveBookingByOwner:       req { bookingId: string; startsAt: Instant }                    res { startsAt: Instant; endsAt: Instant }
```
A cancellation by the professional never counts against the client. `moveBookingByOwner` does not check her own
rules (she may book outside her hours); the client is emailed if she gave an email.

```ts
offerWaitlistSlot:   req { waitlistId: string; serviceId: Uuid; addOnIds?: Uuid[]; guests?: 0 | 1 | 2; startsAt: Instant; holdMinutes?: number /* 15...1440, default 180 */ }
                     res { status: "offered"; holdKey: string; holdId: string; expiresAt: Instant }   // link: <web>/<slug>/time?offer=<holdKey>
                       | { status: "slotTaken" }                                                       // the time is not free by her own rules
removeWaitlistEntry: req { waitlistId: string }   res { ok: true }
```
The waitlist entry becomes `offered`; the slot is held for that long for whoever opens the link; booking through it
marks the entry `booked`.

```ts
suggestBookingTime: req { bookingId: string; startsAt: Instant; holdMinutes?: number /* 15...1440, default 180 */ }
                    res { status: "suggested"; holdKey: string; holdId: string; expiresAt: Instant }   // link: <web>/<slug>/time?offer=<holdKey>
                      | { status: "slotTaken" }
```
"Suggest another time" on a request (2.10): the `pendingApproval` booking becomes `declined` and the proposed time is held
like a waitlist offer, with the request's service, add-ons and guests (`BOOKING_NOT_ACTIVE` when it is no longer pending).
The app sends the link on WhatsApp; no email is sent. Booking through the link follows her usual rules and keeps the
`bookingLink` origin (only an offer tied to a waitlist entry makes a `waitlist` booking).

```ts
markNoShow: req { phone: E164; action: "mark" | "forgive" | "reset"; markId?: Uuid; markedAt?: Instant; bookingId?: string }
            res { counted: number }
setOnlineBookingStopped: req { phone: E164; stopped: boolean }   res { ok: true }
```
`mark` (needs `markId`, idempotent, and `markedAt`) / `forgive` (needs `markId`) / `reset` start her count from zero.
`bookingId` also sets that booking's status to `noShow`. Marks are per professional; the server counts them within
`noShow.countingMonths`. `setOnlineBookingStopped` is the "Stop online booking" switch of the client record.

### 6.4 Portal

```ts
publishPortal: req { token: Token /* made by the app: 16 random bytes, base64url */; clientRef: Uuid /* opaque, e.g. the client id */;
                     revoke?: boolean;
                     content?: PortalContent }          // required unless `revoke`
               res { ok: true; expiresAt: Instant }

type PortalContent = {                                   // <= 64 KB; the shape getPortal returns, plus the identity used by `rebook`
  clientName: string;
  upcoming?: { serviceName: string; startsAt: Instant; endsAt: Instant; timeZoneID: string }[];
  next?: { serviceName: string; recommendedDate?: LocalDate };
  past: { serviceName: string; date: LocalDate; summary?: string }[];
  aftercare: { title: string; lines: string[]; date?: LocalDate }[];
  products: { name: string; note?: string }[];
  rebook?: { serviceId: Uuid; addOnIds: Uuid[]; client: { name: string; phone: E164; email?: string; locale: LocaleId } };
};
```
The server stores only the token's hash. `revoke: true` makes it unusable at once. Not published = not visible.
Republishing with the same token updates the content and keeps the 180-day expiry sliding.

### 6.5 Mailbox (sealed envelopes)

```ts
getMailboxItem:         req { itemId: Uuid }   res { itemId: Uuid; kind; bookingId: string; createdAt: Instant; envelope: Envelope }
acknowledgeMailboxItem: req { itemId: Uuid }   res { ok: true }      // deletes the item and its Storage object; unknown id is also ok (idempotent)
```
List with a Firestore query on `inbox/{uid}/items` (metadata and small envelopes are readable by the owner); use
`getMailboxItem` for items whose `storagePath` is set. `Envelope` is the object of `submitSealed`.

### 6.6 Devices and push

```ts
registerDevice:   req { fcmToken: string; platform: "ios"; locale?: LocaleId }   res { ok: true }
unregisterDevice: req { fcmToken: string }                                        res { ok: true }
```

### 6.7 Deletion (D30)

```ts
deleteClientServerData: req { phone?: E164; bookingIds?: string[]; portalClientRef?: Uuid }   res { deleted: { bookings: number; mailboxItems: number; requests: number; waitlist: number; portals: number; contacts: number } }
deleteAccount:          req { confirm: true; appleAuthorizationCode?: string }   res { ok: true; appleRevocation: "revoked" | "failed" | "skipped" }
```
`deleteClientServerData`: removes that client's bookings, sealed items tied to those bookings, reschedule requests, waitlist
entries, portal and the stored contact row for the phone (her no-show marks, last form date, "stopped" flag).
**It does not touch the registration counter or ledger** (deleting never returns a free slot).
`deleteAccount`: marks `deletion.requestedAt`, removes everything under her uid (bookings, holds, sealed items and Storage
objects, portals, requests, waitlist, contacts, devices, availability, public page, slug, registrations, account) and the
Auth user. Safe to call again; a job finishes any account that was interrupted. The promise to users is 30 days; backups age out within a short window.
**Sign in with Apple (D44):** the app requests a fresh authorization code (`ASAuthorizationAppleIDRequest`) right before
calling and passes it as `appleAuthorizationCode`; the server exchanges it and revokes her Apple grant
(`appleRevocation: "revoked"`). `"failed"` means Apple refused or was unreachable, `"skipped"` means no code was sent or the
Apple key is not configured in this environment (`APPLE_SIGNIN_KEY_ID` + secret `APPLE_SIGNIN_PRIVATE_KEY`, H17). **The
data is deleted in every case**; the app may tell her to revoke in Settings when the answer is not `"revoked"`.

---

## 7. Push messages (FCM -> APNs), D31 and `docs/06` section 8

Notification payloads contain **only a kind and ids** and a localization key; the app resolves the text, so no name or
detail is ever on a lock screen. The server never sends arguments.

| `data.kind` | `data.id` | alert (`loc-key`) | notes |
|---|---|---|---|
| `booking` | booking id | `push.booking.new` | new booking, request, change or cancellation |
| `bookingLate` | booking id | `push.booking.late` | a client reported running late (urgent: ignores quiet hours) |
| `bookingConfirmed` | booking id | `push.booking.clientConfirmed` | a client confirmed she is coming |
| `rescheduleRequest` | request id | `push.reschedule.request` | |
| `waitlist` | waitlist id or empty | `push.waitlist.new` | a new entry, or a freed slot matches waiting people |
| `mailbox` | item id | none: **silent** (`content-available: 1`, background) | the app syncs the mailbox, imports, then raises its own alert |

Invalid tokens are removed from `devices/{uid}/tokens` automatically.

## 8. What the app may read from Firestore directly (rules in `firebase/firestore.rules`)

Authenticated owner, own data only; **no client write anywhere except `devices` and `accounts.locale`**.

| Path | Read | Contents (selected fields) |
|---|---|---|
| `accounts/{uid}` | owner | `phone?` (phone sign-in only; absent for Sign in with Apple, D44), `slug`, `countryCode`, `locale`, `dataRegion`, `registrations {count, freeLimit}`, `plan {state, expiresAt, source}`, `inboxKeyring[] {keyId, pub, createdAt, retiredAt?, compromisedAt?}`, `inboxKeyringPruneAt?`, `deletion {requestedAt}` |
| `accounts/{uid}/registrations/{clientId}` | owner | `registeredAt` (the ledger, ids and dates only) |
| `publicProfiles/{slug}` | anyone | the published profile (section 4) |
| `bookings/{id}` | owner (query `ownerUid == uid`) | `status`, `serviceId`, `serviceName`, `durationMinutes`, `addOns`, `guestCount`, `startsAt`, `endsAt`, `timeZoneID`, `client {name, phone, email?, locale}`, `note?`, `pendingReason? ("newClient" \| "freeRegistrationsUsed" \| "noShowLimit")`, `origin`, `policy`, `rulesText?`, `noShowPolicy? {isOn, limit, lateCancelCounts}` (D47 snapshot), `clientConfirmedAt?`, `lateByMinutes?`, `rescheduleCount`, `isLateCancellation?`, `cancelReason?`, `intakeSubmittedAt?`, `verification? ("whatsapp": the client's contact is NOT verified, 5.8)`, `reference?`, `pendingExpiresAt?`, `expiredAt?` (an unverified request released unanswered), `createdAt`, `updatedAt`, `purgeAt` |
| `inbox/{uid}/items/{itemId}` | owner | `kind`, `bookingId`, `createdAt`, `expiresAt`, `sizeBytes`, `keyId`, `envelope?` (inline when <= 200 KB) or `storagePath` |
| `rescheduleRequests/{id}` | owner (query `ownerUid == uid`) | `bookingId`, `clientName`, `serviceName`, `currentStart`, `currentEnd`, `requestedStart`, `requestedEnd`, `note?`, `status`, `createdAt` |
| `waitlist/{id}` | owner (query `ownerUid == uid`) | `name`, `phone`, `serviceId?`, `serviceName?`, `dayFrom`, `dayTo`, `status` (`waiting` \| `offered` \| `booked`), `createdAt`, `offeredAt?` |
| `devices/{uid}/tokens/{id}` | owner, **and she may write** | `fcmToken`, `platform`, `locale`, `lastSeenAt` |

Timestamps in documents are Firestore `Timestamp` (UTC). Nothing else is readable: `availability`, `holds`, `portal`,
`contacts`, `rate`, `audit`, `slugs`, `calendarLocks`, `emailCodes`, `emailProofs`, `trustedDevices`, `idempotency`, `intakeForms` and every counter are function-only.

## 9. Retention (what the legal texts promise, D30)

| Data | Leaves the server |
|---|---|
| Booking | 7 days after the visit ends (`purgeAt`); the manage link stops working then |
| Sealed envelope | when the app acknowledges it, and in any case 30 days after it arrived |
| Hold | 5 minutes (offers: their own length) |
| Email code, email proof | 30 min, 30 min |
| Unverified request (`verification: "whatsapp"`) not answered | released (`declined`) 24 hours after it was made, or at the visit's start; then as any booking |
| Trusted-device token (hash) | 90 days, or "Forget this device", or with her data |
| Waitlist entry | 7 days after its last day |
| Reschedule request | with its booking |
| Portal | revoked, or 180 days without use |
| Rate counters | when their window ends |
| Audit events (no personal data) | 400 days |
| Account and everything under it | `deleteAccount`, within 30 days at the latest |
| Logs | contain ids, kinds, sizes, durations and counts only; no names, phones, emails, tokens, codes or envelopes |

## 10. Functions that are not callable by apps

`onBookingWritten`, `onInboxItemCreated` (Firestore triggers: generic push to the owner's devices, contact bookkeeping),
`cleanupJob` (every 10 minutes: unanswered unverified requests, holds, envelopes, bookings, codes, trusted devices,
portals, waitlist, audit, unfinished deletions, dead retired inbox keys),
`sendReminders` (every 5 minutes, only when `WHATSAPP_AUTOMATION` is on), `appStoreNotifications` (HTTPS POST from Apple,
App Store Server Notifications V2: verifies the signed payload and updates `accounts.plan`).

## 11. Function index (kept in step with the code by a test)

Public / token: `getPublicPage` `getSlots` `holdSlot` `getHold` `sendEmailCode` `verifyEmailCode` `createBooking`
`findBookings` `joinWaitlist` `getBooking` `confirmPresence` `reportLate` `cancelBooking` `rescheduleBooking`
`requestReschedule` `rebook` `getFormContext` `submitSealed` `getPortal` `forgetDevice` `getIcs`

Owner: `ensureAccount` `reserveRegistration` `reserveRegistrations` `syncPlan` `isSlugAvailable` `claimSlug`
`publishProfile` `publishAvailability` `updateInboxKey` `respondBookingRequest` `respondRescheduleRequest`
`cancelBookingByOwner` `moveBookingByOwner` `suggestBookingTime` `offerWaitlistSlot` `removeWaitlistEntry` `markNoShow`
`setOnlineBookingStopped` `publishPortal` `getMailboxItem` `acknowledgeMailboxItem` `registerDevice` `unregisterDevice`
`deleteClientServerData` `deleteAccount`

Triggers, jobs, webhooks: `onBookingWritten` `onInboxItemCreated` `cleanupJob` `sendReminders` `appStoreNotifications`
