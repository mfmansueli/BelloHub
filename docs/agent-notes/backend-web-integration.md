# Agent notes: backend + web integration (S8 exit, S9 hosting)

Branch `backend-web`, created from `build/v1` at `af1d03a`. It merges the backend branch (`worktree-agent-a243edc65aa8fcdad`,
tip `983279c`, notes in `backend.md`) and the web branch (`worktree-agent-ac7ea3c725dfcc9b0`, tip `15a053f`, notes in
`web.md`), then adds the Hosting block, the end-to-end script and Lighthouse CI. Nothing was pushed, deployed or run
against a real project; every emulator run used `demo-bellohub`. `docs/PROGRESS.md`, `DESIGN.md`, `docs/14-HUMAN-TASKS.md`
and every iOS file are untouched. Both merges were clean (no conflicts: the two branches touched disjoint paths).

## 1. Commits

| Commit | What |
|---|---|
| `e9f2c8a` | Merge backend (`firebase/`, `scripts/test-firebase.sh`, `docs/agent-notes/backend.md`) |
| `a43629b` | Merge web (`web/`, `scripts/test-web.sh`, `docs/agent-notes/web.md`) |
| `ea48027` | Hosting block in `firebase/firebase.json` (+ test), `TRUSTED_PROXY_HOPS` parameter, API.md and README updates |
| `c7866f3` | `scripts/e2e-local.sh`, the `e2e-local` web build, the Playwright story, seed extensions |
| (next) | Lighthouse CI (`web/lighthouserc.json`, `web/scripts/lighthouse.ts`, `npm run lighthouse`, step in `test-web.sh`) and these notes |

## 2. Results (2026-10-09, this machine: Node 26, Java 21, firebase-tools 15.32.1)

| Check | Result |
|---|---|
| `scripts/test-firebase.sh` (all) on the merged tree | green: lint 0, types ok, audit 0, **739** unit, **65** rules, **258** use cases, **17** transport |
| `scripts/test-web.sh full` on the merged tree | green: lint, types, i18n, contrast, privacy, **219 passed + 2 skipped** unit, build in budget, Playwright **175 passed, 15 skipped** |
| `scripts/test-firebase.sh static` + `unit` after the Hosting test and the parameter | lint 0, types ok, audit 0, **745** unit (739 + 6 in `hostingConfig.test.ts`) |
| Hosting emulator with the dev `firebase.json` | `/maria` 200 `text/html`; `/m/abc` carries the CSP, HSTS, `Cache-Control: no-store`, `X-Robots-Tag`; `/assets/<hash>.js` 200 `immutable`; `/api/<name>` is proxied to the function (to the cloud when the Functions emulator is not among the targets, so always start both) |
| `scripts/e2e-local.sh` | **E2E LOCAL SUCCEEDED, 6 passed (18 s)** through Hosting + Functions + Firestore + Auth + Storage emulators |
| `npm run lighthouse` (web) | see section 5 |

## 3. Hosting merge (what changed in `firebase/firebase.json`)

- `hosting.public = ../web/dist` (paths in `firebase.json` are relative to `firebase/`), `predeploy` runs `npm ci` and
  `npm run build` in `web/` (SRI hashes and `/.well-known/bellohub-build.txt` are written by that build). Set the
  `VITE_*` variables of `web/env.d.ts` for the project first (H4, H6).
- `headers`: byte for byte the `**`, `/m/**`, `/p/**`, `/api/**`, `/assets/**`, `/fonts/**`, `/.well-known/**` blocks of
  `web/hosting.json` (strict CSP without `unsafe-*`, HSTS preload, nosniff, DENY, no-referrer, COOP/CORP,
  Permissions-Policy, `no-store` on the token pages and the API, immutable hashed assets).
- `rewrites`: `/api/<name>` for every **public and token** function (the 18 of the fragment plus `getHold`), `/api/getIcs`
  for the HTTP one, all in `europe-west1`; `** -> /index.html` last. Owner functions have **no** rewrite.
- `emulators.hosting.port = 5080` (5000 is macOS AirPlay Receiver).
- `functions/test/unit/hostingConfig.test.ts` fails the unit suite when the headers drift from `web/hosting.json`, when a
  public/token function has no rewrite or an owner function has one, when the catch-all is not last, or when the prod
  target grows a Hosting block. `firebase.prod.json` and `rules/prod/*` are untouched (deny-all).
- API.md section 1 ("Same-origin option") and `firebase/README.md` (deploy step 6, parameters) now describe this.
- CSP decision for the owner (web notes section 7 item 4) is **still open**: Firebase phone sign-in and App Check with
  reCAPTCHA Enterprise need Google origins in `script-src`, `frame-src` and `connect-src`; the shipped policy forbids them
  (this is also why the e2e verifies by email, section 4).

