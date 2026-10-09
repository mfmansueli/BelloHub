# Agent notes: S9, the client web app (`web/`)

Branch `worktree-agent-ac7ea3c725dfcc9b0`, based on 407427e. Nine commits on top: 248bedd foundation and app,
52e5948 localizations, 265f170 privacy gate and unit tests, 27e6f2d Playwright suite, 6ca27f2 first notes, then the
second session: da20d8d (speaks API.md exactly), 3275f3f (the WebKit CSP report found and scoped), 4bceba0
(`scripts/test-web.sh`), and this notes update. Nothing was pushed. Everything touched is under `web/`,
`scripts/test-web.sh` and this file. `docs/PROGRESS.md`, `DESIGN.md`, `firebase/` and every iOS file are untouched.

## 1. State in one paragraph

The SPA speaks `firebase/functions/API.md` (contract v1, read at the backend commit 983279c) exactly: callable
transport, the wire shapes of sections 4 and 5, the error table of section 3. Every page of the brief exists and is
covered by tests: booking Bk-1..Bk-8, approval/pause Bk-10, find Bk-11, management Bk-9, reschedule Cl-9, cancel
Cl-6, portal Cl-2, rebook Cl-3, health intake Cl-4 (adult and minor), skin check-in Cl-5, my data Cl-7. Fourteen
localizations pass the gate. `scripts/test-web.sh full` is green: lint, typecheck, i18n, contrast, privacy, 221 unit
tests, the production build inside its size budget, and 175 Playwright tests passed with 15 skipped across
Chromium, WebKit and the throttled low-end project. The WebKit CSP problem of the first session is understood (an
engine quirk on `<select>`, section 5) and no longer fails the suite. Not done: Lighthouse CI, the Hosting merge,
the human tasks, and the owner decisions of section 9.

## 2. What is done, with paths

All paths are relative to `web/` unless they start with `docs/` or `scripts/`.

**Stack and tooling.** Preact 10 + TypeScript 5.9 strict (`noUncheckedIndexedAccess`) + Vite 7 + Vitest 4 + ESLint
flat config `strictTypeChecked` (zero warnings). `package.json`, `tsconfig.json` (src), `tsconfig.node.json`
(tests, scripts, configs), `eslint.config.js`, `vite.config.ts`, `vitest.config.ts`, `playwright.config.ts`,
`.env.e2e`, `.gitignore`. Exact dependency versions, `npm audit` clean at the last install.

**Source.**
- `src/api/` one typed client that speaks API.md: `types.ts` (the wire types of API.md sections 4 and 5, then the
  page types `parse.ts` derives from them), `errors.ts` (the server's codes mapped onto the page's vocabulary),
  `transport.ts` (the only `fetch`: callable POST `{data}` -> `{result}`), `parse.ts` (wire -> page, with the
  derived fields: first name, `rulesText` split into lines, the professional's profile beside a booking, the
  questions of the opaque template), `client.ts` (the `Api` interface; the token pages are composed from
  `getBooking`/`getPortal` plus one cached `getPublicPage` per slug), `appcheck.ts`, `firebasePhone.ts`,
  `verifier.ts`.
