# firebase/: the server (stage S8)

Operational data for booking, the sealed mailbox, push, plan mirroring and deletion (`docs/11-BACKEND-FIREBASE.md`). It
**never holds clinical data**: a client's health form is encrypted in her browser with the professional's public key and
stored here as an opaque envelope for at most 30 days (`docs/06-PRIVACY-SECURITY.md`). The contract the web app and the
iPhone code against is [`functions/API.md`](functions/API.md).

```
firebase/
  firebase.json            dev target: real rules, functions, Hosting (web/dist + /api rewrites), emulators on the default ports
  firebase.test.json       the same on other ports, used by scripts/test-firebase.sh (parallel sessions never collide)
  firebase.prod.json       the ONLY config that may touch the existing project `bello-hub`: deny-all rules, nothing else
  .firebaserc              default = demo-bellohub (cannot reach the cloud); `bello-hub-deny-all` is an explicit alias
  firestore.rules          the real rules (dev target)            storage.rules   deny all, permanently
  firestore.indexes.json   the one composite index + the TTL policies (D30)
  storage-lifecycle.json   delete sealed-envelope objects after 31 days (a backstop to the cleanup job)
  rules/prod/              deny-all Firestore and Storage rules + empty indexes (what `bello-hub` has today)
  config/<env>.json        regions: FUNCTIONS_REGION europe-west1, DATA_REGION eu, Firestore eur3 (D29)
  functions/               TypeScript, Node 22, ESM, Cloud Functions 2nd gen (see functions/README.md)
  scripts/                 rules-fixtures/ (Swift oracle), sms-regions.mjs
```

## Safety rules of this folder

1. **Nothing here is ever deployed by an agent.** The existing project `bello-hub` keeps deny-all rules and an empty
   database until a human creates dev and staging (H4, ASSUMPTION-1). A bare `firebase deploy` fails on purpose: the default
   project is `demo-bellohub`.
2. **All tests run on local emulators** with the project id `demo-bellohub`. A `demo-` id never reaches the cloud.
3. **No personal data in logs**, generic errors to clients, secrets only through parameters and Secret Manager, no analytics.

## Requirements

Node 22 (local runs also work on newer Node; the functions declare `"engines": {"node": "22"}`), Java 17+ (the Firestore
emulator), `firebase-tools` 15, and network access for `npm ci` the first time.

## Run the tests

```
scripts/test-firebase.sh              everything: lint, types, build, audit, unit, rules + use cases, Functions emulator
scripts/test-firebase.sh unit         pure rules and contracts only (seconds, no emulator)
scripts/test-firebase.sh emulator     Firestore rules and every use case on the Firestore/Auth/Storage emulators
scripts/test-firebase.sh transport    the deployed entry points through the Functions emulator
RUN_FIREBASE=1 scripts/test.sh fast   the iOS fast plan plus the server suites (opt in; adds a few minutes)
```

It prints only failures and the result; full logs are in `build/logs/firebase-*.log`.

## Run the emulators for the web or iOS work

See "Local development" in `functions/API.md`: `cd firebase/functions && npm ci && npm run build`, then
`cd .. && firebase emulators:start --project demo-bellohub`, then `npm run seed` for the demo professional.

## How a human deploys to dev and staging later (H4)

Not done by Claude Code: it needs accounts, billing and keys that only the owners have (`docs/14-HUMAN-TASKS.md`).

1. Create the projects `bellohub-dev` and `bellohub-staging` (Blaze plan) in the same Google account; create Firestore
   `(default)` in **`eur3`** and the default Storage bucket in the **EU** location in each.
2. Add them to `firebase/.firebaserc`:
   `{ "projects": { "default": "demo-bellohub", "dev": "bellohub-dev", "staging": "bellohub-staging", "bello-hub-deny-all": "bello-hub" } }`.
3. In each project: Authentication > Phone on, SMS region policy **allow-list** = the output of
   `node firebase/scripts/sms-regions.mjs` (D37), an SMS budget alert; upload the APNs auth key (Cloud Messaging); add the iOS
   app and download its `GoogleService-Info.plist` into `Config/Firebase/<Env>/`.
