# Agent notes: S9, the client web app (`web/`)

Branch `worktree-agent-ac7ea3c725dfcc9b0`, based on 407427e. Five commits on top (248bedd foundation and app, 1f25deb
before it, 52e5948 localizations, 265f170 privacy gate and unit tests, 27e6f2d Playwright suite). Nothing was pushed.
Everything this agent touched is under `web/` plus this file. `docs/PROGRESS.md`, `DESIGN.md`, `firebase/` and every
iOS file are untouched. This is a hand-off: a fresh agent continues from here. Read "What remains" first.

## 1. State in one paragraph

The SPA is complete against a mock API that this agent wrote from `docs/10-WEB-BOOKING.md` and
`docs/11-BACKEND-FIREBASE.md` section 3 (no `firebase/functions/API.md` was available). Every page of the brief
exists and is covered by tests: booking Bk-1..Bk-8, approval/pause Bk-10, find Bk-11, management Bk-9, reschedule
Cl-9, cancel Cl-6, portal Cl-2, rebook Cl-3, health intake Cl-4 (adult and minor), skin check-in Cl-5, my data Cl-7.
Fourteen localizations pass the gate. The independent HPKE vectors pass in both directions. Chromium and the throttled
low-end project were green in the last full run; the WebKit project has failures (section 5). Not written yet:
`scripts/test-web.sh`, the Lighthouse CI config, and the review of the WebKit problem.

## 2. What is done, with paths

All paths are relative to `web/` unless they start with `docs/`.

**Stack and tooling.** Preact 10 + TypeScript 5.9 strict (`noUncheckedIndexedAccess`) + Vite 7 + Vitest 4 + ESLint
flat config `strictTypeChecked` (zero warnings). `package.json`, `tsconfig.json` (src), `tsconfig.node.json`
(tests, scripts, configs), `eslint.config.js`, `vite.config.ts`, `vitest.config.ts`, `playwright.config.ts`,
`.env.e2e`, `.gitignore`. Exact dependency versions, `npm audit` clean at the last install.

**Source.**
- `src/lib/` pure helpers: `locales.ts`, `digits.ts`, `bidi.ts`, `base64url.ts`, `phone.ts`, `countries.ts`,
  `datetime.ts` (everything in the professional's time zone), `format.ts` (`Formatter`), `policy.ts` (cancel and
  reschedule rules, shared fixture `test/fixtures/policy-cases.json` with the iOS side), `ics.ts`, `storage.ts`,
  `config.ts`, `whatsapp.ts`, `text.ts`, `inapp.ts`, `image.ts`.
- `src/api/` one typed client: `types.ts` (the whole contract), `errors.ts`, `transport.ts` (the only `fetch`),
  `parse.ts`, `client.ts`, `appcheck.ts`, `firebasePhone.ts`, `verifier.ts`.
- `src/crypto/` `envelope.ts` (constants, AAD, key id, padding, payload types), `seal.ts` (HPKE, lazy chunk),
  `submit.ts`.
- `src/app/` router, store, page data, `booking/machine.ts` (pure state machine), `booking/store.ts`,
  `booking/summary.ts`, `booking/slotDays.ts`.
- `src/i18n/` fourteen catalogs (12 authored + derived `es-419.json` and `en-GB.json`), `overrides/`, `manifest.json`
  (all `needs_review`), `translate.ts`, `index.ts`.
- `src/legal/` generated legal texts (`scripts/build-legal.ts` embeds the iOS legal drafts, 5 documents x 14 locales).
- `src/components/`, `src/routes/{booking,manage,portal,form,checkin,data}/`, `src/styles/`.

**Scripts** (`scripts/`): `gen-regions.ts`, `gen-tokens.ts` (CSS tokens from the iOS Swift palette, light, dark and
Increase Contrast), `check-contrast.ts` (140 text/background pairs from the same Swift files), `build-legal.ts`,
`check-size.ts` (initial JS <= 80 KB gzip, CSS <= 15, sealing chunk <= 60, language and legal chunks <= 15),
`check-i18n.ts` (full localization gate), `derive-locales.py`, `check-privacy.ts` (syntax-tree gate), `vite-integrity.ts`
(SRI and `/.well-known/bellohub-build.txt`), `screenshots.ts` (design-review tool), `make-fonts.py`, `list-keys.ts`.