- `src/lib/` pure helpers: `locales.ts`, `digits.ts`, `bidi.ts`, `base64url.ts`, `phone.ts`, `countries.ts`,
  `datetime.ts` (everything in the professional's time zone), `format.ts` (`Formatter`), `policy.ts` (cancel and
  reschedule rules for wording deadlines; the server's `actions` decide what is offered), `ics.ts`, `storage.ts`,
  `config.ts`, `whatsapp.ts`, `text.ts`, `inapp.ts`, `image.ts`.
- `src/crypto/` `envelope.ts` (constants, AAD, key id, padding, payload types), `seal.ts` (HPKE, lazy chunk),
  `submit.ts`.
- `src/app/` router, store, page data, `booking/machine.ts` (pure state machine: `holdKey`, `alternatives`, UUID
  idempotency keys), `booking/store.ts`, `booking/summary.ts`, `booking/slotDays.ts`.
- `src/i18n/` fourteen catalogs (12 authored + derived `es-419.json` and `en-GB.json`), `overrides/`, `manifest.json`
  (all `needs_review`), `translate.ts`, `index.ts`. 413 keys (eleven that no screen used any more were removed).
- `src/legal/` generated legal texts (`scripts/build-legal.ts` embeds the iOS legal drafts, 5 documents x 14 locales).
- `src/components/`, `src/routes/{booking,manage,portal,form,checkin,data}/`, `src/styles/`.

**Scripts** (`web/scripts/`): `gen-regions.ts`, `gen-tokens.ts`, `check-contrast.ts`, `build-legal.ts`,
`check-size.ts`, `check-i18n.ts` (also fails on a catalog key no screen uses), `derive-locales.py`,
`check-privacy.ts`, `vite-integrity.ts` (SRI and `/.well-known/bellohub-build.txt`), `screenshots.ts`,
`make-fonts.py`, `list-keys.ts`. Repository root: `scripts/test-web.sh` (section 3).

**Tests.**
- Unit (Vitest): `test/unit/*.test.ts`, 13 files, 221 tests. New: `api.test.ts` (the callable envelope, the error
  table, the parsers, the client composition).
- Vectors: `test/vectors/inbox-v1.json` (9 positive, 12 negative) made with pyhpke and cryptography,
  `rfc9180-vectors.json`, `js-sealed.json`, README in `test/vectors/generate/README.md`.
- Mock API: `test/mock-server/{api,fixtures,slots,server,main}.ts`. Speaks API.md: callable envelope, 405 on any
  GET, the error table with HTTP and callable statuses, `getSlots` days (42-day cap), `holdKey`, idempotency with
  `CONFLICT`, `VERIFICATION_FAILED`, `KEY_MISMATCH`, `PAYLOAD_TOO_LARGE` with `maxBytes`, retry/`CONFLICT` on a
  reused `itemId`, `TOKEN_EXPIRED`/`NOT_FOUND` without details. Serves `dist-e2e/` with the headers of
  `hosting.json`, gzips text like Firebase Hosting, decrypts the sealed inbox with a test key, gives every test its
  own professional (`maria-t<id>`). Test controls under `/__test/*` (plain JSON, not the callable envelope).
- Playwright: `test/e2e/*.spec.ts` (booking, manage, portal, sealed, rtl, languages, a11y, interaction, security,
  perf), `support.ts` (fixtures and the `guard`), `flows.ts`. 190 tests across the three projects.

## 3. How to run the checks (and the last known result)

From the repository root: `scripts/test-web.sh [quick|full]` (default `full`). It installs what is missing
(`web/node_modules`, the Playwright browsers, the optional Python venv for the vectors), runs lint, typecheck,
i18n, contrast, privacy, the unit tests and the production build with its size budget, then in `full` mode the e2e
build and the whole Playwright suite. Only failures and a result line are printed; the full log is
`build/logs/test-web-<mode>-<stamp>.log`; one Playwright run per checkout (`build/.playwright.lock`). `E2E_PORT`
picks the mock's port when 4010 is busy (the backend agent's emulators use 5001, 9099, 8080, 9199, 4000, 15001).

Last result: `** WEB TESTS SUCCEEDED (full) **`, 175 passed, 15 skipped (WebKit skips the axe scans, the keyboard
tests and the low-end budget; low-end skips what the layout tests already cover), 1.1 minutes.

The individual commands, from `web/` (Node >= 22.18):

| Command | What it does | Last result |
|---|---|---|
| `npm ci` | install | clean |
| `npm run typecheck` | gen + `tsc` for src and for tests/scripts | clean |
| `npm run lint` | gen + ESLint `--max-warnings 0` | clean |
| `npm test` | gen + Vitest | 221 passed |
| `npm run i18n` | derive check + `check-i18n.ts` | 14 localizations, 413 keys, 0 problems |
| `npm run contrast` | contrast from the iOS Swift tokens | 140/140 pairs pass |
| `npm run privacy` | privacy gate | passed |
| `npm run build` | gen + production build + size budget | initial JS about 52 KB gzip (budget 80), CSS 6.8 KB |
| `npm run e2e` | `build:e2e` then all Playwright projects | 175 passed, 15 skipped |
| `npx playwright test --project=chromium` (and `webkit`, `lowend`) | one project; run `npm run build:e2e` after any source change | |