### `trustedProxyHops`

The rate limits key on the client IP, read from the end of `X-Forwarded-For`. It is now the deploy parameter
`TRUSTED_PROXY_HOPS` (`functions/src/config/params.ts`, read in `createDeps`, floor 1), **default 1, unchanged**.
I could not prove the value behind real Hosting rewrites: the Hosting emulator's proxy (`firebase-tools/lib/hosting/proxy.js`)
copies the browser's headers and adds only `X-Forwarded-Host`, so in the emulator a function sees the same header it
would see when called directly. Production Hosting (Fastly/Google front ends) is expected to add one entry before Google's
Functions front end adds its own, hence `2`. **Owner/staging action:** log `X-Forwarded-For` once from one function
behind `/api/<name>` on staging and set `TRUSTED_PROXY_HOPS=2` in `functions/.env.<project>` if the client address is the
second entry from the end. Too low only degrades the limits (they key on the proxy's address); too high lets a client
dodge them with a forged entry, so the default stays conservative.

## 4. `scripts/e2e-local.sh` (S8 exit criterion)

What it does, in order: fake secrets file if missing -> `npm ci` where needed -> Playwright Chromium -> `npm run build`
in `firebase/functions` -> `npm run build:e2e-local` in `web/` (new mode, `web/.env.e2e-local`: `/api`, the **production**
phone verifier, App Check off, no mock) -> writes `firebase/firebase.e2e.json` from `firebase.json` (git-ignored, removed
on exit) with a free port block (default base 25000: hosting 25080, functions 25001, firestore 25002, auth 25003, storage
25004, pubsub 25005, hub 25006, logging 25007; `E2E_LOCAL_PORT_BASE` moves it; a busy block skips to the next, never
touching other processes) and `hosting.public = ../web/dist-e2e-local` -> `firebase emulators:exec --only
hosting,functions,firestore,auth,storage` running: the seed, then `npx playwright test -c playwright.e2e-local.config.ts`.
Prints only failures and `** E2E LOCAL SUCCEEDED/FAILED **`; the full log is `build/logs/e2e-local-<stamp>.log`.

Seed (`firebase/functions/scripts/seed.ts`, through the owner API with a custom-token sign-in on the Auth emulator):
`ensureAccount`, `claimSlug maria`, `publishProfile` with Maria's page **and the same six-question health form the web mock
publishes** (so the browser answers the same questions against the real functions), `publishAvailability`, and, when
`SEED_DEVICE_TOKEN` (20+ chars) is set, `registerDevice` so the emulator push sender records every push in `emulatorOutbox`.

The story (`web/test/e2e-local/booking.spec.ts`, one worker, serial, Pixel 7 profile, zone America/Sao_Paulo):
1. `/maria` renders from `getPublicPage` through `/api`; no booking exists.
2. Helena picks the first service, a day at least two days ahead (the helper moves the calendar when needed), the first
   free time (`holdSlot`), fills name/phone/email, presses "send code" (the SMS path fails in the browser, see below),
   switches to the email code, types `123456`, answers Bk-7 and confirms. Assertions: one `createBooking` with
   `verification.method = "email"`, the token never in any URL, the Firestore booking `confirmed` with the chosen
   `startsAt`, the client (`+5511987654321`, email), a `push` of kind `booking` for that id, >= 2 counted emails.
3. From `/m/<token>` she moves it to another time of the same day: `rescheduleBooking` (direct), no `requestReschedule`,
   `rescheduleCount 1`, new `startsAt`.
4. `/m/<token>/form`: latex, medication yes, pregnant no, skin no, isotretinoin no, a secret free text, typed signature,
   consent. Exactly one `submitSealed`, the envelope has the seven fields of docs/06 section 3.3, the secret and "latex"
   appear in **no** request body or URL, `inbox/demo-maria/items` has one item (`kind intake`, same `keyId`, `itemId`
   and `ct`, no secret in the stored document), a `push` of kind `mailbox` for the item id, `intakeSubmittedAt` set.
5. She cancels with a reason, no late warning; `cancelledByClient` + `cancelledBy: client`; the link now shows "cancelled".
6. The outbox holds push kinds exactly `booking` and `mailbox`, >= 2 emails, and no address or `@` anywhere.

A guard on every test fails it on any request that leaves the page origin, any CSP violation, any uncaught error, any
cookie, and any storage key other than `bh.lang` / `bh.draft.*`. Stored state is read through the Firestore emulator's REST
API with the `Bearer owner` token (`support.ts`), which no real project accepts.

**Web client vs real functions:** no disagreement surfaced on the exercised paths (page, slots, hold, email code,
createBooking, getBooking, rescheduleBooking, getFormContext, submitSealed, cancelBooking); the web client needed no change.
Two things the story could not cover:
- **SMS in the browser**: the production verifier runs Firebase Auth in the page; the shipped CSP (`connect-src 'self'`)
  blocks the Auth emulator origin exactly as it would block `identitytoolkit.googleapis.com` in production. The booking
  therefore verifies by email. This is the open CSP decision (section 7, item 1); once decided, add a second project with
  the looser policy and `VITE_FIREBASE_CONFIG` + `VITE_AUTH_EMULATOR_URL` to exercise `signInWithPhoneNumber` against the
  Auth emulator (the backend transport tests already drive that flow headlessly).
- The `firebase`-mode SMS failure shows the page's "unavailable" error before the client taps "use email"; that is the
  real behaviour of a build without Firebase config, not a bug.

Findings while making it run: `registerDevice` requires a token of 20+ characters; the Firestore REST API prints
timestamps without milliseconds (the helper normalises); the calendar's days are `aria-disabled` until the month's slots
arrive (the helper waits for an enabled day). The Playwright run and the Firestore emulator are quick; the Functions
emulator's first call per function (~4 s each) dominates the 18 s.

## 5. Lighthouse CI

`web/lighthouserc.json`: 3 runs, mobile form factor (Lighthouse's default device), assertions `categories:performance`
>= **0.9** and `categories:accessibility` >= **0.95** (median of the runs, errors), best-practices >= 0.9 as a warning,
SEO off; `uses-http2`, `is-on-https`, `redirects-http`, `canonical` are skipped (the mock is plain HTTP on localhost).
Reports land in `web/.lighthouseci/reports/` (git-ignored).

`npm run lighthouse` (`web/scripts/lighthouse.ts`): serves `dist-e2e` through the mock on a free port (production headers,
gzip), seeds one booking, runs `lhci autorun` on `/maria` and `/m/<token>`. Chrome: `CHROME_PATH`, else Playwright's
Chromium, else `/Applications/Google Chrome.app`. **When no Chrome is found it prints the command for the owner and exits
0** (`LIGHTHOUSE_REQUIRED=1` makes that an error). `scripts/test-web.sh full` runs it after Playwright (`LIGHTHOUSE=0` skips).

**Deviation from the plan ("`@lhci/cli` dev dependency"):** `@lhci/cli@0.15.1` is run through `npx --yes @lhci/cli@0.15.1`
(pinned, cached by npm after the first download) and is **not** in `web/package.json`. Installing it added 7 high `npm
audit` findings (`extract-zip`, `tmp`, `puppeteer-core` chain) with no fixed release of `extract-zip`, which would make the
audit of the page that seals health data permanently red (docs/06 section 6). If the owner prefers the dependency anyway,
`npm i -D --save-exact @lhci/cli@0.15.1` plus `"overrides": {"basic-ftp": "6.2.2", "tmp": "0.2.7"}` leaves only the
`extract-zip` findings.

Result on this machine (Playwright's Chromium 1248, Lighthouse 12.6.1, 3 runs each): `/maria` performance **0.99**
(all three runs), accessibility **1.0**, best practices 1.0, SEO 0.9; `/m/<token>` performance **0.99**, accessibility
**1.0**, best practices 1.0, SEO 0.5 (the page is `noindex` by design; SEO is off in the assertions). "All results
processed", exit 0; reports in `web/.lighthouseci/reports/`. A single cold run earlier scored 0.90 (TBT 400 ms), so
the 0.9 threshold can flicker on a loaded laptop; the median of three is what is asserted.

Two things that cost time, for the next agent: `preset: "mobile"` is not a Lighthouse CLI value (mobile is the default;
the config sets `formFactor` only); and the runner must `spawn` lhci asynchronously, because the mock serves from the
same process and a `spawnSync` blocks the event loop (Lighthouse then reports `NO_FCP` after protocol timeouts).

## 6. Remaining work (not done here)

1. The iOS half of S8 (backend notes section 4 item 2): `RemoteBookingRepository`, `MailboxService`, outbound queue,
   `FirebaseAuthProvider`, FCM; the push `loc-key` strings; `busy` publishing; `appAccountToken`.
2. A second e2e project with the looser CSP for the browser SMS path (after decision 7.1), and a waitlist-offer and portal
   leg of the story (`getHold` and `getPortal` are rewritten but not walked).
3. `TRUSTED_PROXY_HOPS` on staging (section 3). `ENFORCE_APP_CHECK` stays off; App Check enforcement was never enabled.
4. `docs/PROGRESS.md` and `docs/14-HUMAN-TASKS.md` entries for the items of both notes (not edited by this agent, as instructed).
5. `DESIGN.md`: the web notes' Reduce Motion remark (section 9 item 7 of web.md) is still unrecorded.
6. Smaller: the Lighthouse step adds ~1-2 min to `test-web.sh full`; `scripts/e2e-local.sh` does not take the Playwright
   lock of `test-web.sh` (different ports, so they may run together); `firebase.e2e.json` generation duplicates nothing
   (it is derived from `firebase.json` at run time).

## 7. Owner decisions still open (kept from both notes, none decided here)

From `web.md` section 9 and section 7 item 4:
1. **CSP variant for phone sign-in / App Check** (reCAPTCHA Enterprise and Firebase Auth load Google scripts, frames and
   endpoints the strict policy forbids): a looser CSP on the booking paths while the sealed paths keep the strict one, or
   SMS through the API only. Until decided the browser SMS path is untested end to end (section 4).
2. **First-visit answers (Bk-7)**: the page asks "how did you hear" and "been before" but the server stores only `note`.
   Send them sealed, drop them, or add them to `createBooking`?
3. **Guest names (Bk-5)**: the page collects one name per guest; the server stores a count. Drop the fields, or send
   them sealed with the intake?
4. **Consent texts**: hers (`getFormContext.consent`, needs a plain-text layout) or the embedded drafts (`src/legal`,
   then `publishProfile.intake.consent` is unused)? The e2e seed publishes hers; the page still shows its own.
5. **"Counts as a missed appointment"**: publish `lateCancelCounts` on the booking policy, or accept the page's always-warn
   wording after the free window.
6. **Google Calendar link**: the event description carries the personal link (the token goes to Google by the client's
   own tap). Keep, or leave the link out of the Google variant?
7. **Portal and the sealed pages**: `getFormContext`/`submitSealed` accept a manage link only, so the portal cannot reach
   the form, the check-in or the data request. Fine for v1, or accept a portal token?
8. **Reduce Motion in `DESIGN.md`**: chips, buttons and options now fade only under `no-preference`; record it.

From `backend.md` sections 4-6:
9. **D42 specifics** (a confirmed booking from a new phone registers it at once; a pending request counts only on
   approval; deleting a client never lowers the counter; `deleteAccount` deletes the ledger): confirm as ASSUMPTIONs.
10. **Total booking time** = service + add-ons + guests x service minutes (guests take the same service, no add-ons):
    check against iOS `NewAppointment`.
11. **Pseudonymous `contacts` rows** (HMAC of the phone: no-show marks, stopped flag, last form date) live until the
    professional deletes the client or the account: one sentence in the privacy policy (`legal/README.md` fact 5).
12. **`respondBookingRequest` has no free-text reply** (a reply by email could carry clinical content): keep it that way?
13. **Retired inbox keys** are still accepted for new envelopes (the app keeps old private keys): add a drop-keys path to
    `updateInboxKey` after a compromise-driven rotation?
14. **App Check**: enforcement is a runtime parameter (`ENFORCE_APP_CHECK`, default off), `consumeAppCheckToken` replay
    protection unused; enable only after staging (H5), by a human.
15. **Email texts** in 12 languages are unreviewed (D41); **Resend** account (EU, DPA) and `EMAIL_FROM` + `EMAIL_API_KEY`
    (H7); **Apple root certs** + `APPLE_ENVIRONMENT`/`APPLE_APP_ID` (H14); **WhatsApp** token and template approval (H13);
    dev/staging projects, `PHONE_HASH_PEPPER`, SMS allow-list, APNs key, budgets, PITR, Firestore TTL, Storage lifecycle (H4).
16. **Hosting site id** must start with `bellohub` or `bello-hub` (CORS allow-list) if the page ever calls the functions
    cross-origin; with the rewrites of section 3 it does not need to, but the id choice is the owner's (H6).

From `web.md` section 8 (human tasks): H8 real-iPhone checks (in-app browsers, the WebKit `<select>` console line,
camera/library in the check-in, `.ics`, clipboard, Low Power Mode, private mode), H6 domain + HSTS preload + operator
details for `BELLO_STRICT_LEGAL=1`, H4 web config and App Check site key.

## 8. Commands

```
scripts/test-firebase.sh                 server: lint, types, build, audit, unit, rules + use cases, transport (~7 min)
scripts/test-web.sh full                 web: lint, types, i18n, contrast, privacy, unit, build, Playwright, Lighthouse (LIGHTHOUSE=0 skips)
scripts/e2e-local.sh                     the story against the real functions (~2 min incl. builds; E2E_LOCAL_PORT_BASE picks ports)
cd web && npm run lighthouse             Lighthouse CI alone (needs dist-e2e: npm run build:e2e; CHROME_PATH optional)
cd web && npx playwright test -c playwright.e2e-local.config.ts     the story alone, with the emulators running and seeded
cd firebase && firebase emulators:start --project demo-bellohub      dev emulators incl. Hosting on 5080 (serves web/dist)
```