**Tests.**
- Unit (Vitest): `test/unit/*.test.ts`, 12 files, 211 tests: crypto vectors and cross-implementation, date/time,
  digits/bidi, formatter, ICS, locales, phone, policy, booking state machine, `translate` (all 14 catalogs rendered for
  every plural count), intake rules, `groupByDay`.
- Vectors: `test/vectors/inbox-v1.json` (9 positive, 12 negative) produced by `test/vectors/generate/generate.py` with
  pyhpke and cryptography (a different implementation from the page's hpke-js), `rfc9180-vectors.json`,
  `js-sealed.json`, README in `test/vectors/generate/README.md`.
- Mock API: `test/mock-server/{api,fixtures,slots,server,main}.ts`. Serves `dist-e2e/` with the headers of
  `hosting.json`, gzips text like Firebase Hosting, decrypts the sealed inbox with a test key, and gives every test its
  own professional (`maria-t<id>` is `maria` with private state). Test controls under `/__test/*`.
- Playwright: `test/e2e/*.spec.ts` (booking, manage, portal, sealed, rtl, languages, a11y, interaction, security,
  perf), `support.ts` (fixtures and the `guard`), `flows.ts`. 188 tests across the three projects.

## 3. How to run the checks (and the last known result)

All from `web/`. Node >= 22.18.

| Command | What it does | Last result |
|---|---|---|
| `npm ci` (or `npm install`) | install | clean |
| `npm run typecheck` | gen + `tsc` for src and for tests/scripts | clean |
| `npm run lint` | gen + ESLint `--max-warnings 0` | clean |
| `npm test` | gen + Vitest | 211 passed |
| `npm run i18n` | derive check + `check-i18n.ts` | 14 localizations, 424 keys, 0 problems |
| `npm run contrast` | contrast from the iOS Swift tokens | 140/140 pairs pass, 0 CSS misuses |
| `npm run privacy` | privacy gate | passed |
| `npm run build` | gen + production build + size budget | initial JS about 52 KB gzip (budget 80), CSS 6.8 KB |
| `npm run e2e` | `build:e2e` then all Playwright projects | see below |
| `npx playwright test --project=chromium` (and `webkit`, `lowend`) | one project; run `npm run build:e2e` after any source change, the mock serves `dist-e2e/` | |
| `npx tsx scripts/screenshots.ts --locale ar --out build/screens/ar` | design review screenshots (needs `npm run mock:e2e` running) | |

Playwright last full run (188 tests, 4 workers): no failing test listed for Chromium or the low-end project; WebKit had
about 25 failures (section 5). The final summary line of that run was cut off, so treat the Chromium and low-end
result as "no failure seen" and re-run to confirm. Spec-level runs on Chromium that passed in full: booking 11, manage
11, sealed 11, portal 5, rtl 11, languages 8, a11y 12 (axe, zero violations, en and ar, plus dark and Increase
Contrast), interaction 11, security 10; low-end 12 (including the performance budget).

Low-end measurement (Moto G4 profile, CPU 4x, 1.6 Mbit/s, 150 ms): LCP about 2.1 s, CLS 0, blocking time about 0-16 ms,
JS 57.8 KB, CSS 6.8 KB, fonts 46 KB, 6 requests. Budgets in `test/e2e/perf.spec.ts`: LCP < 3000, CLS < 0.05.

The cross-implementation vectors need Python: `python3 -m venv .venv && .venv/bin/pip install -r
test/vectors/generate/requirements.txt && .venv/bin/python test/vectors/generate/generate.py` regenerates
`inbox-v1.json`; `npx tsx test/vectors/generate-js.ts` regenerates `js-sealed.json`. The unit tests read the committed files.

Mind the repository's two `derive-locales.py`: the one in the repo root is the iOS catalog; the web one is
`web/scripts/derive-locales.py`. Run the right one from the right place.

## 4. What remains, in priority order

1. **`scripts/test-web.sh`** (repo root, like the other wrappers): install if `web/node_modules` is missing (and the
   Python venv for the vectors), then `npm run lint`, `typecheck`, `i18n`, `contrast`, `privacy`, `npm test`,
   `npm run build` (size budget), `npm run e2e`; print only failures and a result line; full log to `build/logs/`;
   one `playwright` at a time. Not written. The npm scripts above are what it should call.
2. **WebKit.** Section 5. Decide whether the failures are real before anything else: they may be a Safari-only CSP
   report on the phone country picker, which would block real iPhone users on the "you" step.
3. **Lighthouse CI.** Not set up. Plan: `@lhci/cli` as a dev dependency, `lighthouserc.json` with `collect.startServerCommand`
   `npx tsx test/mock-server/main.ts --serve-dist dist-e2e`, URLs `/maria` and a seeded `/m/<token>` (needs the seed
   call first, so use a small Node script), `CHROME_PATH` pointing at the Playwright Chromium, assertions
   `categories:performance >= 0.9` (mobile preset) and `categories:accessibility >= 0.95`. If Chrome cannot be found
   the command to give the owner is `npx lhci autorun --config=lighthouserc.json`. The Playwright low-end test already
   guards LCP, CLS and the byte budgets.
4. **Reconcile with `firebase/functions/API.md`** when it lands (section 6 lists every assumption). The only file to
   change should be `src/api/{types,client,transport,parse}.ts` and the mock.
5. **Hosting merge** (section 7) and the build step before deploy.
6. **Human tasks** (section 8).
7. Smaller: strict legal build (`BELLO_STRICT_LEGAL=1`) needs the operator details; the portfolio switch and struck-out
   times (below) were deliberately left out.

## 5. The CSP / WebKit problem (unfinished)

Symptom, WebKit project only (Playwright WebKit with the iPhone 14 profile): the `guard` fixture reports
`style-src-attr inline` on every test that goes through the booking "you" step, the waiting-list sheet, the find page
and the data-request sheet. Console text: "Refused to apply a stylesheet because its hash, its nonce, or 'unsafe-inline'
does not appear in the style-src directive". The app writes no inline style anywhere (`grep style= src` is empty; no
`.style`, no `setAttribute('style')`), and the same pages are clean in Chromium.