Mind the repository's two `derive-locales.py`: the one in the repo root is the iOS catalog; the web one is
`web/scripts/derive-locales.py`. Run the right one from the right place.

## 4. What remains, in priority order

1. **Owner decisions** (section 9): the first-visit answers, the guest names, the consent texts, the "counts as
   missed" wording, the Google Calendar link. Each is a small change once decided.
2. **Lighthouse CI.** Not set up. Plan: `@lhci/cli` as a dev dependency, `lighthouserc.json` with
   `collect.startServerCommand` `npx tsx test/mock-server/main.ts --serve-dist dist-e2e`, URLs `/maria` and a seeded
   `/m/<token>` (needs the seed call first, so a small Node script), `CHROME_PATH` pointing at the Playwright
   Chromium, assertions `categories:performance >= 0.9` (mobile preset) and `categories:accessibility >= 0.95`. The
   Playwright low-end test already guards LCP, CLS and the byte budgets. Add it as a step of `scripts/test-web.sh`.
3. **Hosting merge** (section 7) and the build step before deploy; the Hosting site id must start with `bellohub`
   or `bello-hub` (API.md CORS) if the page ever calls the functions cross-origin.
4. **Human tasks** (section 8), above all the real-iPhone check of the `<select>` console line (section 5).
5. Smaller: strict legal build (`BELLO_STRICT_LEGAL=1`) needs the operator details; the portfolio switch and
   struck-out times were deliberately left out; `DESIGN.md` should mention that colour fades of chips, buttons and
   options now respect Reduce Motion (this agent did not edit `DESIGN.md`).

## 5. The WebKit CSP report: found, scoped, not a page bug

Symptom (first session): under Playwright's WebKit every page with the phone country picker reported
`style-src-attr inline` and the guard failed about 20 tests.

Bisection (this session, static pages served by the mock under the shipped policy, no CSS, no script): the report
fires once per `<select>` element WebKit creates. It fires for an empty `<select>`, a hidden one, a listbox
(`multiple`, `size`), a menulist, with `appearance: none` from a stylesheet, on the iPhone profile and on desktop,
with or without focus or touch. The `<input type="tel">` with every attribute (`inputmode`, `autocomplete`,
`dir`) is innocent, as are `<input type="text">` and Preact. The sample is empty and the source is the script that
created the element (the entry bundle in the app, nothing on a static page). Chromium reports nothing. The refused
style changes nothing: the computed style, the box and the behaviour of the select are byte-identical with and
without the policy header (`getComputedStyle`, `getBoundingClientRect`, option count, `value` after a change).

Cause: WebKit's own user-agent shadow tree for `<select>` carries an inline style attribute, and this WebKit build
applies the page's CSP to it. It is the engine, not the page: no element of ours has a `style` attribute (the privacy
gate and `grep` both say so) and no script writes one.

What was done: the guard (`test/e2e/support.ts`) now reports every violation of every page and navigation through a
context binding (before, only the pages still open at the end were read) and excuses exactly one signature: WebKit,
`style-src-attr`, blocked URI `inline`, empty sample, while the page holds a `<select>`; the matching console line
("Refused to apply a stylesheet...") is excused once per such report. Any other violation, in any browser, still
fails the test. `'unsafe-inline'` and `'unsafe-hashes'` were not added; `hosting.json` is unchanged; the native
`<select>` stays.

For the owner, H8: on a real iPhone, open the "you" step of the booking with the Web Inspector attached and see
whether Safari prints the same "Refused to apply a stylesheet" line. If it does, it is cosmetic (no `report-uri`
or `report-to` is set, so nothing is sent anywhere); if the picker looked or behaved wrong, the alternatives would
be a custom country picker (departs from the native-components rule; needs a decision) or a `datalist`-backed text
field. Nothing else needs to change.

Other WebKit results: the "first Tab reaches Skip to content" test is now skipped on WebKit like the two other
keyboard tests (Safari does not Tab to links without the system option). The WebKit project is green: 74 passed,
15 skipped.

## 6. How the page reads API.md (deviations and derived behaviour)

What the page sends and reads is API.md sections 4 and 5 exactly; `src/api/types.ts` is the list. Where the page
derives something or had to decide:

- **Transport.** Every function is a callable POST at `{API_BASE}/{name}` (default `/api`, `VITE_API_BASE_URL`)
  with `{ data }` and `{ result }`; no GET anywhere (a GET of any function is 405 in the mock and a test asserts
  it). Errors map by `error.message` (section 3) onto the page's codes: `NOT_FOUND` -> `notFound`, `TOKEN_EXPIRED` ->
  `expired` (both pages look the same to the person), `RATE_LIMITED` -> `rateLimited` with `details.retryAfterSeconds`,
  `VERIFICATION_FAILED` -> `codeExpired` ("send a new code"), `INVALID_CODE` -> `codeInvalid`, `NOT_ALLOWED`,
  `CONFIRMATION_REQUIRED` and `BOOKING_NOT_ACTIVE` -> `notAllowed`, `KEY_MISMATCH` -> `keyMismatch` (the sealed
  pages drop their envelope and her cached page, then show "cannot be sealed right now"), `PAYLOAD_TOO_LARGE` ->
  `tooLarge`, `NOT_CONFIGURED` and `TRY_AGAIN` -> `unavailable`, `CONFLICT` and `INTERNAL` -> `server`. An error
  never carries a contact, so the expired-link page has no "Message Maria" button any more.
- **Profile.** `firstName` = the first word of `displayName`; `defaultLocale` = `locales[0]`; `rulesText` is split
  into lines (blank lines dropped, a leading `- `/`•` removed) and shown as "Maria's rules"; `bio` is one string;
  `businessName` is shown under the name; `credentials` are flat; a service `price` is `Money` and an add-on's
  `priceText` is words that are never summed (the per-person price is the service price only). `headline`, `tags`,
  `verifiedByPro`, `weekStart`, `use24Hour`, `askFirstVisitQuestions`, `waitlist` and `channels.emailCode` do not
  exist: the waiting list is always offered, email codes are always offered (a `NOT_CONFIGURED` answer shows as an
  error when sending), the first-visit questions are always asked, the region decides the week start and the clock.
- **Slots.** `getSlots` takes calendar days in the business zone (the month view asks from today to the end of the
  month, capped at the horizon; reschedule asks 28 days with `rescheduleToken`; rebook asks 35 days by slug and
  service); the `days[]` are flattened into one ascending list. The hold uses the draft's `holdKey` (random,
  per attempt, kept in the session draft so a refresh keeps the hold); `holdSlot` answers of `slotTaken` and
  `paused` become the page's `slotTaken`/`paused` errors, which the time screen already handles.
- **Booking.** `guests` is a count; `createBooking` sends only `note` (<= 300) from Bk-7; the proof is
  `{ method: 'phone', idToken }` or `{ method: 'email', proof }` and travels with every attempt, retries included (the
  proof stays in memory; the request is rebuilt from the same draft, so the idempotent replay carries the same
  verification as API.md 5.8 requires). `pendingApproval` has no reason: Bk-10 always says "she confirms new
  clients herself" (D42, never money or limits). `paused` has no scope: the page fetches her page again and shows
  Bk-1's notice if she stopped accepting bookings, Bk-10's "paused for you" otherwise. The confirmation (Bk-8)
  renders the server's times and service name plus the add-ons, guests and price from the draft; the health-form
  card shows when `intakeAvailable`.
- **Management.** The server's `actions` decide what Bk-9, Cl-6 and Cl-9 offer; `lib/policy.ts` only words the
  deadline. Cancelling after the window sends `acceptLateWarning: true` (the page already asked her); the done
  page reads `isLateCancellation`. A visit is "completed" when `status === 'confirmed' && phase === 'past'`.
  `reportLate` offers 10, 15, 20, 30. No `proReply`, `movedFrom`, price or guest names on the page.
- **Token pages.** `getBooking` and `getPortal` return a header only, so the client also calls `getPublicPage(slug)`
  (cached per slug) to get her languages, zone, currency, photo and city. `getFormContext` is composed from
  `getBooking` + the profile + `getFormContext`; a `NOT_FOUND` (no form published) leaves the check-in and the data
  request working with the key from her page. The template's questions are read from `template.questions` (or the
  template itself as a list), a question names its kind as `kind` or `type`, an unknown kind is left out.
