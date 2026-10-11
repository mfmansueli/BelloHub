# First prompt for Claude Code

Paste everything below the line into Claude Code, opened in the root of the `BelloHub` repository after this folder's contents were copied in and committed.

---

You are going to build **Bello Hub** end to end in this repository, on your own, from the current scaffold to a TestFlight-ready v1. Everything you need is in this repository.

**Already provisioned (do not recreate, do not ask; verify in S0 and record what you find in `docs/PROGRESS.md`):**
- This Mac with Xcode 27 and the tools you need; the Apple Developer account and signing in Xcode (team `X5392U638Q`); the CloudKit container; the Firebase projects (`dev`, `staging`, `prod`) with billing, Authentication, APNs key and App Check already set up, and the Firebase CLI logged in.
- Apple identifiers (decision D38): bundle id `com.bellohub` (tests `com.bellohub.BelloHubTests`, `com.bellohub.BelloHubUITests`), iCloud container `iCloud.com.bellohub`. Create the entitlements file and enable iCloud (CloudKit), Push and App Attest through the project and entitlements; build with `-allowProvisioningUpdates` so Xcode registers whatever is missing.
- Firebase: run `firebase projects:list` and read `.firebaserc`; use the existing projects and put each `GoogleService-Info.plist` where `docs/11-BACKEND-FIREBASE.md` says.

**Not provisioned yet, and yours to do in S0:** the Firestore database. The region is decided (D29) and cannot change: Firestore multi-region **`eur3`**, Cloud Functions **`europe-west1`**, Storage in the **EU** location, in all three projects. Create the `(default)` Firestore database in `eur3` in each project (if one already exists, read its location; if it is not `eur3`, state that as a hard question at the top of `PROGRESS.md`). Version `firebase.json`, `.firebaserc`, `firestore.rules`, `firestore.indexes.json` and `storage.rules` in the repository, starting with deny-all rules, then build the real rules and indexes in S8 as `docs/11-BACKEND-FIREBASE.md` describes. Do not build multi-database support; keep the region in configuration and keep `dataRegion` on the account (D29).

If something else turns out not to be provisioned, do what you can through the CLI or Xcode; if you cannot, build against the fake or emulator, add exact steps to `docs/14-HUMAN-TASKS.md`, mark the spot `TODO(HUMAN-Hn)` and continue. Never block a stage on it.

**Read now, in this order, completely:**
1. `CLAUDE.md` (the architecture constitution; it stays authoritative for code and process).
2. `docs/00-START-HERE.md` (your operating contract: autonomy, hard stops, the stage loop, git workflow).
3. `docs/01-PRODUCT.md`, `docs/02-DECISIONS.md`, `docs/03-BUILD-PLAN.md`.
4. `docs/04-ARCHITECTURE.md`, `docs/05-DATA-MODEL.md`, `docs/06-PRIVACY-SECURITY.md` (read this one twice).
5. `docs/07-LOCALIZATION.md`, `docs/16-MARKETS.md`, `docs/08-DESIGN-SYSTEM.md`, `docs/09-MOTION.md`.
6. `docs/10-WEB-BOOKING.md`, `docs/11-BACKEND-FIREBASE.md`, `docs/12-AI-AND-VOICE.md`.
7. `docs/13-TESTING-QUALITY.md`, `docs/14-HUMAN-TASKS.md`, `docs/15-PROGRESS-TEMPLATE.md`.
8. `docs/screens/SCREENS.md` and `docs/screens/INDEX.md`; for each screen open its entry in `docs/screens/HANDOFF.md` and the matching image in `design/screenshots/` as you reach it. `design/PROTOTYPE-NOTES.md` explains the prototype files. Never edit `design/`.

**Then work, without stopping between stages:**
- Do **S0** now: preflight (`docs/00-START-HERE.md` §5), branch `build/v1`, apply `repo-patch/CLAUDE.md.edits.md` (iPhone only, bundle ids `com.bellohub*`, languages, folders, `.gitignore`), the Firebase provisioning check and Firestore creation above, and copy `docs/15-PROGRESS-TEMPLATE.md` to `docs/PROGRESS.md`. Then **S1 through S12** in order, following the stage loop in `docs/00-START-HERE.md` §3. A stage ends only when its exit criteria hold, `scripts/test.sh fast` and `smoke` pass, and `scripts/check-warnings.sh` and `scripts/check-project-settings.sh` report zero warnings. Commit, tag `stage-S<n>`, push `build/v1`, and start the next stage immediately. Open a pull request into `main` at the end of each phase; never push to `main` directly and never force-push.
- **Decide, don't wait:** every decision is in `docs/02-DECISIONS.md` (D1 to D39). For anything missing, choose what best serves the non-negotiables, log `ASSUMPTION-n` in `docs/PROGRESS.md` and continue.
- **Firebase safety:** deploy functions, hosting and real rules to `dev` and `staging` only. In `prod`, create the empty database and deploy the deny-all rules, nothing else. Never turn on App Check enforcement, never run destructive commands against existing data, never publish anything to the App Store or open any market. Use the emulators for all tests.
- **Hard stops, and only these:** no Xcode able to build Swift; a change that would put clinical data anywhere but the iPhone vault or the sealed mailbox; a change that would add a financial feature; a missing secret that has no safe stub. State the question at the top of `docs/PROGRESS.md`, then keep working on everything that does not depend on it.
- **Non-negotiables:** no financial operations; iPhone only for the professional, any device for her clients through the web app; clinical data private by construction (vault on the iPhone and iCloud, sealed mailbox for client input, on-device AI with mandatory review); ten languages in fourteen localizations (`pt-BR`, `pt-PT`, `es-MX`, `es-419`, `es`, `en`, `en-GB`, `it`, `fr`, `de`, `tr`, `id`, `hi`, `ar` with right-to-left) in every change; warm palette, Fraunces + DM Sans, one motion language, Reduce Motion respected.
- **Markets:** **Brazil and Europe are the two top priorities and open together (wave 1)**: Brazil, Portugal, Spain, Italy, France, Germany/Austria/Switzerland, United Kingdom, Ireland (D36, `docs/16-MARKETS.md`). `pt-BR` is the reference voice, and the wave 1 European languages (`pt-PT`, `es`, `it`, `fr`, `de`, `en`, `en-GB`) get the same care and the same completeness checks. Everything else is built now and opened later. Track readiness in the "Market readiness" table of `docs/PROGRESS.md`.
- Things only a person can do remain (real-device checks, native reading of the languages, legal review, App Store Connect, opening markets). List them in `docs/14-HUMAN-TASKS.md` as you reach them and keep going.
- Everything you write is in English (code, comments, commits, docs). Keep `docs/PROGRESS.md` current: it is your memory after a context reset and the report the owners read.

Start by replying with a short plan for S0 and S1, then begin.