What was learned with `scratchpad/csp-webkit.mjs` (a scratch script, not committed): the home page, the manage pages and
the health form are clean in WebKit. The report appears when the page moves from the time step to the "you" step, and
the event says `sourceFile` = the entry bundle, line 2, column 7864, which is inside Preact's `diffElementNodes` (element
creation). Patching `cssText`, `setProperty` and `setAttribute('style')` logged nothing, so no script wrote a style.
Common to the failing pages: they all render `PhoneField`, a `<select>` with about 250 `<option>` country entries next to
`<input type="tel">`. Hypothesis: WebKit (not our code) adds an inline style while creating or sizing that `<select>` or
the tel input, and reports it against `style-src 'self'`. Not proven.

Next steps: (a) in WebKit, load a static page under the same CSP containing only that `<select>` and `<input
type="tel" autocomplete="tel-national">` and see if the report appears; bisect by removing `autocomplete`, `inputmode`,
`dir`, the option count; (b) check on a real iPhone (H8) because Playwright's WebKit is not Safari; (c) if it is a
WebKit quirk with no workaround, the choices are to accept the report (it only says a style was refused; the page still
works) if real Safari does not show it, or to replace the native country `<select>` with another control, which departs
from the native-components rule and needs the owner's decision. Do not add `'unsafe-inline'` or `'unsafe-hashes'` to
`style-src`.

Other WebKit failures in the same run that are expected, not bugs: the "first Tab reaches Skip to content" test (Safari
does not Tab to links without the system option; mark it `test.skip` for webkit like the two other keyboard tests) and
tests that fail only because the guard sees the report above. Re-run after the cause is found and list what is left.