- **Portal.** Only what `getPortal` returns: upcoming visits are listed without links, "book again" shows when a
  `rebook` section exists, the past list shows `summary`, aftercare shows `title` and `date`. There are no form,
  check-in or data links in the portal: `getFormContext` and `submitSealed` need a booking (a manage link). The
  outcome of a rebook (approval, pause) is only known from the server's answer, so the page shows no gate before it.
- **Waitlist.** `dayFrom`/`dayTo` are calendar days; `serviceId` is sent when known.
- **Find.** `findBookings` carries the phone with the proof; the list shows the duration from `endsAt - startsAt`
  and the professional's name from her page.
- **Sealed.** Unchanged: `{ v: 1, suite, keyId, kind, itemId, enc, ct }`; the page's plaintext limits are the caps of
  docs/06 section 3.4 (the server allows +1 KB for the tag and framing). A 21st unacknowledged item answers
  `RATE_LIMITED`, shown as "Too many tries. Wait a moment and try again." (`details.maxItems` is not worded).
- **Not called:** `getHold` (the waitlist offer link `/{slug}/time?offer=<holdKey>` is not built yet), `getIcs`
  (the calendar file is built in the browser; the server's variant would put the manage token in a URL).

Behaviour that departs from the docs or the prototype (candidates for ASSUMPTION entries), unchanged from the
first session: guest count chosen on Bk-2; profession-neutral first-visit questions; the booking draft in
`sessionStorage` (name, phone, email, service, time, guest names, hold key; never a code, proof, answer or token);
D42 wording on Bk-10; reCAPTCHA vs "no third-party scripts" (section 7, item 4); MX clock follows the region;
struck-out times and the portfolio switch not built; no SRI on lazy chunks; `form-action 'self'`.

## 7. Hosting: the exact `firebase.json` changes for the coordinator

`web/hosting.json` is a fragment, not a config. Merge its `hosting` object into `firebase/firebase.json`:

1. `hosting.public` = `web/dist` (relative to the repository root, as in the fragment) and run `npm --prefix web ci &&
   npm --prefix web run build` before `firebase deploy --only hosting` (the build also writes the SRI hashes and
   `dist/.well-known/bellohub-build.txt`). Set the build-time variables from section 6 for the real project.
2. `hosting.headers`: copy the `**` block (CSP, HSTS with preload, `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy:
   no-referrer`, COOP, CORP, Permissions-Policy, `Cache-Control: no-cache`) and the blocks for `/m/**` and `/p/**`
   (`no-store`, `X-Robots-Tag: noindex, nofollow`), `/api/**` (`no-store`), `/assets/**` (immutable), `/fonts/**`,
   `/.well-known/**`.
3. `hosting.rewrites`: one `/api/{name}` rewrite per public function to `europe-west1` (the 18 listed, add a line per
   new function) and the catch-all `** -> /index.html` last. If the function names in the backend differ, change them
   here and in `test/mock-server/server.ts` (`callFunction`).
4. Decide the CSP variant from the reCAPTCHA item: Firebase phone sign-in and App Check with reCAPTCHA Enterprise
   load Google scripts and frames, which the strict baseline forbids. Either a looser CSP for the booking paths
   (`script-src` and `frame-src` for `https://www.google.com/recaptcha/` and `https://www.gstatic.com/recaptcha/`,
   `connect-src` for `identitytoolkit.googleapis.com`, `securetoken.googleapis.com`,
   `firebaseappcheck.googleapis.com`) while the sealed paths keep the strict one, or SMS through the API only.
5. Domain (H6): the rewrites assume the page and `/api` share one origin, so the CSP can say `connect-src 'self'`.
   If the page ever calls `https://europe-west1-<project>.cloudfunctions.net` directly, the Hosting site id must start
   with `bellohub` or `bello-hub` (API.md CORS, backend commit b0a1aaa) and `connect-src` must name that origin.
   Slugs are `a-z0-9-` 3 to 30 characters; the reserved list is `RESERVED_SLUGS` in `src/app/router.ts` and must match
   the backend's.

The Playwright suite and the mock read the same `headers`, so what is tested is what ships.

## 8. Human tasks

- **H8, in-app browsers (WhatsApp, Instagram) and real iPhone.** On a real iPhone (Safari) and from a link tapped inside
  WhatsApp and Instagram, check: the page renders and the language is right; the booking runs to the confirmation
  (the SMS code is the risk); whether the console shows the `<select>` line of section 5; the calendar `.ics` and
  Google links work or the in-app note appears (`cal.inApp`); the personal link copies, or the manual selection
  fallback appears; a photo can be chosen in the check-in (camera and library) and previews; `<dialog>` sheets open,
  trap focus, close with the back gesture; no horizontal scroll; Arabic mirrors; Dynamic Type at the largest sizes;
  Low Power Mode; storage blocked (private mode) still books; links to WhatsApp open the app; nothing asks for
  cookies or permissions.
- **H6, domain.** DNS and the Hosting site for the real domain, HSTS preload submission, the `/privacy` operator details
  (name, address, contact, DPO) via the legal build variables, then `BELLO_STRICT_LEGAL=1 npm run build`.
- **H4, Firebase.** The web app config (`VITE_FIREBASE_CONFIG`), the App Check site key (`VITE_APP_CHECK_SITE_KEY`) and the
  phone provider in the real project. Local runs use the emulators with `--project demo-bellohub`; this agent never
  touched a real project. Against the emulators the page needs `VITE_API_BASE_URL=http://127.0.0.1:5001/demo-bellohub/europe-west1`
  (or a dev proxy) and `VITE_AUTH_EMULATOR_URL`; the email code is `123456` there.
- Native-language review is not planned (D41); `src/i18n/manifest.json` keeps every locale `needs_review`.

## 9. Decisions needed from the owner

1. **First-visit answers (Bk-7).** The page asks "how did you hear about her" and "been before" but sends only the
   note (API.md stores `note` only). Keep asking and send them sealed, drop the two questions, or add them to
   `createBooking`? Until then the UI stays and the answers go nowhere.
2. **Guest names (Bk-5).** The page asks one name per guest; the server stores a count (API.md 5.8). Drop the name
   fields, or send them sealed with the intake? They stay on the page only (they are in the session draft).
3. **Consent texts.** `getFormContext` returns the consent texts she published per language; the page still shows
   its own embedded consent drafts (`src/legal`, with the checkbox statement and sign label) and records their
   version in the sealed payload. Which text is the contract: hers (then the page needs a layout for plain text) or
   the embedded one (then `publishProfile.intake.consent` is unused)?
4. **"Counts as a missed appointment."** The policy on the booking has no `lateCancelCounts` (it is a no-show
   setting the profile does not publish). After the free window the page now always warns that a late cancellation
   may count, and Bk-9 says "it counts" in the cancel row. Either publish the flag or accept the wording.
5. **Google Calendar link.** The event's description carries the personal link, so tapping "Google Calendar" sends
   the manage token to Google in the URL (by her own action, like saving the `.ics`). Keep (useful: the link is in
   her calendar) or leave the link out of the Google variant?
6. **Portal and the sealed pages.** `getFormContext`/`submitSealed` accept a manage link only, so the portal has no
   path to the form, the check-in or the data request. Fine for v1, or should the backend accept a portal token for
   `getFormContext` (with the latest booking) and `submitSealed`?
7. **Reduce Motion.** Colour fades of chips, buttons and options now stop under Reduce Motion (they ran regardless
   and axe sampled a mid-fade colour). `DESIGN.md` motion section should say so; this agent did not edit it.

## 10. Security checklist (this session's review; one line per item)

- **HPKE suite and framing.** Fine. `envelope.ts` and `seal.ts` match docs/06 section 3.1 and 3.3 and the vectors
  README: base mode, DHKEM(X25519, HKDF-SHA256) + HKDF-SHA256 + ChaCha20-Poly1305, `info` `bellohub/inbox/v1`, AAD
  `bellohub/v1|<kind>|<itemId>|<keyId>`, `keyId = base64url(SHA-256(pub)[0..<8])`, `_pad` to 1 KiB (16 KiB for a
  check-in with a photo), base64url without padding. The 9 positive vectors made with pyhpke reproduce byte for
  byte and the 12 negative ones fail to open (`npm test`). The item id is a fresh UUID v4 per seal; a retry resends
  the same bytes and the server treats a different ciphertext under the same id as `CONFLICT`.
- **Key verification.** Residual (known, accepted by docs/06): the page checks that `pub` is 32 bytes and that
  `keyId` is its hash, so a swapped key with a stale id is refused (a test proves it); a server that swaps the key
  AND recomputes the id is only caught by the app's own check (docs/06 section 3.2). New this session: a
  `KEY_MISMATCH` answer drops the envelope and the cached profile so no retry ever reuses the old key.
- **Manage tokens in transit and at rest.** Fine. Tokens travel only in POST bodies (a test fails if any `/api/`
  URL contains one); the pages `/m/**` and `/p/**` are `no-store` and `noindex`; `Referrer-Policy: no-referrer`
  as a header and a meta; every outbound link is `noopener noreferrer`; `sessionStorage` holds the booking draft
  only (never a token, a code, a proof or an answer; a unit test greps the serialized draft); nothing calls
  `console.*` (the privacy gate parses the syntax tree); the error type carries a code only.
- **Token exposure by the client's own action.** Residual: the personal link is copied to the clipboard on tap and
  is written into the `.ics` description and the Google Calendar URL (decision 9.5); browser history keeps `/m/<token>`
  (the URL is the key by design); link previews by WhatsApp or Instagram fetch the HTML shell only (the token is
  never in the HTML; the API needs a POST).
- **Error details.** Fixed. The expired-link page no longer expects a contact in the error: API.md never puts
  personal data in `details`, and an unknown and an expired link look the same.
- **Privacy gate and guard.** Fine, with one change. `check-privacy.ts` still forbids storage and cookies on the
  sealed routes, markup from strings, `console.*`, and any absolute URL other than the two the client taps. The
  guard now sees every CSP violation of every page and navigation (a context binding, not a read of the pages left
  open), every request, cookie and storage key. The only tolerance is the WebKit `<select>` signature of section 5.
- **CSP.** Fine. `default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self' data:;
  connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; manifest-src 'none'; object-src
  'none'`, no `unsafe-*`, no wildcard, no remote host; a test asserts the directives and their absence. Residual:
  the reCAPTCHA/phone sign-in variant (section 7, item 4) is an owner decision; `form-action 'self'` could be
  `'none'` since no form submits.
- **SRI.** Fine. Every `<script>` and stylesheet `<link>` of `index.html` carries `integrity="sha384-..."` written
  from the built file at build time; `/.well-known/bellohub-build.txt` lists the SHA-256 of every served file and a
  hash over the list, and a test fetches eight files and recomputes them. Residual (known): lazy chunks (language
  files, the sealing library, Firebase) cannot carry `integrity` on a dynamic import; `script-src 'self'` and the
  published list cover them.
- **Mock versus real backend.** Fine for what is tested: the mock enforces what API.md says the functions enforce
  (token-only POST, idempotency and `CONFLICT`, verification matching the phone or email, size caps, approval and
  pause decided server-side, no phone enumeration in `findBookings`). Not mirrored in the mock: rate limits, the
  20-item mailbox cap, App Check, the 7-day token expiry after the visit (the mock expires tokens the same way but
  nothing tests it).

## 11. Known issues and findings

- The portal tabs moved focus in a `setTimeout` after rendering the panel in a microtask; under load a second
  arrow key acted on the old tab (3 of 12 runs). Focus now moves synchronously in the key handler.
- The guests chip on Bk-2 faded its colours regardless of Reduce Motion; axe sampled the mid-fade colour and
  failed the booking-flow scan every run of this session. Chips, buttons and options now only transition under
  `prefers-reduced-motion: no-preference`.
- Real bugs the suite found and fixed in the first session: `cl9.noTimes` without `{name}`; the calendar overflowed
  320 px; bars outside landmarks; the photo input without a name; 22 px text buttons; portal tabs without Home/End.
- The Vite chunk warning is silenced with a justified limit in `vite.config.ts`; the real budget is `check-size.ts`.
- For the next agent: after editing any source file run `npm run build:e2e` before Playwright; the mock serves the
  built `dist-e2e/`, not the source. The probe pages of the CSP bisection were written under `dist-e2e/probe/` and
  removed; nothing outside the repository is needed (scratch scripts lived in the session scratchpad).
