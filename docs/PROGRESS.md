# PROGRESS

This file is the memory across context resets. Read it first in every session; update it at the end of every stage and whenever something notable happens. Humans read it to see what happened while they were away.

## Open questions for humans (top = most urgent)
Nothing here blocks the build; each item has a safe default in use.

1. **Only one Firebase project exists, not three; the owner decided (D43) that `bello-hub` is the dev environment.** **Done by the owner on 2026-10-08:** Blaze billing linked, default Storage bucket created (EU location, production-mode rules), Auth Phone provider enabled with the SMS region allow-list for the ten wave-1 countries (BR, PT, ES, IT, FR, DE, AT, CH, GB, IE), budget alert created, APNs authentication key uploaded to Firebase Cloud Messaging (the owner reported it; a real push test waits for the S8 iOS integration). **Still open (not blocking):** the Cloud Functions API turns on at the first deploy, later a custom domain (the site is served at `bello-hub.web.app` meanwhile), an email-provider key, and a separate `prod` project before launch. Original note: **Only one Firebase project exists, not three.** `firebase projects:list` (logged in as the owner's account) shows a single project, `bello-hub` (number 73917800030), with one iOS app (`com.bellohub`). The brief expects `dev`, `staging` and `prod`. What I did: created the `(default)` Firestore database in `eur3` in `bello-hub` and deployed deny-all rules there, nothing else, because I cannot tell which environment it is meant to be. What I need: either create `dev` and `staging` (H4) or tell me `bello-hub` is dev. Until then every backend test runs on the emulators and nothing but deny-all rules is deployed (ASSUMPTION-1).
2. **Default Storage bucket: created by the owner on 2026-10-08.** (Was: not created.) Needs the Firebase console (Blaze plan) or `gcloud`, which is not installed on this Mac. `storage.rules` is committed (deny all). H4.
3. **Crashlytics removed (FYI, ASSUMPTION-2).** `docs/04-ARCHITECTURE.md` section 8 says no Analytics and no Crashlytics in v1, so I removed the Crashlytics product, its dSYM build phase, the crash-policy code and tests, and the README section the scaffold had. If Mateus wants crash reports, the proposal is MetricKit (S12) rather than a third-party SDK that can carry log text.
4. **`gh` is not logged in** and `origin` is `git@github.com:mfmansueli/BelloHub.git`. Pushing branches works only if this Mac's SSH key has access; opening pull requests needs `gh auth login` (H17).

## Owner decisions made during the build
| Date | Decision | Effect on the work |
|---|---|---|
| 2026-10-08 | **D40 Go-to-market:** open every market possible, formalize legal matters only after real sales appear; no gate on native reading or legal review. | Claude Code writes the legal documents of every market now (plan item L below). The market table below is information; the owner opens markets in App Store Connect. |
| 2026-10-08 | **D41 Languages:** no human review is planned; Claude Code does its best. | Every string stays `needs_review` (true, and not a gate). The S11 completeness checks stay; the "awaiting reviewers" list is simply every non-English string. |
| 2026-10-08 | **D42 Monetization:** first 10 client registrations free (cumulative; deleting never restores a slot; across manual, import and booking; duplicates and edits do not count), paywall on the 11th, existing data always accessible, counter at account level; one paid plan, monthly or yearly (EUR 14.99 / 149.99, USD 14.99 / 149.99, BRL 39.90 / 399.90), same features, **no 14-day trial** (D33 revised). | S2 builds `RegistrationQuota`, `PlanSavings` and the vault ledger; S4 the registration gate and the limit message; S8 the server counter and the booking branch; S10 the plan screen and the paywall with StoreKit. |
| 2026-10-08 | **D43 Environment:** the owner said `bello-hub` may be used as the **development** environment ("the project is still in development, errors in production do not matter at this stage"): real rules, functions and hosting may be deployed to it. | Supersedes the deploy limits of ASSUMPTION-1 for `bello-hub` only. Still in force: never turn on App Check enforcement, never run destructive commands against existing data, never publish to the App Store or open a market. A real `prod` project must be created and kept deny-all before launch (human task H4). Cloud Functions need the Blaze plan: the owner links billing in the console. |
| 2026-10-09 | **D44 to D52:** Sign in with Apple is the main sign-in of the professional (phone as alternative); no first-visit questions on the booking page (she asks in the app); policies apply from the moment of booking and the app and web say so; e-mail-code verification on the web with the strict CSP; guests as a count; the consent text comes from the server; no manage token in third-party URLs; retired inbox keys stop after 24 h (at once on compromise); forms are reached from the booking link. | Work launched on 2026-10-09: sign-in with Apple (iOS), web and backend alignment (see "Current stage"). `docs/02-DECISIONS.md` has the full text. |
| 2026-10-10 | **D56 Smart slots** (owner's request "se a profissional tem serviços com tempos variados… fazer melhor", spec `docs/tasks/smart-slots.md`): anchored start times, per-service prep/clean-up/processing time, a slot interval setting and "Keep my day compact" with an honest fallback. | Built on `build/v1` after S9 (notes `docs/agent-notes/smart-slots.md`); deployed to dev. |

**Plan item L (legal drafting pass), right after S2, done 2026-10-08 (98 drafts, see the stage log):** for every market, the terms and data processing agreement, privacy policy, client notice, health-form consent, photo consent, guardian consent and data-subject-request wording, written as carefully as possible in the language of each region set (`docs/07-LOCALIZATION.md` section 8), versioned under `legal/<doc>/<localization>/<version>.md`, with `legal/STATUS.md` and `scripts/check-legal-status.sh`. Refined in S11 once the screens that show them exist. Marked `LEGAL-REVIEW` in the headers, never claiming compliance (`docs/06` section 12).

## Risk register (what opening before legal review leaves open; owner accepted under D40)
| Risk | Where | Mitigation already in the design | Still open |
|---|---|---|---|
| Health data processed without a legal opinion (LGPD art. 11, GDPR art. 9 and equivalents) | All markets | Clinical data never reaches our servers readable (vault, sealed mailbox, on-device AI); the professional is the controller, Bello Hub a processor with a DPA accepted in the app; retention and deletion built in | The texts themselves are unreviewed |
| Apple requirements | All storefronts | Privacy-policy URL and App Privacy answers drafted from `docs/06`; `PrivacyInfo.xcprivacy` in S12 | The policy must be hosted at a public URL (needs the domain, H6) |
| EU trader status for subscriptions | EU storefronts | Instructions in H16 | The owner must declare it in App Store Connect; Apple does not allow skipping it |
| Gulf health-data residency (UAE Federal Law 2/2019, Saudi PDPL) | `SA`, `AE` | No clinical data on servers; only ciphertext in transit for up to 30 days | `healthDataResidency` is `blocking-until-reviewed` in `regions.json`; the owner decides |
| French health-data hosting certification (HDS) | `FR` | Servers cannot read the sealed envelopes | Unconfirmed whether HDS applies |
| German and Austrian legal notice (Impressum) | `DE`, `AT` | An optional "legal notice" text on the public page is planned as a design addition | The professional must fill it in |
| Minors | All | Guardian flow (D17) and per-country wording in the drafts | Age thresholds differ per country |
| WhatsApp automation and SMS | All | Manual-first sending, SMS allow-list (D31, D37) | Meta onboarding (H13) if automation is wanted |

## Market readiness (keep current; mirrors `legal/STATUS.md`)
| Wave | Market | Language(s) | Strings read by a native | Legal texts reviewed | Open in App Store Connect |
|---|---|---|---|---|---|
| 1 | Brazil | pt-BR | no | no | no |
| 1 | Portugal | pt-PT | no | no | no |
| 1 | Spain | es | no | no | no |
| 1 | Italy | it | no | no | no |
| 1 | France | fr | no | no | no |
| 1 | Germany, Austria, Switzerland | de | no | no | no |
| 1 | United Kingdom, Ireland | en-GB | no | no | no |
| 2 | Mexico | es-MX | no | no | no |
| 2 | United States | en | no | no | no |
| 2 | Latin America (AR, CO, CL, PE...) | es-419 | no | no | no |
| 2 | Australia, New Zealand, South Africa | en-GB | no | no | no |
| 3 | India | hi, en-GB | no | no | no |
| 3 | Turkey | tr | no | no | no |
| 3 | Indonesia | id | no | no | no |
| 4 | Saudi Arabia | ar | no | no | no |
| 4 | United Arab Emirates | ar | no | no | no |

Under D40 and D41 the first two columns are not gates: the owner opens markets by his own judgement (H15). They stay `no` because it is true.

### Market readiness by localization (S11, 2026-10-10)
Strings: all 2,232 app keys + 5 permission texts + 401 booking-page keys present, style-checked and `needs_review` (no native reader, D41). Templates: 16 message kinds (`docs/strings/message-templates.json`) and 7 emails. Professions: 9 per catalog, `check-professions.sh` green. Legal: `2026-10-2` drafts of terms+DPA, privacy policy, client notice, data requests (`draft`, not reviewed). Screenshots: `LocalizationScreenshotUITests` (15 key screens per localization, 213 PNGs in `build/screenshots/s11/`, not committed; green on 2026-10-10 in 33 min, plus Arabic mirroring and the double-length pseudolanguage; navigation titles measured by `NavigationTitleFitTests`).

| Localization | Wave | Strings | Templates | Professions | Legal set | Review doc | Screenshots |
|---|---|---|---|---|---|---|---|
| `pt-BR` | 1 | complete, needs native read | 16 + 7 emails | 9 | LGPD set | `docs/review/pt-BR.md` | 15 screens, no clipped text |
| `pt-PT` | 1 | complete, needs native read | 16 + 7 | 9 | GDPR core + PT annex | `docs/review/pt-PT.md` | 15 screens, no clipped text |
| `es` | 1 | complete, needs native read | 16 + 7 | 9 | GDPR core + ES annex | `docs/review/es.md` | 15 screens, no clipped text |
| `it` | 1 | complete, needs native read | 16 + 7 | 9 | GDPR core + IT annex | `docs/review/it.md` | 15 screens, no clipped text |
| `fr` | 1 | complete, needs native read | 16 + 7 | 9 | GDPR core + FR annex | `docs/review/fr.md` | 15 screens, no clipped text |
| `de` | 1 | complete, needs native read | 16 + 7 | 9 | GDPR core + DE annex (AT, CH notes) | `docs/review/de.md` | 15 screens, no clipped text |
| `en-GB` | 1 | derived from en + 34 overrides | 16 + 7 | 9 | GDPR core + UK annex (IE, AU, NZ, ZA notes) | `docs/review/en-GB.md` | 15 screens, no clipped text |
| `en` | 1/2 | source language | 16 + 7 | 9 | US set | `docs/review/en.md` | 15 screens, no clipped text |
| `es-MX` | 2 | complete, needs native read | 16 + 7 | 9 | LFPDPPP set | not yet (wave 2) | 15 screens, no clipped text |
| `es-419` | 2 | derived from es-MX + overrides | 16 + 7 | 9 | Latin America set | not yet | 15 screens, no clipped text |
| `tr` | 3 | complete, needs native read | 16 + 7 | 9 | KVKK set | not yet | 15 screens, no clipped text |
| `id` | 3 | complete, needs native read | 16 + 7 | 9 | PDP set | not yet | 15 screens, no clipped text |
| `hi` | 3 | complete, needs native read | 16 + 7 | 9 | DPDP set | not yet | 15 screens, read by eye (the clipped audit skips Devanagari) |
| `ar` | 4 | complete (six plural forms), needs native read | 16 + 7 | 9 | PDPL set | not yet | 15 screens + mirroring test, read by eye (the clipped audit skips Arabic script) |

## Strings awaiting reviewers
Read by `scripts/check-strings.sh --final` (S11): a `needs_review` string is allowed only in a localization listed here. Under D41 no native reviewer is planned, so every non-English localization stays listed until a human reads it and imports the corrections with `scripts/import-strings.sh <id> <file.csv> --reviewed` (how: `docs/review/README.md`).

`pt-BR` `pt-PT` `es-MX` `es-419` `es` `en-GB` `it` `fr` `de` `tr` `id` `hi` `ar`

## Environment (S0, 2026-10-08)
- Xcode 27.0, build 27A266a (a three-digit build number, which looks like a release build and not a beta; confirm in Xcode > About Xcode. If it is a beta, TestFlight uploads need a release Xcode, H16 item 4).
- iOS runtimes: 18.0, 18.1, 18.2, 18.4, 18.5, 26.5, 27.0. Simulator used by the scripts: iPhone 17 on the oldest iOS 26+ runtime (26.5).
- SwiftLint 0.65.1 · Node v26.11.0 (functions target Node 22 in `engines`; local test runs use the installed Node) · npm 11.20.0 · Firebase CLI 15.32.1 · Java OpenJDK 21.0.12 · git 2.54.0 · gh 2.102.0 (not logged in) · no `gcloud`.
- Signing: team `X5392U638Q`, "Apple Development: IAGO XAVIER DE LIMA". `xcodebuild -allowProvisioningUpdates` for a device build produced the profile "iOS Team Provisioning Profile: com.bellohub" with iCloud/CloudKit (`iCloud.com.bellohub`), Push (`aps-environment`) and App Attest entitlements. H1 is verified done.
- Pinned dependencies: firebase-ios-sdk 13.0.1 (Core, Auth) · hpke-js, preact, vite: not yet · firebase-tools 15.32.1.

## Firebase provisioning (S0)
| Item | State |
|---|---|
| Projects | `bello-hub` only (`dev`, `staging`, `prod` do not exist; see open question 1) |
| Firestore `(default)` | Created in S0 in `bello-hub`, location **eur3** (verified with `firestore:databases:get`), type Firestore Native, PITR disabled, delete protection off |
| Rules deployed | Firestore deny-all and empty indexes. Nothing else (no functions, hosting or Storage) |
| Storage | Not created. `storage.rules` committed. H4 |
| Region config | `firebase/config/{dev,staging,prod}.json`: `FUNCTIONS_REGION=europe-west1`, `DATA_REGION=eu`, `FIRESTORE_LOCATION=eur3`, `STORAGE_LOCATION=EU` |
| iOS plist | `BelloHub/SupportFiles/GoogleService-Info.plist` (project `bello-hub`, bundle `com.bellohub`). Per-environment plists go under `Config/Firebase/<Env>/` once the environments exist (ASSUMPTION-6) |
| Layout | `firebase/` holds `firebase.json`, `.firebaserc`, rules and indexes; run the CLI from `firebase/` (ASSUMPTION-5) |

## Baseline (untouched scaffold, before any S0 edit)
`scripts/test.sh full`: `** TEST SUCCEEDED **`. 9 unit tests in 4 suites (Swift Testing) and 1 UI test (`LaunchUITests`), 0 failures.

## Current stage
**v1 is complete (S12 done 2026-10-11, tags `stage-S12` and `v1.0.0-rc1`).** Every stage S0 to S12 is tagged. What is left is human work only (RESUME HERE, "v1 complete", and `docs/14-HUMAN-TASKS.md`).

**Owner rule 2026-10-09 (later): at most 2 agents at a time, only `model: fable` at `medium` effort** (replaces the 3 sonnet + 1 fable split). Order: s8-publish and s6-home first, then s7-record, s10-account, D55, S8 inbox. Worktree dirs under `.claude/worktrees/`: s6-home = `agent-a9c2564560a1e27e2`, s7-record = `agent-af16371e7560af324`, s8-publish = `agent-ae6aa117cf4712fe2`, s10-account = `agent-a498cf63dedef1f7d`.

**2026-10-09 night:** the booking link WORKS end to end on the owner's iPhone (Debug builds now sign in through Firebase/Apple by default; `-devLogin` keeps the fake login). `s8-publish` is merged. The owner said "continue the production": continue with at most 2 Fable agents at `medium` (weekly usage was at 92%, resets Wednesday 12:00: expect agents to die at the limit; state is always in worktrees and notes). Running: `s10-account` (12 commits, verifying; worktree `agent-a498cf63dedef1f7d`, sim `581B8F64`; remove its `TmpQuietHoursProbeUITests.swift` if still present) and `d55-web-backend`. S6 is tagged. Next when a slot frees: `s7-record` (worktree `agent-af16371e7560af324`, 1 commit + 7 uncommitted), then D55 (web+backend, then iOS), S8 inbox, S9, S11, S12.

### FIRST THING WHEN A SESSION RESUMES (2026-10-09; SUPERSEDED: read RESUME HERE below)
`build/v1` at `87e45ca` or later is the truth: S0 to S5 tagged; S6 (calendar, appointment) and S7 flow merged; fast 1426+, smoke and `check-warnings` zero warnings on the merged tree; installed on both iPhones. Four agents may have died with the limit: `s6-home`, `s7-record`, `s8-publish` (Sonnet) and `s10-account` (Fable). For each: `git -C .claude/worktrees/<agent dir> log --oneline` and `status`, read its `docs/agent-notes/<slice>.md`, and launch a NEW agent (sonnet or fable, effort `medium` at most) pointed at the same worktree and branch with the original brief shortened to "finish, verify, commit"; then merge each branch (conflicts are always the same: `MainView`, `RootView`, `AppDependencies`, `UITestSeeding`, `UISmoke.xctestplan`: keep both sides; regenerate the catalog with `git checkout --ours BelloHub/SupportFiles/Localizable.xcstrings && python3 scripts/merge-strings.py`), run `scripts/test.sh fast`, `smoke`, `scripts/check-warnings.sh`, tag `stage-S6` when "home" is merged. Then queue: S8 "inbox", D55 consent removal (web+backend with Fable now; iOS after S10 merges), wire the S7 Start/Records/Incident/Export rows, add the AI settings row to More, S9 integration, S10 merge, S11, S12. Deployed: backend and web at `https://bello-hub.web.app` (dev); the app does not publish yet (waits for `s8-publish`).

### RESUME HERE (living block: updated at every milestone; a cut of the session costs little if this is current)
**2026-10-11: v1 COMPLETE. S12 done on `build/v1`, tags `stage-S12` and `v1.0.0-rc1` at HEADPLACEHOLDER** (stage log "S12", notes
`docs/agent-notes/s12-release.md`, acceptance `docs/13-TESTING-QUALITY.md` section 8 checked with evidence). Palette
changed to graphite and orange by PR #1 after S11/S12 measurements; contrast and audits re-run on HEADPLACEHOLDER.

**Before the first real client** (full steps: top of `docs/14-HUMAN-TASKS.md`, "Minimum to run v1 in production"):
1. Domain (H6) → `BELLO_WEB_BASE_URL`, store URLs. 2. **E-mail sender, critical (H7)**: Resend EU account, DPA, SPF/DKIM/DMARC at
the registrar, `EMAIL_API_KEY` + `EMAIL_FROM`; without it no client can book (the e-mail code is the only verification,
D46/D57). 3. App Store Connect (H14, H16). 4. Apple root certificates and the App Store Server Notifications URL (H14).
5. Sign in with Apple key (H22). 6. Firebase production project or promotion (H4). 7. Real-iPhone checks (H3, H8, H19).

**Open items, all HUMAN** (H-number in `docs/14-HUMAN-TASKS.md`):
- H1 add Mateus to the Apple team; H2 CloudKit schema to Production; H3 two-iPhone checks (sync, recovery key restore,
  voice matrix when voice ships); H4 `prod` project (or promote `bello-hub`), TTL policies; H5 App Check providers and
  enforcement (not for v1, before scaling); H6 domain; H7 e-mail provider (critical); H8 in-app browser tests;
  H9 Google Calendar (optional); H10 native readers (D41, optional); H11 legal review (after sales, D40);
  H12 fonts (done unless offline); H13 WhatsApp Cloud API (post-v1: the provider is built and tested but **not wired** in
  `createDeps`, which always uses `DisabledWhatsAppProvider`, so automation also needs a small code change: a phone
  number id parameter and an access token secret); H14 App Store Connect, products, privacy labels, root certificates;
  H15 open markets; H16 trader status, seller name, release Xcode; H17 `gh auth login`; H18 breach-plan duties;
  H19 release-candidate checks on a real iPhone (VoiceOver pass, hitches, cold start, Apple Calendar, camera, Face ID);
  H20 phone sign-in decision (v1 shows Apple only); H21 automated WhatsApp and SMS (post-v1, D57: v1 keeps manual
  `wa.me` and the e-mail code; Meta onboarding needs a registered business); H22 Sign in with Apple key.

**2026-10-10 17:45: S12 started on `build/v1` (single agent).** Step 0 done: the `s8-leftovers` merge (`cf9d249`) is green (fast 2179 / 309 suites, check-warnings zero, firebase and web full green) and functions (`suggestBookingTime`) and Hosting are deployed to dev (stage log "S8 leftovers + S12 prep"). Next in S12: calendar past-hour tap, per-client export under Edit, "Created by " on the record-history route, missing `NSCalendarsFullAccessUsageDescription` and the Apple Calendar write-through (the switch promised it, nothing wrote events), audits, performance, security table, final regression, tags `stage-S12` and `v1.0.0-rc1`.

**2026-10-10 17:30: S11 done on `build/v1`, tag `stage-S11`** (stage log "S11", notes `docs/agent-notes/s11-localization.md`, market readiness table above). Green on the head: fast 2095 tests in 295 suites, smoke 48 (47 + 1 skipped tool), screenshots in 14 localizations, all audit suites (S6 to S8 pt-BR/de/hi runs finished), check-warnings zero, web full. Hosting deployed to dev. **Next: S12.** Open from S11: per-client export/delete under Edit (Help and Privacy describe it), a past hour on today's day view did not open New appointment (notes section 5), native readers for every localization (H10/H11).

**2026-10-10 07:45: D56 smart slots done on `build/v1`** (stage log "D56", notes `docs/agent-notes/smart-slots.md`, decision D56). Everything green on the head: iOS fast 2087 tests in 293 suites, smoke 48 (47 passed + 1 skipped tool), check-warnings zero; functions all suites (unit 906, emulator 66 + 286, transport 19); web full green; e2e-local 7 passed. **Functions and Hosting deployed to dev** (page 200, `/api/getSlots` answers). **Next: S11, S12**; S8 leftovers unchanged.

**2026-10-10 06:00: S9 done on `build/v1`, tag `stage-S9`** (stage log "S9", notes `docs/agent-notes/s9-web.md`). Web full green (unit 233, Playwright 191 + 15 skipped, Lighthouse 0.99/1.00 on both pages, initial JS 48.1 KB gzip), e2e-local 6 passed, iOS fast 2056 tests in 288 suites, smoke 45 UI tests passed (+1 skipped tool, 27 min), check-warnings zero warnings. The app now publishes her health form with the page (`profile.intake`). Web deployed to dev Hosting; functions unchanged. **Next: S11, S12**; S8 leftovers (server deletion and subscription swaps, mailbox/push service tests) unchanged.

Last updated 2026-10-10, 01:40, by the single integration agent. **State: `build/v1` is GREEN** with everything merged: `audits-s6-s8`, `s10-account` (incl. its notes commit), `s8-inbox` (all commits up to fff325e, still WIP: services, no screens) and **`d55-ios`**. Measured on the merged head: `scripts/test.sh fast` 2008 tests in 278 suites pass (strings 2142 keys, legal 28 bundled notices, server contract, professions, health forms gates included); `scripts/test.sh smoke` 42 UI tests pass (26 min); `scripts/check-warnings.sh` zero warnings on simulator, device, Release and the test targets (SwiftLint included). Tags `stage-S7`, `stage-S8`, `stage-S10` on that head. **D55 backend and web are DEPLOYED to dev** (2026-10-10: all functions updated, Hosting released; `/api/getPublicPage` NOT_FOUND for an unknown slug, page 200). Rules: owner wants v1 finished end to end; commit before every long build or test ([[feedback-commit-before-tests]]); one xcodebuild at a time.

| Work | Branch | State |
|---|---|---|
| S10 account | `s10-account` | Merged and green; notes `docs/agent-notes/s10-account.md`; DESIGN.md updated |
| D55 iOS | `d55-ios` | Merged (7b8d10d) and green. Resolution: a minimal legal reader stays for `LegalNotice` only (terms + privacy policy): `Models/Legal/{LegalFileName,LegalTextRenderer,LegalTextValues}`, `Managers/Legal/{LegalTextError,LegalTextRenderer+Build,LegalNoticeLibrary,BundleLegalNoticeLibrary}`; `scripts/sync-legal-resources.py` bundles only `terms-dpa` and `privacy-policy` (28 files), `check-legal-resources.sh` stays in `test.sh`; `merge-strings.py` = build/v1's version + D55's `--prune` (run `python3 scripts/merge-strings.py --prune` after deleting keys from a batch); `MailboxService` no longer passes the removed `HealthForm` signature/guardian fields |
| D55 web + backend | merged (`573a50f`) | **Deployed to dev 2026-10-10** |
| S8 inbox | `s8-inbox` merged; screens built on `build/v1` | Services (models, server reads, mailbox opening and import into 4.5, outbound queue, push wiring, UI-test inbox server `-uiInbox fixtures` or `paywall`, built through `InboxServices`) **and screens 2.9 Waitlist, 2.10 BookingRequest, 2.11 RescheduleRequest** (`Screens/Inbox/`, cards at the top of Alerts, `AgendaRoute.bookingRequest/rescheduleRequest/waitlist`), strings `s8-inbox.json`, 30 unit tests (`WaitlistBoard`, `InboxRequestPhase`, `RescheduleTiming`, `InboxAlerts`, three ViewModels over `FakeInboxRepository` incl. queue replay after offline), `InboxUITests` (3 flows, smoke) and `InboxAuditUITests` (Full). Not built: "Suggest another time" (no server call), the waitlist "Cancels often" chip, `MailboxService`/`PushService` unit tests |
| Next | | S8 leftovers: `FirebaseAuthProvider` server deletion and subscription verification swaps, mailbox and push service tests; then S9, S11, S12; the `pt-BR`, `de`, `hi` audit runs of S6 to S8 never finished |

**Later on 2026-10-10 (04:35): approved color refinement done on `build/v1`** (task `docs/tasks/color-refinement.md`, notes and token-to-role mapping `docs/agent-notes/color-refinement.md`). Medium-intensity sage, rose and peach from the hex specification (the reference mockup was not in the repo). New `Palette` roles: `action`/`onAction` (every `.belloPrimary`, check discs, radios, progress; `inkOnFill` is gone), `selectionFill`/`selectionInk` (selected chips, calendar day, week-grid today, region tile, tab bar tint; always with a ring or a check), brand fills + `onBrandCard` + family badges (insight tiles, empty-state shapes, avatar ends), `ivory`, `brandMark` (the mark now matches the app icon). Neutrals, accents, washes, avatars, hero (green-graphite) and shadow tint retinted; amber and coral unchanged. Home's "New appointment" quick action is primary unless the empty state shows it. Web carries the roles (`web/src/styles`, `check-contrast.ts`; `scripts/test-web.sh full` green, 152/152 pairs). New: `-uiDark` UI-test hook (the iOS 27 simulator's appearance switch does not reach apps) and the opt-in `ColorReviewUITests` (screenshots to `TEST_RUNNER_SCREENSHOT_DIR`). Measured on the head: fast 2038 tests in 285 suites; smoke 45 UI tests (+1 skipped tool); `check-warnings.sh` zero warnings. Review screenshots in `build/screenshots/` (not committed). Owner to compare with the approved mockup.

**Later on 2026-10-10 (03:30): S8 inbox screens 2.9 to 2.11 done on `build/v1`.** Measured on the head: fast 2038 tests in 285 suites; smoke 45 UI tests (incl. 3 `InboxUITests`); `InboxAuditUITests` clean in en, pt-BR, de, ar, hi at the default size and AX5; `check-warnings.sh` zero warnings; strings 2212 keys. Fixed on the way: alert cards grow to fit every line; no isolate marks around a bare time in the Alerts request cards (the audit read them as clipped text); the S10 recovery-key UI test flips its switch again when the first tap lands during the scroll (it flaked once in smoke).

Integration fixes made on 2026-10-10 (all committed): `AppDependencies` split through `InboxServices` (SwiftLint body length); `FirestoreDocumentDecoder` integer helper (complexity); orphaned doc comment in `UITestInboxRepository`; the deprecated `Messaging.fcmToken` getter replaced by `TokenContinuations` keeping the last token; the `ConsentRecordViewModelTests` delete-guard test gave the record another client's id.

**Deployed to `bello-hub` (dev, D43) on 2026-10-09 (functions and Hosting redeployed with D55 on 2026-10-10):** Firestore rules and indexes, Storage rules, all Cloud Functions in `europe-west1` (Node 22, 2nd gen; image cleanup policy of 1 day set), Hosting at `https://bello-hub.web.app`; secrets in Secret Manager: `PHONE_HASH_PEPPER` (generated once, never rotate), `EMAIL_API_KEY` and `APPLE_SIGNIN_PRIVATE_KEY` as placeholders (`unset`); parameters in `firebase/functions/.env.bello-hub` (no secrets; `EMAIL_FROM` and `APPLE_SIGNIN_KEY_ID` empty keep e-mail and Apple revocation off). Smoke test passed (page 200, `/api/getPublicPage` answers `NOT_FOUND` for an unknown slug). Redeploy Hosting with `scripts/deploy-hosting-dev.sh`, functions with `cd firebase && firebase deploy --project dev --only functions`. Not done by me: enable the Apple provider in Firebase Auth, the budget alert, App Check stays off. The iOS app does not publish yet (S8 iOS half).

**D55, to apply (owner, 2026-10-09): consents are removed from the app, web and server; only a status record with an optional photo/file of the real document stays.** Work to queue (two slices, Sonnet medium for iOS, Fable medium for web and backend): iOS: delete the consent text, signing and signed-text screens of 4.5, the consent rows and preview of 6.14, `legal.*` strings of the three consent kinds, bundling of consent legal texts (`scripts/check-legal-resources.sh`, `sync-legal-resources`), `ConsentKind` text mapping; replace with a "Consents" status list on 4.5 (label, signed yes/no, date, note, optional photo or file via the vault) with tests, strings and audits. Web and backend: remove `getFormContext.consent`, the consent text and signature from the web form, the `intakeForms` consent text and the consent block of the sealed payload; keep the health questions; update API.md, schemas, tests, e2e. Docs: `docs/05`, `docs/06`, `docs/07`, `legal/STATUS.md` and the legal drafts of the three consent kinds (remove them from the 14-localization bundles).

**Booking link until the domain exists (D54):** base `https://bellohub.web.app` (create the Hosting site `bellohub` in `bello-hub` at the first deploy); `BookingLink.defaultBaseURL` (today `https://bellohub.app`) must read a configuration value (`BELLO_WEB_BASE_URL`), and the booking-page screens must say the link is a preview until she is online. Part of S8 iOS half. Owner tasks: budget alert of about 5 EUR on the Firebase project; enable the Apple provider in Firebase Auth; Apple Sign-In key.

**After the S6 slices:** S7 front end (5.1 to 5.9, 4.7, 4.9, 4.10, 7.5; fakes behind protocols for voice, AI, photos, PDF; manual `Tx-Form` fully real; D53), then S8 iOS half (`RemoteBookingRepository`, `BookingSyncService`, `MailboxService`, outbound queue, `FirebaseAuthProvider` with Apple, FCM and silent push; see `docs/agent-notes/backend.md` section 4 item 2), S9 (web against the app), S10 (9 screens: account, plan with StoreKit, privacy, export, recovery key, help), S11, S12.

**Owner tasks that do not block building** (list in `docs/14-HUMAN-TASKS.md` and the agent notes): Resend account and sender domain, Apple Sign-In key (.p8), Apple root certificates, App Store Connect products and account, domain `bellohub.app`, staging Firebase project, checks on a real iPhone (contact picker, CSV from Excel, Face ID, camera, microphone). Never deploy to Firebase before the backend and web are merged and e2e passes; never enable App Check enforcement.

## Stage log
One block per finished stage (newest last):

```
### S<n> · <name> · done <date> · tag stage-S<n>
Done: files and features (short)
Decisions/assumptions: ASSUMPTION-<n> ...
Deviations from the prototype: ... (reason)
Design additions: ... (screenshot path)
Measured: contrast ..., tests (fast/smoke/full counts), timings ...
Open questions: ...
Human tasks created: H...
```

### S0 · Adopt the repo, preflight, baseline · done 2026-10-08 · tag stage-S0
Done: branch `build/v1`; handoff copied in (`docs/`, `design/`, `repo-patch/`, `PROMPT.md`, `VERSION`); `repo-patch` applied (CLAUDE.md intro, pre-answered decisions, iPhone-only line, languages, sibling folders; `TARGETED_DEVICE_FAMILY = 1`; iPad orientation key removed; bundle ids `com.bellohub`, `.BelloHubTests`, `.BelloHubUITests`; `.gitignore`); no `iagoxavierdelima` id left outside docs; entitlements moved to `SupportFiles/` with iCloud/CloudKit, Push and App Attest (`APP_ATTEST_ENVIRONMENT` per configuration in `App.xcconfig`) and `UIBackgroundModes = remote-notification`; device build signed with `-allowProvisioningUpdates`; Crashlytics removed; `firebase/` with `firebase.json`, `.firebaserc`, deny-all `firestore.rules` and `storage.rules`, `firestore.indexes.json`, `config/{dev,staging,prod}.json`; Firestore `(default)` created in `eur3` in `bello-hub` with deny-all rules deployed; `scripts/check-privacy.sh` (Firebase, SwiftData/CloudKit, print, analytics boundaries) wired into `check-warnings.sh`; `scripts/fetch-fonts.sh`; this file with the market table and 97-row traceability.
Decisions/assumptions: ASSUMPTION-1 to ASSUMPTION-8.
Deviations from the prototype: none (no UI yet).
Design additions: none.
Measured: baseline before edits 9 unit + 1 UI test, all passing; after edits `scripts/test.sh fast`, `smoke` and `full` pass (Fast now has 5 unit tests because the 4 crash-policy tests left with Crashlytics); `scripts/check-warnings.sh` reports zero warnings on simulator, device and Release; `scripts/check-project-settings.sh` clean. One UI smoke run failed once with the simulator reporting `Busy` right after the Fast run; a rerun passed (infrastructure flake, not a code failure).
Open questions: see the top of this file (one Firebase project instead of three; Storage bucket; Crashlytics FYI; `gh` login).
Human tasks created: H17; notes added under H1 and H4.

### S1 · Design system, fonts, motion, catalog, localization infrastructure · done 2026-10-08 · tag stage-S1
Time: about 1 h 10 min (S0 took 20 min; both include reading the docs and a lot of waiting for builds).
Done:
- Tokens: `Palette` (light/dark and Increase Contrast pairs), `StatusPalette`, `AvatarPalette`, `HeroPalette`, `Typography` (Fraunces + DM Sans, variable fonts, `FontRegistry`), `Spacing`, `Radius`, `Elevation`, `Icon`, `Motion`.
- Motion kit: `MotionPolicy`, `MotionArrival`, `StaggeredStack`, `motionBar()`, press and haptics in the button style, `SuccessSeal`, `HeroSurface` (drift and sheen with the limits of `docs/09`), `Directional`.
- Components: `BelloButtonStyle` (variants and chips), `Avatar` + `Initials`, `StatusChip`, `SectionHeader`, `ListCard` + `belloCard()`, `InsightTile`, `HeroCard`, `EmptyState`, `SheetHeader`, `BelloTextField`, `InlineNotice`, `Skeleton`, `OfflineBanner`, `FooterNote`.
- DEBUG Design Catalog (`-designCatalog`, with `-uiLocale`, `-catalogSection`, `-catalogTextSize`, `-catalogDark`) and `LaunchOptions`.
- Localization: `Localizable.xcstrings` and `InfoPlist.xcstrings` with all fourteen localizations, `knownRegions`, `Config/App-Info.plist` (localizations, remote-notification), `scripts/{check-strings,derive-locales,merge-strings,export-strings,import-strings}`, `Config/Locale/` batches and overrides, glossary extended to all localizations (46 terms), `AppLocalization` (resolution rules), `RegionPreset` + `regions.json` (24 regions) + `RegionCatalog`, `PhoneNormalizer`, `PhoneFormatter`, `DigitNormalizer`, `BidiIsolate`, `Formatters`, `WeekConfig`, line-height multiplier for `ar` and `hi`.
- Tooling: `scripts/check-strings.sh` runs inside `test.sh fast`; `check-warnings.sh` also builds the test targets; `check-project-settings.sh` verifies `knownRegions` and the Info.plist fragment; an `xcodebuild` watchdog in `scripts/lib.sh`.
- `DESIGN.md` rewritten (identity, tokens, typography, motion, components, catalog, accessibility).
Decisions/assumptions: ASSUMPTION-9 to ASSUMPTION-15.
Deviations from the prototype: `fieldBorder` darker (3:1, the prototype's is 1.4:1); avatar initials darker for sage and peach (4.0:1 in the prototype); hero secondary text is a solid color instead of cream at 68 %; tab bar tint is `ink` (the prototype's selected tab is graphite).
Design additions: none.
Measured: contrast, every text pair in light, dark and both with Increase Contrast: all at least 4.5:1 and no pair worse with Increase Contrast; UI parts at least 3:1 (`fieldBorder` 3.6 light, 3.9 dark on `bg`); hero text 8.1:1 (primary) and 5.9:1 (secondary) at the lightest glow point. Unit tests: 99 in 16 suites (0.12 s); smoke: 3 UI tests (25 s); Full also runs the accessibility audit of the catalog (clipped text and element description) in `en`, `pt-BR`, `de`, `ar` and `hi` at the default size (112 s) and at AX5 (111 s), and with doubled strings (22 s): all clean. Strings: 34 keys in 14 localizations, check passes (negative-tested: missing language, placeholder, plural category, empty value, stale derived, hard-coded text). `check-warnings.sh`: zero warnings on simulator, device, Release and the test targets.
Findings worth keeping:
- `Font.custom("Fraunces").weight(.medium)` resolves to `wght` 500 (identical to an explicit variation), so no custom font plumbing is needed.
- `INFOPLIST_KEY_UIBackgroundModes` is not a supported key: it produced nothing, so `remote-notification` was missing until the Info.plist fragment was added.
- An `accessibilityIdentifier` on a container replaces the identifiers of its children. Identifiers go on elements.
- Xcode's right-to-left pseudolanguage launch arguments do not flip SwiftUI layout; the real `ar` run (first chip on the right, mirrored hero) is the RTL check.
- Spanish and Portuguese four-digit grouping, French narrow no-break space, Hindi lakh grouping, German and Turkish currency and the documented week-start and clock defaults all matched the doc (asserted, hand-verified quirks).
- Xcode 27 sometimes keeps `xcodebuild test` alive for minutes after the tests finish; the watchdog stops it once the log shows the run is complete and idle.
Open questions: see the top of this file.
Human tasks created: none. H12 (fonts) was not needed: the network allowed the download.

### S2 · Domain, persistence, vault, keys, sync spike · done 2026-10-08 · tag stage-S2
Time: about 45 min of work (17:05 to 17:50), including the D40, D41 and D42 decisions arriving mid-stage.
Done:
- Domain structs and persisted enums with safe fallbacks (`PersistedEnum`: an unknown raw value never crashes, never widens who sees a photo, never blames a client).
- Pure rules, all taking `now`: `RecordLockPolicy`, `HabitsCalculator`, `FollowUpPlanner` (follow-ups, win-back, birthdays), `FreeSlotsCalculator`, `WaitlistMatcher`, `SessionPlanProgress`, `CancellationEvaluator`, `NoShowEvaluator`, `QuietHours`, `Pricing`.
- Vault: `SecretBox` (AES-256-GCM), `KeyDerivation` (root key, vault key, inbox X25519 key pairs per generation), `RecoveryPhrase` (12 words, BIP-39 list fetched and verified by `scripts/fetch-wordlist.sh`), `VaultFieldCodec` (associated data `kind|id|field`), `KeyManager` over `KeychainKeyStore` (iCloud Keychain, synchronizable) with an in-memory store for previews.
- Persistence: one SwiftData table (`VaultItem`, see the spike), `ClientRecordRepository` as three focused protocols (`ClientRepository`, `AgendaRepository`, `TreatmentRepository`), `SwiftDataClientRecordRepository` (an actor), `InMemoryClientRecordRepository` (DEBUG), `VaultMigrationPlan`, `VaultContainerFactory`, change streams.
- D42: `RegistrationQuota` (the only place that knows the number 10), `RegistrationLedgerEntry` (id and date only, never removed by a delete; the repository appends it the first time a client id is saved), `PlanSavings`, `PlanProduct`; strings for the limit message, counter and paywall in all fourteen localizations (`s2-registration-limit.json`).
- `SyncStatus`, `SyncStatusReducer`, `SyncStatusService`, `CloudKitSyncMonitor` (the only file that knows CloudKit error codes).
- `docs/spikes/SPIKE-swiftdata-cloudkit.md` with the verdict (GO) and the two-iPhone checklist; independent known-answer vectors in `scripts/vault-vectors.py`.
Decisions/assumptions: ASSUMPTION-16 to ASSUMPTION-23; owner decisions D40, D41, D42 recorded in `docs/02-DECISIONS.md`.
Deviations from the prototype: none (no UI). Deviations from the docs: the vault is one table instead of one `@Model` per type (reason in the spike and in `docs/05`); `masterKey` is called `rootKey` in code (SwiftLint's inclusive-language rule), with the HKDF label still `"master"` because it pins the keys.
Design additions: see the table below (D42 screens).
Measured: 302 unit tests in 42 suites (2 s); 3 UI smoke tests; `scripts/check-warnings.sh` zero warnings on simulator, device, Release and the test targets; `check-project-settings`, `check-privacy` and `check-strings` clean. Key derivation matches vectors computed without CryptoKit (HKDF from the standard library, X25519 as the RFC 7748 ladder checked against the RFC's own vector); the four published BIP-39 vectors and the list's SHA-256 match; an AES-GCM known answer from the NIST specification matches. The sentinel test scans the database, its write-ahead log and the external-storage folder for 28 sentinel strings across every sensitive field and finds none, while the clear columns do show the name (so the scan is not blind). Daylight saving: 00:00 to 05:00 offers 4 slots on spring-forward days and 6 on fall-back days in Lisbon, Madrid and New York, and 5 on every day in Mexico City and São Paulo.
Findings worth keeping:
- SwiftData's default `.automatic` CloudKit setting switches mirroring on by itself when the app has the iCloud entitlement; the mirroring delegate logged sync errors in a test that used the default. The factory always passes `.none` or `.private`.
- `INFOPLIST_KEY_UIBackgroundModes` was ignored (S1); `masterKey` trips SwiftLint's inclusive-language rule (renamed `rootKey`).
- A wrong key must not look like an empty vault: if every item of a kind is unreadable the call fails; a partial failure skips the damaged record and logs only its id and kind.
- 23:59:59 versus 24:00:00 and the lock being 24 real hours (not a calendar day) are tested, including across a daylight-saving change.
Open questions: ASSUMPTION-18 (re-signing up with the same phone after deleting the account restarts the count of 10).
Human tasks created: none new. H2 (CloudKit schema to Production) and H3 (two iPhones) now have the concrete checklist in the spike report.

### L · Legal drafting pass for every market (D40) · done 2026-10-08 · tag stage-L
Time: about 16 min of wall clock by the machine clock (17:21 commit of S2 to 17:37), writing in seven batches.
Done:
- 98 drafts under `legal/<document>/<localization>/2026-10.md`: terms of use with the data processing agreement, privacy policy, booking-page client notice, health-form consent, photo consent, guardian consent for minors, and the wording of copy and deletion requests, each in all fourteen localizations. About 46,000 words.
- Each text names the law of its market (LGPD, RGPD/LOPDGDD, UK GDPR and the Privacy Acts, LFPDPPP, US state laws including Washington's My Health My Data Act, KVKK, Indonesia's PDP Law, India's DPDP Act, the Saudi and UAE laws) and uses the product facts in `legal/README.md` (clinical data on the iPhone, sealed mailbox, 7-day and 30-day retention, no analytics, on-device AI, the first 10 registrations free).
- `legal/README.md` (layout, fill-in fields, the facts sheet), `legal/STATUS.md` (the generated table plus ten open points for a lawyer), `scripts/check-legal-status.sh` and `.py`, wired into `scripts/test.sh fast` and `full`. The checker fails on a missing file, a missing header field, an unknown placeholder, a header that does not match its folder, or a forbidden claim.
Decisions/assumptions: ASSUMPTION-24 and ASSUMPTION-25 below.
Deviations from the docs: none. Nothing is claimed as compliant anywhere; every header carries `status: draft` and `review: LEGAL-REVIEW`.
Measured: `scripts/check-legal-status.sh` reports 98 documents, 7 kinds x 14 localizations, all present, exit 0.
Findings worth keeping:
- The system Python is 3.9 and rejects a source file with long non-ASCII lines unless it starts with a coding declaration (`# -*- coding: utf-8 -*-`); the generator scripts live in the scratchpad, not the repo.
- Facts that differ by market are written into the market's own text (Brazil 15 days, Mexico 20 business days, Turkey's article 11 rights, the United States HIPAA note), so `legal/STATUS.md` point 4 asks the lawyer to confirm them.
Open questions: the operator identity (H17) fills `{{OPERATOR_NAME}}`, `{{OPERATOR_ADDRESS}}`, `{{OPERATOR_EMAIL}}`, `{{WEB_BASE_URL}}` and `{{EFFECTIVE_DATE}}`; until then the in-app screens must show these texts with the fields visibly pending in DEBUG and block the Release build (S11 gate).
Human tasks created: none new; H17 now also covers the operator fields.

### S3 · Shell, onboarding, session, lock · done 2026-10-08 · tag stage-S3
Time: about 1 h 30 min of work (17:38 to about 19:10 by the machine clock, after plan item L), including a run on the owner's iPhone and three rounds of accessibility audit fixes.
Done:
- State gate: `RootView` over `RootGate` (welcome → sign-in → setup → locked → app), driven by `SessionService`, `AppLockService` and `DefaultsKey`; Services are `@State` at the root and distributed with `.environment`. `AppDependencies` builds the live set, or an in-memory set for UI tests.
- Session: `AuthProvider` protocol, `SessionService`, `LocalDevAuthProvider` (DEBUG: any phone, code 123456), `UnconfiguredAuthProvider` (Release until S8). Phone sign-in screen with the country code menu, auto-verify on the sixth digit, a 30 second resend countdown and every error spoken.
- Lock: `LockPolicy` (grace 0/30/60/300/900 s, default 60), `AppLockService` over `BiometricAuthenticating` (`LocalAuthentication`, device-owner policy so a failed face offers the passcode), the Locked screen (scrollable, auto-prompts once), `PrivacyCover` over everything while the scene is not active, the key cleared from memory on lock.
- Vault additions: `BusinessRepository` (profile, tags, record template, and `saveOnboarding` that stores everything together) in the SwiftData and in-memory repositories, new `VaultKind`s `profile`, `tag`, `recordTemplate`; `VaultService`, `ProfileService`.
- Onboarding: 8 steps in one `OnboardingViewModel` (About you with region, Profession, Services with the custom-service sheet, Terminology with the client term and her own names, Tags, Record fields and intake, Permissions, Ready), pure rules and builder in `Screens/Onboarding/Support/` (`OnboardingRules`, `OnboardingSuggestions`, `OnboardingBuilder`, `PriceInput`).
- Profession catalog as data: `Resources/Professions/professions-<localization>.json` for the 14 localizations (9 professions; 51 services, 49 tags, 63 record fields each), `ProfessionCatalog` loader, `scripts/check-professions.sh` (runs in `test.sh`).
- Shell: five tabs on the system `TabView` (Home, Clients titled with the term she chose, Calendar, Alerts, More), honest empty states, More with her profile card, Lock now and Sign out.
- Design system: `BrandMark`, `BrandLockup`, `ChoiceCard`, `FlowLayout`, `StepProgressBar`, `ToggleRow`, `GlowBackdrop`, `Text.prompt`; `BelloTextField` gained `identifier`.
- Strings: 167 new keys (212 in the catalog) in all 14 localizations (`s3-entry`, `s3-setup`, `s3-shell`, `s3-region`); usage descriptions for Face ID, microphone, camera and contacts localized in `InfoPlist.xcstrings`.
- `scripts/run-device.sh` builds, installs and launches the Debug app on a paired iPhone; `scripts/test.sh` takes `ONLY_TESTING=<suite>`.
Decisions/assumptions: ASSUMPTION-26 to ASSUMPTION-34; the Design additions table has six S3 rows.
Deviations from the docs: the draft is not saved across a killed app (ASSUMPTION-28); the booking link and the import shortcut on Ready wait for S8 and S4; Sign out is in More until S10.
Design additions: see the table below (About you, sign-in without email, terminology term, six-segment progress, Ready link, empty states).
Measured: about 410 unit tests in 64 suites pass in about 2 s (S2 had 302 in 42); the fast and smoke plans pass; `scripts/check-warnings.sh` zero warnings (simulator, device, Release, test targets). Contrast measured by unit tests (the backdrop's strongest point for `ink`, `ink2` and `coralText`; `roseText` stays off the glow). Accessibility audit (clipped text and element descriptions) of every onboarding screen, Home, More and Locked in `en`, `pt-BR`, `de`, `ar` and `hi`, at the default size and at AX5: clean, with two documented false positives (Devanagari text and the phone field).
Findings worth keeping:
- Apple's `.contrast` audit flagged 14:1 buttons (shadow), disabled controls and 5:1 secondary text, so the audit suites skip it and contrast is measured exactly by the unit tests. It did find real problems: the system placeholder gray (about 2:1, now `Text.prompt` in `ink2`), the pale rose "hub" wordmark (2.4:1, now `roseText`) and `roseText` links on a glow (4.0:1; the glow is now small and `roseText` stays below it).
- "Text may be clipped at larger Dynamic Type sizes" is the audit's way of saying a screen does not scroll: the Locked screen needed a `ScrollView` with a minimum height; `ViewThatFits` left an empty zero-size element at AX5, so adaptive rows use `FlowLayout` or `dynamicTypeSize.isAccessibilitySize`.
- The system tab bar does not pass accessibility identifiers to its buttons: UI tests find tabs by position.
- A confirmation dialog's button matches twice in XCUITest; use `.firstMatch`. `Wait.untilMain` is the helper for main-actor state.
- Glossary rule applied to every UI string: neutral forms ("cliente", "Kundschaft"), no feminine plural. The legal drafts still use feminine forms in places (`legal/STATUS.md` point 11).
- Turkish "uygulama" means both app and treatment; treatments are "işlem" in the app and in the legal drafts.
Open questions: none new.
Human tasks created: none.

### S4 · Clients and the client record · done 2026-10-09 · tag stage-S4
Built by four parallel agents on the contract `407427e` (notes in `docs/agent-notes/{clients-ui,import,health-forms,tags-record-template}.md`, which keep the full detail), integrated by the coordinator on 2026-10-09 after a session limit (merge commits `0e5ba77`, `f172479`, `b9912de`, `8285942`).
Done:
- Clients (2.2, 4.1 to 4.4): `ClientsTabView` over `ClientsRoute`, list with search, filter chips (incl. Archived), sort, the win-back strip, 2,000-client performance test; profile (hero, habits, knowledge, health and consent row, session plan card); New client sheet through the D42 gate with an inline duplicate notice; edit with Restore and merge (`ClientMerger`, `mergeClient` on both vaults with contract tests); knowledge editor; `PhoneLauncher`.
- Import (4.6): CSV parser (UTF-8, UTF-16, Windows-1252), column mapper, row rules, system contact picker, file importer, mapping screen, result with the D42 "n more need a plan" card; the import shortcut on the last setup step.
- Health and consent (4.5) and Client forms (6.14): versioned health form model per profession, sealed `patchTest` vault kind, `ConsentKind.guardian` and the minors flow (D17), the legal texts bundled per language with `scripts/check-legal-resources.sh` and `check-health-forms.sh`, signed text kept with version and language.
- Tags (6.12), Record fields (6.13) and More (2.5) with `MoreTab` over `MoreRoute`; `ProfileService` edits; tag deletion that cleans clients in one write.
- Design system: `TagColor`, `TagDot`, `ErrorNotice`, `BelloNoteField`, `FlowLayout(wrapsLongChildren:)`, `SheetHeader(closeIdentifier:)`.
- Integration fixes: `FlakyHealthRepository` gained `mergeClient`; `HealthContrastTests` named a pair that does not exist (`sage on surface`); the health UI helper closes the keyboard before it scrolls to a chip (the drag landed on the keys and the chip was lost); the `legal.draftNote` line was removed from 4.5 and 6.14 because `legal/STATUS.md` says the app never shows the word "draft".
Decisions/assumptions: ASSUMPTION-35 to ASSUMPTION-48.
Deviations from the prototype: see `DESIGN.md` "Changes from the prototype (S4)" and the Design additions table (S4 rows).
Measured: fast 988 unit tests in 131 suites pass; UISmoke 18 UI tests pass (453 s); `scripts/check-warnings.sh` zero warnings on simulator, device, Release and the test targets; `scripts/check-strings.sh` passes (597 keys, 14 localizations). Audits run by the agents at AX5 and default size: Clients in `en`, `ar`; Import in `en`, `pt-BR`, `de`, `ar`, `hi`; Health in `en`, `ar`; More in `en`, `ar`, `hi`, `pt-BR`, `de` (AX5 `pt-BR`, `de`, `ar` for More not rerun after its last test-only scroll change). Not run: `scripts/test.sh full` with every audit in five languages (about 1 h); the tag `stage-S4` also carries the S5 contract commit `78a7317`, made before the last fixes.
Findings worth keeping:
- Swift Testing has its own `Tag`: in test files write `BelloHub.Tag`.
- XCUITest thinks anything inside a scroll view is visible even under a floating bottom bar; drag then hold before a tap (`scrollAboveBottomBar`), and close the keyboard first.
- `Calendar.current` is Islamic under `ar_SA`: take every year from a Gregorian calendar in the business time zone.
- A UTF-16 file without a BOM in ASCII letters is valid UTF-8 (every other byte NUL): test UTF-16 first.
- Bounds on 2,000-row pure code are measured in thread CPU time (`CPUTime.measure`); wall clock under parallel suites on Debug is noisy.
- `-AppleInterfaceStyle Dark` does not switch an XCUITest run; `xcrun simctl ui <udid> appearance dark` does.
- Agents sharing the scratchpad must use slice-specific script names.
Open questions: should the D42 gate own the phone-clash check on edits (today the form checks); phone-less contacts imported twice become two clients; does a minor turning 18 change her form; where `{{OPERATOR_*}}`, `{{WEB_BASE_URL}}`, `{{EFFECTIVE_DATE}}` come from (H17).
Human tasks created: on a real iPhone, check the contact picker (multi-select, labelled phones, birthdays) and the file importer with CSV from Excel for Windows and from Numbers (added to H8).

### S5 · Business setup · done 2026-10-09 · tag stage-S5
Built by two Sonnet agents on the contract `78a7317` (notes `docs/agent-notes/s5-services.md`, `s5-booking.md`); both died once of the session limit and were finished by new agents; integrated by the coordinator (merge commits after `1378a7a`).
Done:
- Services (6.1, 6.2, 6.3), Products (6.4), Credentials (6.10), Team (6.11, static): `Product`, `Credential`, `CatalogRepository` on both vaults, contraindications from the health-form catalog tokens, patch-test flag, reorder through `PositionRules`, price input read the way each language writes it (`PriceInput` fixed for Arabic digits and Brazilian decimals).
- Availability (6.5), BookingSettings (6.7) with pause and return date, ShareLink (6.8, QR with CoreImage), CancelPolicy (6.16), NoShowPolicy (6.15), QuickReplies (6.9): `BookingSetupService` (injected from `RootView`), `BookingSetupRepository` on both vaults, `BookingSlug`, `BookingLink`, `BookingPause`, `PolicyRuleText` (one owner of the client-facing rule text, all 14 localizations), `QuickReplyRenderer`, `BookingRepository` protocol with an offline implementation (the server arrives in S8).
- Decisions/assumptions: ASSUMPTION-49 to ASSUMPTION-58.
Deviations from the prototype: `DESIGN.md` "Changes from the prototype (S5)".
Measured: fast 1362 unit tests in 166 suites pass; UISmoke 21 UI tests pass (631 s); `scripts/check-warnings.sh` zero warnings on simulator, device, Release and the test targets; `scripts/check-strings.sh` passes (1,032 strings merged, 14 localizations). Audits `ServicesAuditUITests` and `BookingSetupAuditUITests` run in `en` and `ar` at default size and AX5; not run: `pt-BR`, `de`, `hi` for them, dark mode, `scripts/test.sh full`.
Open questions: do saved policies apply to bookings already made (today they keep their snapshot, the prototype footer said otherwise; owner); should "Always" return as a no-show counting period (needs a model case and the server's `countingMonths`); should the credentials page switch survive with no credential; should these screens follow `clientTerm` instead of "clients".
Human tasks created: none.

### S6 · Home, calendar and appointments · done 2026-10-09 · tag stage-S6
Built by three slices (notes `docs/agent-notes/s6-calendar.md`, `s6-appointment.md`, `s6-home.md`) on the contract (`AppointmentService`, `AppointmentTransitions`, `AgendaRoute`, `AgendaSheet`); also merged in the same integration: the S7 treatment flow front end (5.1 to 5.9, D53; `docs/agent-notes/s7-flow.md`) and the S8 publish slice (the booking link works end to end, `docs/agent-notes/s8-publish.md`).
Done: day and week calendar with the warnings engine, NewAppointment, Reschedule, BlockTime, WeekGlance; appointment detail with cancel, no-show, running late, before-you-start, messages through WhatsApp, session plan, no-show history; Home, follow-ups, win back, Alerts (local), shared states, local notifications with no names; time blocks in the vault.
Measured: fast 1710+ unit tests pass; UISmoke 48 UI tests pass; `scripts/check-warnings.sh` zero warnings on simulator, device, Release and the test targets; `scripts/check-strings.sh` passes (1596 strings, 14 localizations). Audits (`en`, `ar`, default size and AX5) for Calendar, Appointment, Home; not run: `pt-BR`, `de`, `hi`, dark mode inspected by eye, `scripts/test.sh full`.
Decisions/assumptions: see each notes file (to fold into the table at the next consolidation); Design additions: see each notes file.
Open questions: Home quick actions are "New appointment" and "Week at a glance" only; Alerts holds local alerts until S8 inbox.

### S7 · Treatment record front end (D53) · done 2026-10-10 · tag stage-S7
Merged earlier with S6 (`docs/agent-notes/s7-flow.md`, `s7-record.md`): 5.1 to 5.9 with voice and AI as unavailable stubs, the manual form fully real; 4.7, 4.9, 4.10; 7.5 AISettings (row in More → Preferences). Tagged at the 2026-10-10 integration head (fast 2008, smoke 42, zero warnings).

### S8 · Backend and iOS integration (partial) · tag stage-S8 on 2026-10-10
Done: backend and web (D55 deployed to dev 2026-10-10), the publish slice (booking link live), inbox services (sync, mailbox, outbound queue, push), and after the tag the inbox screens 2.9, 2.10, 2.11 with their Alerts cards, tests and audit (DESIGN.md "Changes from the prototype (S8 inbox)"). Open: `OfflineAccountDeleter` and `OfflineSubscriptionVerifier` swaps to the server, mailbox and push service unit tests. The tag marks the integration head, not the stage exit.

### S10 · Account and settings · done 2026-10-10 · tag stage-S10
Done: 7.1 to 7.4 and 7.6 to 7.10 (`docs/agent-notes/s10-account.md`): account with delete-account cascade, language and region, plan and paywall over StoreKit 2, notification settings, integrations, privacy with the legal notices, export all (ZIP of CSVs and a PDF), recovery key with restore from Locked, help. Also D55 iOS (`docs/agent-notes/d55-ios.md`): consent status records with an optional photo or file replace the consent texts and signing.
Measured: fast 2008 tests in 278 suites; smoke 42 UI tests; `check-warnings.sh` zero warnings; strings 2142 keys in 14 localizations. Audits of the slice (`AccountAuditUITests`, `HealthAuditUITests`) are in the Full plan; not run in this integration.
Decisions/assumptions: see the two notes files (delete-account order, paywall = Plan screen, device settings survive deletion, consents as records). Design additions: DESIGN.md "Changes from the prototype (S10)" and "Changes from D55".

### S9 · Client web app against the real app and backend · done 2026-10-10 · tag stage-S9
Done (`docs/agent-notes/s9-web.md`, gap table of 8.1 to 9.9): the web app built in S8 checked screen by screen against docs/10, docs/06 and the prototype; built what was missing: the waiting-list offer link `/{slug}/time?offer=<key>` (`getHold`, converts her hold), the Bk-1 approval notice, the Bk-8 health card by `intakeRequired`, the Cl-7 "Health form" label (D55). **Found and fixed on the iOS side: the app never published her health form** (`publishProfile.profile.intake` now carries the current template in every booking language; before, `getFormContext` answered NOT_FOUND for every real professional), and check-in and data-request sent times were lost (browser milliseconds; `PayloadInstant`). Shared vectors both ways: the page's own sealed envelopes (`js-sealed.json`, 2 new schema-2 intakes built by the page's form code) opened and read by the app (`EnvelopeOpenerTests`), CryptoKit-sealed envelopes (`swift-sealed.json`, new) opened by the page's suite and Python; the Python cross-check had silently skipped and now runs. Exit tests strengthened: the egress test books, seals and sends a data request; no answer, question key or payload field name in any request; `submitSealed` carries `{token, envelope}` only. Flake fixed: e2e-local picked a slot of the previous day.
Decisions/assumptions: ASSUMPTION: the published form uses the catalog prompt as the label, `choices` as `multiChoice` with `none` last, no `required` flags (the app's form has none); the default template is stored as version 1 at the first publish. Not built on purpose (s9-web.md section 2): her rules list on Bk-9 (same snapshot as the D47 sentences), prices on Bk-9/Cl-3 (no price snapshot), "her reply to late" and the message link on an expired link (no API field), the portfolio switch.
Deviations from the prototype: offer link has no prototype screen (opens on Bk-5; ended offer = full-page state). DESIGN.md "Client web app (S9)".
Measured: web `scripts/test-web.sh full` green: lint, types, i18n (14 localizations, 400 keys), contrast 152/152, privacy gate, unit 233 passed (0 skipped), build, Playwright 191 passed / 15 skipped (Chromium 97, WebKit 82, low-end 12), Lighthouse median of 3 (mobile): `/maria` performance 0.99, accessibility 1.00; `/m/<token>` performance 0.99, accessibility 1.00; initial JS 48.1 KB gzip (budget 80), CSS 7.0 KB, sealing chunk 13.5 KB lazy. `scripts/e2e-local.sh` 6 passed (real functions on the emulators). iOS: fast 2056 tests in 288 suites; smoke 45 UI tests passed (+1 skipped tool, 27 min); `check-warnings.sh` zero warnings (simulator, device, Release, test targets). Deployed: Hosting to dev (`https://bello-hub.web.app`, page 200, CSP and no-store on `/m/**`, `getHold` NOT_FOUND for an unknown slug, SRI hashes in the HTML); functions not redeployed (`firebase/` unchanged).
Open questions: none new; backend fields for price and late-reply snapshots if wanted.
Human tasks created: H8 extended (offer link from WhatsApp; her form on the page after going online).

### D56 · Smart slots · done 2026-10-10 (after S9, before S11)
Done (`docs/agent-notes/smart-slots.md`): `FreeSlotsCalculator` / `freeSlots.ts` plan `all` + `recommended` (anchors, segments with buffered edges, extra and processing time, slot step incl. match-the-service, compact day with per-gap fallback); `getSlots` returns `more`; holds, bookings, reschedules, waitlist offers and matching use it; timing snapshots on bookings and holds; app: service "Time around the visit", Booking settings "Start times" and "Keep my day compact", suggestions and warnings through the same engine, "Show all times" in the app and on the web (Bk-4, Cl-3, Cl-9); 17 app strings and 1 web string in 14 localizations.
Measured: shared fixture 239 free-slot cases (Swift-generated, TS-checked, `all` and `recommended`); functions unit 906, emulator 66 + 286, transport 19; web full green (unit 234, Playwright 191 + 15 skipped, Lighthouse 0.99/1.00); e2e-local 7 passed (new D56 story); iOS fast 2087 tests in 293 suites; smoke 48 UI tests (47 passed + 1 skipped tool); `check-warnings.sh` zero warnings. Deployed: all functions and Hosting to dev; smoke of the deployed page passed.
Fixed on the way: a stale mock server on port 4010 (from 2026-10-09) broke two e2e tests; `InboxRig` first-sync wait 3 s -> 20 s (two Fast-plan flakes).

### S11 · Localization completion and market readiness · done 2026-10-10 · tag stage-S11
Done (`docs/agent-notes/s11-localization.md`): audit of every string in the fourteen localizations against the glossary, the plural rules and the address rules. Main fixes: German app strings in *du* (about 330 were *Sie*), Indonesian in *kamu* (354), Turkish in *siz* (about 180) with client-facing texts kept polite; gender-neutral client wording in de/fr/es/pt/it; pt-PT without *você*, with *desmarcar*; en American and en-GB with 34 overrides; counted nouns through `term.*.count` (Arabic six forms, "12 Kundschaft" gone); one word per glossary term (aftercare, add-ons, patch test, treatment record, follow-up, subscription...); stale facts of D44 to D55 rewritten; profession names without slashes. New gates: `check-strings.sh --final` (style per localization, glossary, templates, navigation-title lists, `needs_review` only where listed), `NavigationTitleFitTests`, `LocalizationScreenshotUITests` (Full plan), `ClientTermCountTests`, functions and web ICS/email tests per localization, `import-strings.sh --self-test`; `merge-strings.py` refuses duplicate keys and merges InfoPlist batches. Reviewer round trip: export → `import-strings.sh <id> <csv> --reviewed` → batches + `Config/Locale/reviewed/` (`docs/review/README.md`, one file per wave-1 language). Message templates 14 × 16 kinds. Legal `2026-10-2` for the four documents in 14 localizations (EU = GDPR core + national annexes, `legal/EUROPE.md`; pt-BR LGPD); versions compared as numbers.
UI fixed: long navigation titles inline on settings-like and request screens (pt-BR 2.10 "Pedido de agendamen…" and ~25 others); FlowLayout keeps one-line chips at their natural width; recovery-key words in two columns (three cut "mountain"); the UI-test seed takes the `-uiLocale` language (More showed the English profession).
Measured: iOS fast 2095 tests in 295 suites (with `check-strings.sh --final`, the import round trip, legal, professions, health forms gates; strings 2232 keys + 5 InfoPlist in 14 localizations); smoke 48 UI tests (47 passed + 1 skipped tool; `CalendarUITests` rerun after its slot fix); `LocalizationScreenshotUITests` 3 tests green in all 14 localizations (213 screenshots, 33 min; de/ar rerun on the final head); every audit suite (14 suites, 38 tests, en/pt-BR/de/ar/hi, default and AX5) green after the fixes; `check-warnings.sh` zero warnings (simulator, device, Release, test targets). Functions unit 943 (ICS and email per localization). Web `test-web.sh full`: i18n 14 localizations 401 keys 0 problems, contrast 152/152, unit 248, Playwright 191 passed + 15 skipped, Lighthouse 0.99/1.00 on both pages, initial JS 48.4 KB gzip.
Deployed: Hosting to dev 2026-10-10 (web strings, legal texts, numeric legal version sort; page 200, `/api/getPublicPage` NOT_FOUND for an unknown slug). Functions not redeployed: only their tests changed.
Open: on today's day view a tap on an hour already past did not open New appointment and the day jumped to Monday (smoke at 11:35 in São Paulo; the UI test now taps an hour ahead; S12); Help and Privacy describe a per-client export/delete under Edit that the Edit screen lacks (`help.topic.deleteClient.answer`, `privacy.perClient.subtitle`; S12); every non-English string stays `needs_review` (no native reader, D41); the clipped-text audit skips Arabic and Devanagari (read by eye in the screenshots); Arabic tab title is the indefinite عملاء because the same plural is used inside sentences.
Human tasks: H10/H11 point at `docs/review/` and `legal/EUROPE.md`.

### S8 leftovers + S12 prep · done 2026-10-10 · merged into build/v1 at cf9d249 (no tag)
**2026-10-10: S8 leftovers, security-review gaps and S12 documentation, performance and accessibility done on
`s8-leftovers`** (notes `docs/agent-notes/s8-leftovers.md`, reviews `docs/agent-notes/security-review.md` and
`docs/agent-notes/accessibility-audit.md`). Server account deletion (resumable after a half-finished attempt) and
server plan verification (`appAccountToken` + `syncPlan`); client data deletion reaches the server through the
outbound queue ("Delete data" in 4.3); the registration count asks `reserveRegistrations` (ledger as cache, offline
replay); the page's inbox key is checked against the derived one (`keyMismatch` stops publishing) and Privacy shows
the form key; store protection set explicitly; recovery words hidden while recorded or shared; "From your clients"
in Alerts (check-ins with their photo, data requests, unopened forms) acknowledges each item; "Suggest another time"
on booking requests (new function `suggestBookingTime`, emulator tests; **needs a functions deploy**); "Cancels
often" on waitlist and requests. Unit suites for `MailboxService`, `PushService`. S12: `PrivacyInfo.xcprivacy`
(+ `check-privacy.sh` rule 7), App Privacy answers, App Store metadata in 13 localizations (`docs/store/`),
`PerformanceUITests` (cold start 1.39 s to Welcome, search over 2,000 clients 12 ms, peak 97 MB with 200 photos;
bounded full-size photo cache), `AccessibilityAuditUITests` (en and pt-BR, default and AX5, Increase Contrast and
Reduce Motion: clean after fixes; VoiceOver pass list for a device), breach plan `docs/BREACH-PLAN.md` (H18).
Fast 2179 tests in 309 suites, check-warnings zero, test-firebase green. Open: App Check (H5), hitch measurement and
the VoiceOver pass on a device, H14 before the server lifts the 10-client limit for a sandbox purchase.

Integration (S12 agent, 2026-10-10 17:10 to 17:45): merge `cf9d249` had no textual conflict; on the merged head `scripts/test.sh fast` 2179 tests in 309 suites passed, `scripts/check-warnings.sh` zero warnings (simulator, device, Release, test targets), `scripts/test-firebase.sh` green (unit 943, rules 66, use cases 289, transport 19), `scripts/test-web.sh full` green (i18n 401 keys, contrast 152/152, unit 248, Playwright 191 + 15 skipped, Lighthouse 0.99/1.00, initial JS 48.4 KB). The server contract changed on the helper's side only, so no regeneration was needed. **Deployed to dev:** all functions (new `suggestBookingTime` created) and Hosting; smoke: page 200, `/api/getSlots` answers (INVALID_ARGUMENT for a bad body), `/api/getPublicPage` NOT_FOUND for an unknown slug.

### S12 · Hardening and release readiness · done 2026-10-11 · tags stage-S12, v1.0.0-rc1
Done (`docs/agent-notes/s12-release.md`): the `s8-leftovers` merge stabilized and deployed (functions incl. `suggestBookingTime`,
Hosting); S11 bugs: the "past hour jumps to Monday" was a UI-test tap under the pinned week strip (the app opens a past
hour; helper fixed, hour-row rule unit-tested), per-client **Export data** under Edit (Help and Privacy now true, 14
localizations), "Created by " name; found and fixed: **Apple Calendar write-through** (the switch promised it; nothing wrote
events) and the missing **`NSCalendarsFullAccessUsageDescription`** (asking EventKit without it ends the app),
`InfoPlistUsageTests`, "Continue with phone" hidden where the provider cannot send codes (H20), launch screen in the page
colour, `BookingImporterTests`; accessibility audit in every Full run (en, Increase Contrast, Reduce Motion); security
re-check table (`security-review.md` section 6); App Store metadata lengths re-checked; TestFlight notes; README; H19 to
H22, D57 (v1 keeps manual WhatsApp and the e-mail code; no SMS, no Cloud API). Merged on the way: PR #1 (graphite and
orange palette, by the co-owner) and `link-copy` (press and hold the booking link on Account to copy it).
Measured on the old palette (head `7adf166`..`c642bdf`): `scripts/test.sh full` 5 h 43 min: unit 2,200 tests in 313
suites passed; UI 103 tests: 94 passed, 6 skipped (5 opt-in performance, 1 opt-in color review), 3 failed, all audit
walks losing a row after an AX5 audit re-laid a lazy list out or dragging a sheet closed (BookingSetup availability,
More record fields, Services catalog); the walks were fixed and the suites re-run on the final head (below).
`LocalizationScreenshotUITests` green (14 localizations 31 min, Arabic mirroring, double-length pseudolanguage).
`AccessibilityAuditUITests` en + pt-BR, default and AX5, Increase Contrast and Reduce Motion: clean.
`PerformanceUITests` (simulator, Debug): cold start 1.26 s to Welcome (budget 1.5), search over 2,000 clients 12 ms
(150), peak memory with 200 photos 96 MB (250); hitches, week render, photo save, vault timing: device (H19).
`check-warnings.sh` zero warnings; `test-firebase.sh` unit 943, rules 66, use cases 289, transport 19; `test-web.sh full`
unit 248, Playwright 191 + 15 skipped, Lighthouse 0.99/1.00, JS 48.4 KB gzip; `e2e-local.sh` 7 passed.
POSTPRPLACEHOLDER
Deployed to dev: functions (all, `suggestBookingTime` created) and Hosting on 2026-10-10, smoke OK; nothing under
`firebase/` or `web/` changed afterwards, so no redeploy at the end.
Human tasks created: H19, H20, H21, H22; H13 rewritten (post-v1), H7 marked critical.

## Assumptions
| # | Assumption | Reason | Stage |
|---|---|---|---|
| ASSUMPTION-1 | `bello-hub` is treated as an environment of unknown role: only the empty database and deny-all rules are deployed to it. Real rules, functions and hosting are never deployed until `dev` and `staging` exist; all S8 and S9 tests run on the emulators | The brief allows real deploys to dev and staging only, and prod only gets the empty database and deny-all | S0 |
| ASSUMPTION-2 | Crashlytics and its dSYM upload phase were removed | `docs/04-ARCHITECTURE.md` section 8: no Analytics and no Crashlytics in v1, so no client text can leak through telemetry | S0 |
| ASSUMPTION-3 | The unused Sign in with Apple entitlement was removed from `BelloHub.entitlements`, and the file moved to `SupportFiles/` | The professional signs in with a phone code (D3, `04` section 3); `CLAUDE.md` section 3 puts entitlements in `SupportFiles/` | S0 |
| ASSUMPTION-4 | `scripts/check-privacy.sh` allows Firebase imports in `Managers/Booking`, `Managers/Session` and `Managers/Firebase` (bootstrap only) | `docs/04` places `FirebaseAuthProvider` in `Managers/Session`, while `docs/13` section 4 lists only `Managers/Booking` | S0 |
| ASSUMPTION-5 | `firebase.json` and `.firebaserc` live in `firebase/`, not the repo root | `docs/11` section 1 repo layout | S0 |
| ASSUMPTION-6 | The single `GoogleService-Info.plist` stays in `SupportFiles/` and keeps the app bundle test working | No per-environment projects exist yet | S0 |
| ASSUMPTION-7 | `2.5 More` (a tab root) is built in S3 with the shell; it appears in no stage list of `03-BUILD-PLAN.md` | The five-tab `MainView` is S3 | S0 |
| ASSUMPTION-8 | Local Node is v26; Cloud Functions will declare Node 22 in `engines` as the docs say | Installed toolchain differs from the target runtime | S0 |
| ASSUMPTION-9 | Pure localization types (`AppLocalization`, `RegionPreset`, `RegionCatalog`, `PhoneNormalizer`, `PhoneFormatter`, `DigitNormalizer`, `BidiIsolate`, `Formatters`, `WeekConfig`) live in `Models/Locale/` (Foundation only); only the bundle loader is in `Managers/Locale/` | `CLAUDE.md` section 2: Models are pure, Managers touch the outside world. `docs/04` draws them all under `Managers/Locale/` | S1 |
| ASSUMPTION-10 | Strings are authored as batch files (`Config/Locale/strings/*.json`, twelve native languages per row) and merged into the catalog by `scripts/merge-strings.py`, which derives `es-419` and `en-GB`. The catalog stays the committed artifact | Writing 14 languages by hand in the catalog JSON does not scale to about 1,500 keys | S1 |
| ASSUMPTION-11 | `Config/App-Info.plist` carries the keys `INFOPLIST_KEY_*` cannot express (`CFBundleLocalizations`, `UIBackgroundModes`) and is referenced by `INFOPLIST_FILE` in `App.xcconfig` | Measured: `INFOPLIST_KEY_UIBackgroundModes` produced nothing | S1 |
| ASSUMPTION-12 | `Palette.accent` is `roseText`; the tab bar tint is `ink` | The prototype's selected tab is graphite; rose is for links and actions | S1 |
| ASSUMPTION-13 | Fonts are registered at launch with `CTFontManagerRegisterFontsForURL` (`FontRegistry`), not through `UIAppFonts` | `UIAppFonts` is an array that xcconfig keys cannot express and the Info.plist fragment would duplicate the list | S1 |
| ASSUMPTION-14 | Strings with arguments use `LocalizedStringResource("semantic.key", defaultValue: "...\(arg)")`, never `Text("key \(arg)")` | The latter looks up the key `key %@`, which does not exist (found in the catalog) | S1 |
| ASSUMPTION-15 | `docs/strings/message-templates.json` is extended in S6, where the messages are first used; the glossary was extended in S1 as the build plan says | The templates have no consumer before S6 | S1 |
| ASSUMPTION-16 | A **new client who books online after the free registrations are used, without a plan**, arrives as "waiting for approval" (`Bk-10-Review`) and the paywall appears when the professional approves | The owner asked for the limit on online booking too, but a professional is not present at booking time; this never loses a request and never blocks existing clients | S2 |
| ASSUMPTION-17 | The server counter is the authority; the iCloud ledger (ids and dates only) backs it up and the app uses the larger count; offline the cached count is used and the server reconciles by client id | Survives reinstall and a new device with the same Apple ID even offline, and cannot be reset by deleting local data | S2 |
| ASSUMPTION-18 | **Open question for the owner:** deleting the whole account and signing up again with the same phone number would start a new count of 10. v1 does not keep a tombstone (a stored hash of the phone and the count) because that would hold data after an erasure request | Avoids retaining personal data after account deletion; say if you prefer the tombstone (needs a line in the privacy policy) | S2 |
| ASSUMPTION-19 | Contact and spreadsheet imports go through the same gate: an import stops at the remaining free slots and offers the paywall for the rest | "Every way a client is created" | S2 |
| ASSUMPTION-20 | The paywall is the `Plan` screen opened as a sheet, not a new screen; other storefronts than EUR, USD and BRL use Apple's equalized price (the owner can set them in App Store Connect) | Keeps the 97-screen scope; the owner gave three regions | S2 |
| ASSUMPTION-21 | The vault is one SwiftData table (`VaultItem`) with clear index columns, plain JSON and a sealed sensitive part | The CloudKit schema only grows; a new kind of record is a new `kindRaw`, not a new CloudKit field | S2 |
| ASSUMPTION-22 | A health form from the mailbox is deduplicated by `importedFromItemID`, kept in a clear index column (an opaque id, not content) | Idempotent import after a crash between import and acknowledge | S2 |
| ASSUMPTION-23 | Concurrent edits of the same record on two devices resolve last-writer-wins for the whole record | One JSON value per record; the second device is usually idle; to be confirmed on two phones (spike checklist step 4) | S2 |
| ASSUMPTION-24 | The legal texts are shipped as bundle resources and shown in the app by `textVersion` (the file name, `2026-10`); a change is a new file and each acceptance stores the version it accepted | Old versions must stay readable for the record, and consent is only meaningful for the exact text shown | L |
| ASSUMPTION-25 | One text per localization serves every market that localization covers (for example `en-GB` for the United Kingdom, Ireland, Australia, New Zealand and South Africa; `de` for Germany, Austria and Switzerland; `ar` for Saudi Arabia and the UAE), with the regulators of each named inside | Fourteen localizations is the product's scope (D41); a text per country would be about 40 sets nobody can review | L |
| ASSUMPTION-26 | The lock grace period defaults to 60 seconds (options 0, 30, 60, 300, 900); a cold launch always locks. The setting screen arrives with Privacy and security (S10); the key exists now (`lock.graceSeconds`) | A professional switching to WhatsApp and back must not be asked for her face every time, yet a borrowed phone must lock quickly | S3 |
| ASSUMPTION-27 | The profile, tags and record template are stored in the clear in the vault (no sensitive keys): field and tag names, region and language are not clinical | `docs/05` lists tags among the unencrypted fields; what she writes in the fields is sealed in `TreatmentRecord` | S3 |
| ASSUMPTION-28 | The setup draft is not saved across a killed app: the setup saves everything together on the last tap and a relaunch before it starts over | There is nothing to protect before a vault key exists, the setup takes a few minutes, and saving partial drafts would create duplicate services on re-run. Revisit if testers lose progress | S3 |
| ASSUMPTION-29 | The first sign-in on a phone creates the vault key (`createIfMissing: true`); a phone that has lost its key after setup shows "No key on this iPhone" on the Locked screen and restores it in S10 | A first sign-in cannot have records to lose; silently starting a new vault later would orphan them | S3 |
| ASSUMPTION-30 | Sign out lives in More until the Account screen exists (S10) | A tester needs to switch users, and the stage list has no earlier home for it | S3 |
| ASSUMPTION-31 | Debug builds sign in with any phone number and the code `123456` (`LocalDevAuthProvider`); Release builds say sign-in is unavailable until S8 adds Firebase | The whole app must be usable before the server exists, and a Release build must never carry a shortcut | S3 |
| ASSUMPTION-32 | The "Aftercare" switch of a custom service stores an empty aftercare template (on, words to be written later) | `Service.aftercareTemplate` is optional text; no separate flag existed | S3 |
| ASSUMPTION-33 | German uses "Kunde/Kundin" for one client and "Kundschaft" for several and for the tab | The glossary's collective noun does not fit a sentence about "each" client; "pro Kunde/Kundin" does | S3 |
| ASSUMPTION-34 | "Use passcode" on the Locked screen runs the same system prompt as the Face ID button: the system offers the passcode after a failed face | `LocalAuthentication` has no call that jumps straight to the passcode | S3 |
| ASSUMPTION-35 | "New" on a client means no completed visit yet | The only list rule not owned by `HabitsCalculator` or `FollowUpPlanner` | S4 |
| ASSUMPTION-36 | Merging two clients: the kept profile wins and the other fills the gaps; lists join without duplicates; two notes become two paragraphs; booking stays stopped if either had it stopped; the registration ledger is never touched | A merge must lose nothing and never change the D42 count | S4 |
| ASSUMPTION-37 | The client form, not the D42 gate, catches a phone clash on an edit | The gate treats the same id as an edit before it looks at the phone | S4 |
| ASSUMPTION-38 | Client edit and knowledge are pushed with Cancel; only New client is a sheet | `ClientsRoute` models them as stack routes | S4 |
| ASSUMPTION-39 | Contacts come from the system contact picker, with no contacts permission flow; only the restricted state is explained | The picker hands over only the ticked contacts, stricter than any access level | S4 |
| ASSUMPTION-40 | Import reads CSV only in v1; the row says so | `.xlsx` needs its own zip and XML reader | S4 |
| ASSUMPTION-41 | One health form template per professional (one version sequence), not per profession | `HealthForm.formVersion` is one number and the mailbox carries one | S4 |
| ASSUMPTION-42 | A patch test is its own sealed vault kind `patchTest` | A health form or consent has no product or result | S4 |
| ASSUMPTION-43 | Health form questions are never pre-answered | A silent "no" on a health form is a clinical risk | S4 |
| ASSUMPTION-44 | A consent text is filled with her current business name when shown, not stored | Placeholders are filled at display; operator fields wait for H17 | S4 |
| ASSUMPTION-45 | The app never shows the word "draft" on legal texts; `legal.draftNote` was removed at integration | `legal/STATUS.md` | S4 |
| ASSUMPTION-46 | Record fields save as she goes; a field with data keeps it when switched off or deleted; S7 keys saved values by field `key` | Nothing lost on Back; saved records stay readable | S4 |
| ASSUMPTION-47 | Titles and counts avoid the client term ("Tags", "2 people") | The term would need several grammatical forms in twelve languages | S4 |
| ASSUMPTION-48 | Deleting a tag removes it from every client, archived included, in one write | The warning count must equal what changes | S4 |
| ASSUMPTION-49 | Contraindications use the health-form catalog's tokens, plus "Under 18"; an unknown token is kept as written | The matcher can decide every offered token in all 14 catalogs | S5 |
| ASSUMPTION-50 | The professional registration number is a `Credential` of kind `registration`; the "show on page" switch is stored per credential | docs/05 stores it per credential | S5 |
| ASSUMPTION-51 | Names of services, add-ons and products (same brand) are unique ignoring case and accents, 60 characters | Avoids two identical rows | S5 |
| ASSUMPTION-52 | A switched-off service stays in her list and is hidden from the agenda and booking page (S6 and S8 read `isActive`) | Deleting would lose history | S5 |
| ASSUMPTION-53 | Until she saves, Availability shows a starting week (Mon to Fri, 09:00 to 18:00) and stores nothing | An empty week would mean nobody can book her | S5 |
| ASSUMPTION-54 | The slug is a local preference until S8; the server decides ownership when she goes online | No networking before S8 | S5 |
| ASSUMPTION-55 | A saved policy applies to bookings made afterwards; each booking keeps its snapshot (the document wins over the prototype footer) | `CancellationEvaluator` | S5 |
| ASSUMPTION-56 | No-show counting period options are 3, 6 and 12 months | The model's `countingMonthOptions` | S5 |
| ASSUMPTION-57 | Quick replies are written in the business language on first open, with fixed ids so devices agree; then they are hers | Locale-aware defaults | S5 |
| ASSUMPTION-58 | A pause with a return date ends the morning of that date in the business time zone; a past return date is dropped | D15 | S5 |

## Conventions learned while building (read before writing code)
- Agent concurrency (owner request): at most 3 agents at a time from the next task on (the six running agents of S4, backend and web finish first); a stage with more slices runs in waves of three.
- Agent effort (owner-approved, from S5): `high` by default, `xhigh` for security and privacy slices (rules, counters, sealed envelopes, health and consent, vault), `medium` for mechanical work (strings, legal sync, lint, docs), `max` only for a hard bug already retried.
- **Agent effort (owner rule, 2026-10-09, overrides the line above): no agent on any model above `medium`** (never `high`, `xhigh` or `max`), to save tokens.
- Parallel work: the owner asked for parallel agents on every stage. Commit a shared contract first (protocols, DTOs, routes, fakes), then one agent per slice with `isolation: worktree`, a distinct existing simulator each (`SIM_UDID`), no edits to PROGRESS.md, DESIGN.md or the generated string catalog (`docs/agent-notes/<slice>.md` instead). Integrate by merging branches, regenerating the catalog with `scripts/merge-strings.py`, deleting `Screens/Clients/Placeholders/`, then fast, smoke and `check-warnings.sh` on the merged result.
- Strings: semantic keys; arguments through `LocalizedStringResource` with a default value; batches in `Config/Locale/strings/`; `scripts/check-strings.sh` is the gate (`Config/Locale/README.md`).
- Accessibility identifiers go on elements, never on containers.
- Tests: Swift Testing for logic, XCUITest through `XCUIApplication.launchedForUITests(locale:largestText:arguments:)`; the heavy audit lives in `DesignCatalogAuditUITests`, skipped by UISmoke.
- UIKit trait mutation in tests needs `@MainActor` (Swift 6 warns otherwise).
- Screenshots of the catalog on the simulator are the fastest way to see a layout: `xcrun simctl launch <udid> com.bellohub -uiTesting -designCatalog -catalogSection components -uiLocale ar`.

## Proposed changes to CLAUDE.md
(none yet)

## Design additions (for the designer to review)
| Screen | Addition | Why | Screenshot |
|---|---|---|---|
| 7.8 ExportAll | Delivery copy changed to Save to Files / share (no email link) | D18 | |
| 7.5 AISettings | "Cloud help" row disabled, "Not available yet"; review toggle locked on | D23 | |
| 2.4 Notifications / 2.1 Home | "Reminders ready" section | D31 | |
| 8.8 Bk-8-Confirmed | Channel-dependent confirmation copy | D31 | |
| 4.2 NewClient / 4.6 ImportClients | The free-registration explainer ("Your first 10 client registrations are free. Deleted clients still count toward this limit.") and the "x of 10 used" counter | D42 | |
| 7.3 Plan | No trial; free usage "x of 10 used"; one plan with monthly and yearly options, localized StoreKit prices, the yearly saving highlighted; opens as the paywall when the 11th client is added | D33, D42 | |
| 7.11 States | "Plan ended" state becomes "Free registrations used" (existing data stays available) | D42 | |
| 2.10 BookingRequest | New reason: a new client waits because the free registrations are used; approving shows the paywall | D42 | |
| 1.x About you (new) | First setup step: name and optional business name; the prototype greets her by name but never asks | S3 | |
| 1.2 SignIn | No "Use email instead" (phone code only, D3); "Create your workspace" heading when she came from Get started | D3, S3 | |
| 1.6 Terminology | A "What do you call the people you see?" choice (client, patient, student, guest) above the names list | docs/07 section 4, S3 | |
| 1.3 to 1.8 | Progress bar has six segments (About to Record) instead of four | S3 | |
| 1.10 Ready | Booking link card says "Ready once you go online" (needs the server, S8); the import shortcut is hidden until S4 | S3 | |
| 2.1 to 2.4 | Honest empty states without a button until each screen is built | S3 | |
| 2.2, 4.1 to 4.4 | Archived chip and Restore row; merge picker; inline duplicate notice; stale-data warning; "no longer here" state; neutral copy ("First visit") | S4, ASSUMPTION-35 to 38 | |
| 4.5 | Review status chip; consent rows open the signed text; minors notice; health form, patch test and signed text sheets; "Send form again" waits for S8 | S4, D17 | |
| 4.6 | Column-mapping screen, "can't be imported" list, partial-import notice, "n more need a plan" card; CSV only | S4, D42 | |
| 6.12, 6.13 | Named tag colors; record fields save as she goes (no Save bar); her own fields renamed, reordered, switched off | S4 | |
| 6.14 | Consent texts read-only and versioned with a language menu; 3/6/12/24 months; no "draft" wording | S4, ASSUMPTION-45 | |

## Screen traceability (97 screens; status: todo / in-progress / done / deferred)
Generated from `docs/screens/SCREENS.md`; stage from `docs/03-BUILD-PLAN.md`.

| Id | Screen | Stage | Status | Notes |
|---|---|---|---|---|
| 1.1 | Onb-1-Welcome | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.2 | SignIn | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.3 | Onb-2-Profession | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.4 | Onb-3-Services | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.5 | Onb-4-CustomService | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.6 | Onb-5-Terminology | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.7 | Onb-6-Tags | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.8 | Onb-6b-Record | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.9 | Permissions | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.10 | Onb-7-Ready | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 1.11 | Locked | S3 | done | `OnboardingUITests`, `OnboardingAuditUITests` |
| 2.1 | Home | S6 | done | `HomeUITests`, `HomeAuditUITests` |
| 2.2 | Clients | S4 | done | `ClientsUITests`, `ClientsAuditUITests` |
| 2.3 | Calendar | S6 | done | `CalendarUITests`, `CalendarAuditUITests` |
| 2.4 | Notifications | S6 | done | local alerts; server alerts in S8 |
| 2.5 | More | S3 | done | Profile card, Lock now, Sign out; Clients section (S4); Business and Messages rows wired to S5 placeholders |
| 2.6 | WeekGlance | S6 | done | `CalendarAuditUITests` |
| 2.7 | FollowUps | S6 | done | `HomeAuditUITests` |
| 2.8 | WinBack | S6 | done | `HomeAuditUITests` |
| 2.9 | Waitlist | S8 | done | `InboxUITests`, `InboxAuditUITests` |
| 2.10 | BookingRequest | S8 | done | `InboxUITests`, `InboxAuditUITests` |
| 2.11 | RescheduleRequest | S8 | done | `InboxUITests`, `InboxAuditUITests` |
| 2.12 | RunningLate | S6 | done | `AppointmentAuditUITests` |
| 3.1 | NewAppointment | S6 | done | `CalendarUITests` |
| 3.2 | Appointment | S6 | done | `AppointmentUITests` |
| 3.3 | BeforeYouStart | S6 | done | `AppointmentAuditUITests` |
| 3.4 | Reschedule | S6 | done | `CalendarUITests` |
| 3.5 | CancelAppointment | S6 | done | `AppointmentUITests` |
| 3.6 | MessageClient | S6 | done | `AppointmentAuditUITests` |
| 6.6 | BlockTime | S6 | done | `CalendarAuditUITests` |
| 3.7 | NoShowMark | S6 | done | `AppointmentUITests` |
| 4.1 | ClientProfile | S4 | done | `ClientsUITests`, `ClientsAuditUITests` |
| 4.2 | NewClient | S4 | done | `ClientsUITests`, `ClientsAuditUITests`; D42 gate |
| 4.3 | ClientEdit | S4 | done | `ClientsAuditUITests`; merge |
| 4.4 | ClientKnowledge | S4 | done | `ClientsAuditUITests` |
| 4.5 | ClientHealth | S4 | done | `HealthUITests`, `HealthMinorUITests`, `HealthAuditUITests`; D55 consent records (`ConsentRecordViewModelTests`) |
| 4.6 | ImportClients | S4 | done | `ImportClientsUITests`, `ImportAuditUITests` |
| 4.7 | RecordHistory | S7 | done | `Screens/Records/History/` (S7 record slice, `docs/agent-notes/s7-record.md`); `RecordUITests`; trail name follows the profile (S12) |
| 4.8 | SessionPlan | S6 | done | `AppointmentAuditUITests` |
| 4.9 | Incident | S7 | done | `Screens/Records/Incident/`; `RecordUITests.testIncidentFromTheProfileIsSaved` |
| 4.10 | ExportRecord | S7 | done | `Screens/Records/Export/`; from the profile and, since S12, from Edit ("Export data"); `RecordUITests.testExportBuildsAClientCopyWithoutPrivateNotes` |
| 4.11 | NoShowHistory | S6 | done | `AppointmentAuditUITests` |
| 5.1 | Tx-1-Register | S7 | done | `TreatmentFlowUITests` |
| 5.2 | Tx-2-Listening | S7 | done | `TreatmentFlowUITests` |
| 5.3 | Tx-3-Organizing | S7 | done | `TreatmentFlowUITests` |
| 5.4 | Tx-4-Review | S7 | done | `TreatmentFlowUITests` |
| 5.5 | Tx-Form | S7 | done | `TreatmentFlowUITests` |
| 5.6 | Tx-5-Saved | S7 | done | `TreatmentFlowUITests` |
| 5.7 | Tx-6-Photos | S7 | done | `TreatmentFlowUITests` |
| 5.8 | Camera | S7 | done | `TreatmentFlowUITests` |
| 5.9 | Tx-7-NextSession | S7 | done | `TreatmentFlowUITests` |
| 6.1 | Services | S5 | done | `ServicesUITests`, `ServicesAuditUITests` |
| 6.2 | ServiceEdit | S5 | done | `ServicesUITests` |
| 6.4 | Products | S5 | done | `ServicesAuditUITests` |
| 6.5 | Availability | S5 | done | `BookingSetupUITests`, `BookingSetupAuditUITests` |
| 6.7 | BookingSettings | S5 | done | `BookingSetupUITests`, `BookingSetupAuditUITests` |
| 6.8 | ShareLink | S5 | done | `BookingSetupUITests`; live in S8 |
| 6.9 | QuickReplies | S5 | done | `BookingSetupUITests` |
| 6.10 | Credentials | S5 | done | `ServicesAuditUITests` |
| 6.11 | Team | S5 | done | static |
| 6.12 | Tags | S4 | done | `MoreUITests`, `MoreAuditUITests` |
| 6.13 | RecordTemplate | S4 | done | `MoreUITests`, `MoreAuditUITests` |
| 6.14 | FormTemplates | S4 | done | `FormTemplatesUITests`, `HealthAuditUITests` |
| 6.3 | AddOns | S5 | done | `ServicesUITests` |
| 6.16 | CancelPolicy | S5 | done | `BookingSetupUITests` |
| 6.15 | NoShowPolicy | S5 | done | `BookingSetupUITests` |
| 7.1 | Account | S10 | done | `AccountUITests`, `AccountAuditUITests` |
| 7.2 | LanguageRegion | S10 | done | `AccountUITests` |
| 7.3 | Plan | S10 | done | `AccountUITests` (buy, paywall at the 11th) |
| 7.4 | NotificationSettings | S10 | done | `AccountAuditUITests` |
| 7.5 | AISettings | S7 | done | stub (D53); row in More → Preferences |
| 7.6 | Integrations | S10 | done | `AccountAuditUITests` |
| 7.7 | Privacy | S10 | done | `AccountAuditUITests` |
| 7.10 | Help | S10 | done | `AccountAuditUITests` |
| 7.11 | States | S6 | done | shared States |
| 7.8 | ExportAll | S10 | done | `AccountAuditUITests` |
| 7.9 | RecoveryKey | S10 | done | `AccountUITests` (reveal, confirm, restore) |
| 8.1 | Bk-1-Page | S9 | done | `booking.spec` (pause, approval notice), `languages`, `a11y`; S9 added the approval notice |
| 8.2 | Bk-2-Service | S9 | done | `booking.spec` @core (add-on + guest count) |
| 8.3 | Bk-3-Professional | S9 | done | Route exists and redirects (no team in v1) |
| 8.4 | Bk-4-DateTime | S9 | done | `booking.spec` (taken, waitlist, **offer link `?offer=`**, S9), `interaction` |
| 8.5 | Bk-5-Info | S9 | done | booking flows, `rtl` |
| 8.6 | Bk-6-Verify | S9 | done | e-mail code only (D46); `booking.spec` |
| 8.7 | Bk-7-Questions | S9 | done | optional note only (D45) |
| 8.8 | Bk-8-Confirmed | S9 | done | `booking.spec` (ICS/Google D50, health card by `intakeRequired`, S9) |
| 8.9 | Bk-9-Appointment | S9 | done | `manage.spec` |
| 8.10 | Bk-10-Review | S9 | done | `booking.spec` (approval, no-show) |
| 8.11 | Bk-11-Find | S9 | done | `booking.spec` (e-mail + code) |
| 9.1 | Cl-1-Reminder | S9 | done | Picture of a WhatsApp message (message templates), not a web page; destinations exist |
| 9.2 | Cl-2-Portal | S9 | done | `portal.spec` (D52: no form links) |
| 9.3 | Cl-3-Rebook | S9 | done | `portal.spec` |
| 9.4 | Cl-4-Intake | S9 | done | `sealed.spec`, vectors both ways; S9: the app now publishes her form (`PublishIntakePayloadTests`) |
| 9.5 | Cl-5-CheckIn | S9 | done | `sealed.spec`; S9: the app reads the sent time (`PayloadInstant`) |
| 9.6 | Cl-6-Cancel | S9 | done | `manage.spec`, e2e-local |
| 9.7 | Cl-7-MyData | S9 | done | `sealed.spec`; label "Health form" (D55) |
| 9.8 | Cl-8-Reminder | S9 | done | Picture of a WhatsApp message (message templates), not a web page; destination `/m/{token}` |
| 9.9 | Cl-9-Reschedule | S9 | done | `manage.spec`, e2e-local |

## Pull request text for phase A (S0 to S2), to open into `main`
`gh` is not logged in (H17), so open it at https://github.com/mfmansueli/BelloHub/pull/new/build/v1 with this body:

> **Phase A: foundation (S0 to S2).** Adopts the handoff, the design system, localization infrastructure and the vault.
> - S0: handoff docs, entitlements (iCloud, push, App Attest), Firestore `eur3` with deny-all rules, privacy and settings checks.
> - S1: tokens, motion kit, components, Design Catalog with accessibility audit, fourteen localizations with check/derive/merge scripts, region presets, phone and digit handling, formatters.
> - S2: domain and pure rules, vault encryption (AES-GCM, key derivation pinned by independent vectors, 12-word recovery), SwiftData vault with contract tests, migration test and on-disk sentinel test, registration quota (D42), sync status, SwiftData and CloudKit spike.
> Decisions recorded: D40 (open every market, legal after sales), D41 (no human language review), D42 (first 10 registrations free, no trial).
> Tests: 302 unit, 3 UI smoke, accessibility audit in five languages at AX5; zero warnings on simulator, device, Release and the test targets.
> Not yet done by a human: see `docs/14-HUMAN-TASKS.md` (Firebase dev and staging projects, domain, App Store Connect, real-device checks).

## Spikes and reports
- `docs/spikes/SPIKE-swiftdata-cloudkit.md`: written in S2 (verdict GO; two-iPhone checklist for H3)
- `docs/spikes/VOICE-LANGUAGE-MATRIX.md`: (S7)

## Release checklist
Done: `docs/13-TESTING-QUALITY.md` section 8 is checked item by item with evidence (S12, 2026-10-11).