## 6. Deviations and unconfirmed assumptions (API and behavior)

No `API.md` existed. These are assumptions in `src/api/types.ts` and `client.ts`, mirrored by the mock:

- Functions live at `{API_BASE}/{name}` (default `/api`, `VITE_API_BASE_URL`). `getPublicPage` and the slug variant of
  `getSlots` are GET with a query string; everything else is POST JSON, and every call that carries a token is POST with
  the token in the body, never in a URL (the mock answers 405 to a GET of those; a test asserts it).
- Success is 2xx with the typed body. Errors are non-2xx with `{ error: { code, retryAfterSeconds?, professional?:
  { displayName, firstName, whatsappE164? } } }`. Codes the page handles: `notFound`, `expired`, `slotTaken`,
  `codeInvalid`, `codeExpired`, `tooManyAttempts`, `rateLimited`, `invalidInput`, `notAllowed`, `tooLarge`,
  `unavailable`, `appCheck`. An unknown token and an expired one look the same to the person.
- `getSlots` token variant takes `purpose: 'reschedule' | 'rebook'` and returns `{ slots, durationMinutes }`.
- `holdSlot` returns `{ holdId, expiresAt }` (5 minutes) and can fail with `slotTaken`.
- `createBooking` returns one of `confirmed { manageToken, booking }`, `pendingApproval { reason, manageToken }` (reason
  `newClient` or `noShowLimit`), `paused { scope: 'page' | 'client' }`, `slotTaken { nextSlots }`. It takes the
  verification proof (`{ kind: 'sms', idToken }` = Firebase ID token, or `{ kind: 'email', token }`), an
  `idempotencyKey`, and optional `firstVisit { heardFrom, hadBefore, note }`. The page never learns whether a phone is
  already a client: the approval decision is the server's.
- `sendEmailCode` and `verifyEmailCode`; `sendSmsCode` and `verifySmsCode` exist only for `VITE_SMS_VERIFIER=api` (tests).
- `findBookings` returns a fresh manage token per result. Token endpoints accept a manage or a portal token.
- `BookingView` carries the policy snapshot, `serverNow`, optional `client.firstName`, `forms { intake, checkIn }`,
  `rules` per locale. The public profile carries `rules` per locale as `{ kind, text }[]`, `inboxKey`
  `{ keyId, alg: 'hpke-v1', pub }`, `channels.whatsAppAutomation`, optional `weekStart` and `use24Hour`.