4. Secret Manager: `firebase functions:secrets:set PHONE_HASH_PEPPER` (a long random value; never rotate it, every stored
   contact is keyed by it) and `firebase functions:secrets:set EMAIL_API_KEY` (the Resend API key, H7; any placeholder
   until the account exists: the key is only read when `EMAIL_FROM` is set) and `firebase functions:secrets:set
   APPLE_SIGNIN_PRIVATE_KEY` (the `.p8` of a Sign in with Apple key, H17, pasted as PEM; any placeholder until the key
   exists: it is only read when `APPLE_SIGNIN_KEY_ID` is set). Later: the Meta token (H13).
5. Optional deploy parameters in `functions/.env.<project>`: `WEB_BASE_URL`, `WHATSAPP_AUTOMATION` (keep equal to the Remote
   Config flag), `ENFORCE_APP_CHECK` (only after App Check works on staging, H5), `PLAN_PRODUCT_IDS`, `EMAIL_FROM`
   (`Bello Hub <no-reply@bellohub.app>`, a sender verified at the vendor; empty keeps email off, H7), `APPLE_ENVIRONMENT`
   and `APPLE_APP_ID` (H14, see `functions/certs/apple/README.md`), `APPLE_SIGNIN_KEY_ID` (H17: the id of the Sign in
   with Apple key whose `.p8` is the secret above; empty keeps `deleteAccount.appleRevocation` at `skipped`), `TRUSTED_PROXY_HOPS` (default 1; behind the Hosting
   rewrites of `/api/<name>` the client IP is probably the second entry from the end of `X-Forwarded-For`, so log that
   header once on staging and set `2` if so; the Hosting emulator adds no entry, so no local test can decide it).
6. Deploy to **dev first** (never to `bello-hub`):
   `cd firebase && firebase deploy --project dev --only firestore:rules,firestore:indexes,storage,functions,hosting`.
   The `hosting` target builds `web/` first (its `predeploy` runs `npm ci` and `npm run build` in `web/`, which also writes
   the SRI hashes and `/.well-known/bellohub-build.txt`); set the `VITE_*` build variables of `web/env.d.ts` for the
   project before deploying (H4, H6). The Hosting site id must start with `bellohub` or `bello-hub` (the CORS allow-list);
   the page calls the functions through the `/api/<name>` rewrites, so its CSP stays `connect-src 'self'`.
   Then run `scripts/test-firebase.sh` locally once more and smoke test the dev project with the seed data of a throwaway
   professional. Staging is the same with `--project staging`.
7. TTL policies come with the indexes file (`ttl: true`). If the CLI rejects that key, enable them in the console: Firestore >
   Time-to-live, collection groups `items`, `holds`, `emailCodes`, `emailProofs`, `rate`, `idempotency`, `audit`, `waitlist`,
   `portal`, field `expiresAt`. The `cleanupJob` deletes the same documents anyway, so a missing policy never breaks a promise.
8. Storage backstop: `gcloud storage buckets update gs://<bucket> --lifecycle-file=firebase/storage-lifecycle.json`.
9. Budget alerts and a monthly cap; PITR with the shortest window and a note in the privacy policy about backups (docs/06 section 7).
10. Production: only when everything above passed on staging. Until then `firebase deploy --config firebase.prod.json --project
    bello-hub-deny-all --only firestore,storage` is the only command that may touch `bello-hub`, and it can only deploy deny-all rules.

## What the humans still owe (see docs/agent-notes/backend.md)

H4 projects and keys, H5 App Check, H6 domain and Hosting, H7 email provider (`ResendEmailProvider` is wired: create the
Resend account in the EU region, sign its DPA, verify the sender domain, then set `EMAIL_FROM` and the `EMAIL_API_KEY`
secret), H13 WhatsApp
Business (code and tests exist, disabled), H14 App Store plan verification (`AppleAppStoreVerifier` is wired; it switches
on when Apple's root certificates are in `functions/certs/apple/`, see the README there, plus `APPLE_ENVIRONMENT` and
`APPLE_APP_ID` for Production; until then it answers `NOT_CONFIGURED`), H17 Sign in with Apple revocation on account
deletion (`AppleSignInTokenRevoker` is wired, D44: Certificates, Identifiers & Profiles > Keys > create a key with
"Sign in with Apple" for the `com.bellohub` App ID, note its Key ID, download the `.p8` once; set `APPLE_SIGNIN_KEY_ID` and
the `APPLE_SIGNIN_PRIVATE_KEY` secret; until then `deleteAccount` reports `appleRevocation: "skipped"`).