- Cancel `reason` is a key: `conflict | unwell | changed | other`.
- Intake payload adds optional `consent.photos` (the guardian's photo box) beyond docs/06 section 3.4. `clientName` is the
  typed signature (adult) or the guardian's name (minor). The data request carries `name` and `phone`.
- The sealed envelope is `{ v: 1, suite, keyId, kind, itemId, enc, ct }`; the mock enforces the plaintext limits of
  docs/06 section 3.4 plus the 16-byte tag.

Behavior that departs from the docs or the prototype (candidates for ASSUMPTION entries):

- **Guest count is chosen on Bk-2**, not Bk-5, because the total duration drives the slots; Bk-5 only asks for one name
  per guest (D19 keeps guests in sequence).
- **First-visit questions are profession-neutral** (how did you hear, been before, a preference note with a "no health
  details here" warning) instead of the prototype's skincare goals.
- **Booking draft in `sessionStorage`**: name, phone, email, service, time, guest names (never a code, proof, answer or
  token), so a refresh does not lose them. The brief says "only the language in localStorage"; this is tab-scoped and
  cleared with the tab. Remove `src/app/booking/store.ts` persistence if the owner wants strictly nothing.
- **D42**: the "waiting for approval" page uses the generic new-client reason and never mentions money, plans or limits;
  `maria-approval` tests assert the absence of those words.
- **reCAPTCHA vs "no third-party scripts"**: Firebase App Check with reCAPTCHA Enterprise and Firebase phone auth load
  Google scripts and frames, which conflicts with docs/06 section 6 on pages with a form. The strict CSP baseline in
  `hosting.json` has none of that. Both are lazy and config-gated (`VITE_SMS_VERIFIER`, `VITE_APP_CHECK`,
  `VITE_FIREBASE_CONFIG`, `VITE_APP_CHECK_SITE_KEY`, `VITE_AUTH_EMULATOR_URL`). The coordinator must choose: a looser CSP
  variant for the booking page (`script-src` and `frame-src` for `https://www.google.com/recaptcha/` and
  `https://www.gstatic.com/recaptcha/`, `connect-src` for `identitytoolkit.googleapis.com`, `securetoken.googleapis.com`,
  `firebaseappcheck.googleapis.com`) while the sealed pages keep the strict one (per-path `headers` rules), or SMS through
  the API only. The Firebase packages are the scoped `@firebase/app`, `@firebase/app-check`, `@firebase/auth` (the
  umbrella `firebase` package pulled an advisory through Firestore; `npm audit` is clean without it).
- **MX clock**: the browser data says Mexico uses a 12-hour clock; the professional's `use24Hour` overrides it.
- **Not built on purpose**: struck-out unavailable times in reschedule, and the portfolio-photo switch in Cl-7 (shown as
  an explanation only).
- **No SRI on lazy chunks** (language files, sealing library, Firebase): dynamic imports cannot carry an integrity
  attribute; `script-src 'self'` and the published bundle hash cover them.
- `form-action 'self'` in the CSP; docs/10 may want `'none'` since there are no HTML forms that submit.

## 7. Hosting: the exact `firebase.json` changes for the coordinator

`web/hosting.json` is a fragment, not a config. Merge its `hosting` object into `firebase/firebase.json`:

1. `hosting.public` = `web/dist` (relative to the repository root, as in the fragment) and run `npm --prefix web ci &&
   npm --prefix web run build` before `firebase deploy --only hosting` (the build also writes the SRI hashes and
   `dist/.well-known/bellohub-build.txt`). Set the build-time variables from section 6 for the real project.
2. `hosting.headers`: copy the `**` block (CSP, HSTS with preload, `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy:
   no-referrer`, COOP, CORP, Permissions-Policy, `Cache-Control: no-cache`) and the blocks for `/m/**` and `/p/**`
   (`no-store`, `X-Robots-Tag: noindex, nofollow`), `/api/**` (`no-store`), `/assets/**` (immutable), `/fonts/**`,
   `/.well-known/**`.
3. `hosting.rewrites`: one `/api/{name}` rewrite per public function to `europe-west1` (the 18 listed, add a line per new
   function) and the catch-all `** -> /index.html` last. If the function names in the backend differ, change them here
   and in `test/mock-server/server.ts` (`POST_ONLY`).
4. Decide the CSP variant from the reCAPTCHA item above and keep `/{slug}` and the sealed paths consistent with it.
5. Domain (H6): the rewrites assume the page and `/api` share one origin, so the CSP can say `connect-src 'self'`.
   Slugs are `a-z0-9-` 3 to 30 characters; the reserved list is `RESERVED_SLUGS` in `src/app/router.ts` and must match the
   backend's.

The Playwright suite and the mock read the same `headers`, so what is tested is what ships.

## 8. Human tasks

- **H8, in-app browsers (WhatsApp, Instagram) and real iPhone.** On a real iPhone (Safari) and from a link tapped inside
  WhatsApp and Instagram, check: the page renders and the language is right; the booking runs to the confirmation
  (the phone country picker and the SMS code are the risk from section 5); the calendar `.ics` and Google links work or
  the in-app note appears (`cal.inApp`); the personal link copies, or the manual selection fallback appears; a photo can
  be chosen in the check-in (camera and library) and previews; `<dialog>` sheets open, trap focus, close with the back
  gesture; no horizontal scroll; Arabic mirrors; Dynamic Type at the largest sizes; Low Power Mode; storage blocked
  (private mode) still books; links to WhatsApp open the app; nothing asks for cookies or permissions.
- **H6, domain.** DNS and the Hosting site for the real domain, HSTS preload submission, the `/privacy` operator details
  (name, address, contact, DPO) via the legal build variables, then `BELLO_STRICT_LEGAL=1 npm run build`.
- **H4, Firebase.** The web app config (`VITE_FIREBASE_CONFIG`), the App Check site key (`VITE_APP_CHECK_SITE_KEY`) and the
  phone provider in the real project. Local runs use the emulators with `--project demo-bellohub`; this agent never
  touched a real project.
- Native-language review is not planned (D41); `src/i18n/manifest.json` keeps every locale `needs_review`.

## 9. Known issues and findings

- WebKit CSP report and the resulting failures (section 5).
- One flaky observation: an axe color-contrast hit on the Arabic guests chip appeared once and did not repeat; the a11y
  tests run with `reducedMotion: 'reduce'` because axe samples colours mid-fade otherwise. Run the Arabic booking-flow axe
  test with `--repeat-each=5` before trusting it.
- Real bugs the suite found and fixed: `cl9.noTimes` rendered without `{name}`; the calendar overflowed 320 px; top bars
  and the action bar sat outside landmarks (action bar is now a named region, new string `common.actions`); the photo
  input had no accessible name; text buttons and `<summary>` were 22 px high; portal tabs lacked Home and End.
- The Vite chunk warning is silenced with a justified limit in `vite.config.ts`; the real budget is `check-size.ts`.
- For the next agent: after editing any source file run `npm run build:e2e` before Playwright; the mock serves the
  built `dist-e2e/`, not the source.
- Scratch files live outside the repository (`/private/tmp/.../scratchpad`): `csp-webkit.mjs`, `overflow*.mjs`,
  `paint.mjs`, `kbd.mjs`, `add_key.py`. Nothing there is needed.

## 10. What deserves an adversarial security review

1. **Sealed envelope and HPKE.** `src/crypto/envelope.ts`, `seal.ts`, `submit.ts`. Check the suite ids, `info`, the AAD
   string, padding and the size limits against docs/06 section 3, the base64url handling, the single-use item id and the
   same-bytes retry. The independent vectors (`test/vectors/`) were made with pyhpke, but the framing (padding and AAD
   assembly) was written by the same agent in both; a third reader should compare against the spec. Known limit:
   `verifiedPublicKey` proves only that `keyId` is the hash of `pub`. A compromised server that swaps the key AND
   recomputes the id is not detected by the page; the real check is the app's (docs/06 section 3.2). A reviewer should
   confirm that limit is acceptable and that the page never reuses an envelope across kinds.
2. **Token handling.** Tokens live in the page path `/m/<token>`, `/p/<token>`; they are sent only in POST bodies, the
   pages are `no-store` and `noindex`, `Referrer-Policy: no-referrer`, links out use `noopener noreferrer`. Review: link
   previews by WhatsApp and Instagram fetching the page, browser history and tab sync exposure, what an unknown or
   expired token reveals (kept identical), and whether a manage token should be rotated after a reschedule.
3. **The privacy gate and the guard fixture.** `scripts/check-privacy.ts` (storage, console, string markup, URLs in the
   syntax tree) and `test/e2e/support.ts` (`guard`: every request, cookie, CSP violation, storage key). Check they
   cannot be bypassed, for instance by a URL assembled at run time or by a request the page makes before the init
   script is installed.
4. **CSP and SRI.** `hosting.json` headers, `scripts/vite-integrity.ts`, and the Firebase and reCAPTCHA variant decision.
5. **Mock versus real backend.** The mock enforces rules that the real functions must also enforce (idempotency,
   token-only POST, size limits, approval decided server-side, no phone enumeration). Anything the mock does that the
   backend does not is a test that proves nothing.
6. **Sensitive text in the page.** `src/routes/form/payload.ts` (what goes into the payload), `image.ts` (EXIF stripped by
   a canvas re-encode), and the rule that the first-visit note is not clinical (it travels to `createBooking` in clear;
   the UI warns, nothing technical stops a person typing health data there).
