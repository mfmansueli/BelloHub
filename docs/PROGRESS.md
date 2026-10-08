# PROGRESS

This file is the memory across context resets. Read it first in every session; update it at the end of every stage and whenever something notable happens. Humans read it to see what happened while they were away.

## Open questions for humans (top = most urgent)
Nothing here blocks the build; each item has a safe default in use.

1. **Only one Firebase project exists, not three.** `firebase projects:list` (logged in as the owner's account) shows a single project, `bello-hub` (number 73917800030), with one iOS app (`com.bellohub`). The brief expects `dev`, `staging` and `prod`. What I did: created the `(default)` Firestore database in `eur3` in `bello-hub` and deployed deny-all rules there, nothing else, because I cannot tell which environment it is meant to be. What I need: either create `dev` and `staging` (H4) or tell me `bello-hub` is dev. Until then every backend test runs on the emulators and nothing but deny-all rules is deployed (ASSUMPTION-1).
2. **Default Storage bucket not created.** Needs the Firebase console (Blaze plan) or `gcloud`, which is not installed on this Mac. `storage.rules` is committed (deny all). H4.
3. **Crashlytics removed (FYI, ASSUMPTION-2).** `docs/04-ARCHITECTURE.md` section 8 says no Analytics and no Crashlytics in v1, so I removed the Crashlytics product, its dSYM build phase, the crash-policy code and tests, and the README section the scaffold had. If Mateus wants crash reports, the proposal is MetricKit (S12) rather than a third-party SDK that can carry log text.
4. **`gh` is not logged in** and `origin` is `git@github.com:mfmansueli/BelloHub.git`. Pushing branches works only if this Mac's SSH key has access; opening pull requests needs `gh auth login` (H17).

## Owner decisions made during the build
| Date | Decision | Effect on the work |
|---|---|---|
| 2026-10-08 | **D40 Go-to-market:** open every market possible, formalize legal matters only after real sales appear; no gate on native reading or legal review. | Claude Code writes the legal documents of every market now (plan item L below). The market table below is information; the owner opens markets in App Store Connect. |
| 2026-10-08 | **D41 Languages:** no human review is planned; Claude Code does its best. | Every string stays `needs_review` (true, and not a gate). The S11 completeness checks stay; the "awaiting reviewers" list is simply every non-English string. |
| 2026-10-08 | **D42 Monetization:** first 10 client registrations free (cumulative; deleting never restores a slot; across manual, import and booking; duplicates and edits do not count), paywall on the 11th, existing data always accessible, counter at account level; one paid plan, monthly or yearly (EUR 14.99 / 149.99, USD 14.99 / 149.99, BRL 39.90 / 399.90), same features, **no 14-day trial** (D33 revised). | S2 builds `RegistrationQuota`, `PlanSavings` and the vault ledger; S4 the registration gate and the limit message; S8 the server counter and the booking branch; S10 the plan screen and the paywall with StoreKit. |

**Plan item L (legal drafting pass), right after S2:** for every market, the terms and data processing agreement, privacy policy, client notice, health-form consent, photo consent, guardian consent and data-subject-request wording, written as carefully as possible in the language of each region set (`docs/07-LOCALIZATION.md` section 8), versioned under `legal/<doc>/<localization>/<version>.md`, with `legal/STATUS.md` and `scripts/check-legal-status.sh`. Refined in S11 once the screens that show them exist. Marked `LEGAL-REVIEW` in the headers, never claiming compliance (`docs/06` section 12).

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
`S2` · started: 2026-10-08 · branch: `build/v1`

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

## Conventions learned while building (read before writing code)
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

## Screen traceability (97 screens; status: todo / in-progress / done / deferred)
Generated from `docs/screens/SCREENS.md`; stage from `docs/03-BUILD-PLAN.md`.

| Id | Screen | Stage | Status | Notes |
|---|---|---|---|---|
| 1.1 | Onb-1-Welcome | S3 | todo |  |
| 1.2 | SignIn | S3 | todo |  |
| 1.3 | Onb-2-Profession | S3 | todo |  |
| 1.4 | Onb-3-Services | S3 | todo |  |
| 1.5 | Onb-4-CustomService | S3 | todo |  |
| 1.6 | Onb-5-Terminology | S3 | todo |  |
| 1.7 | Onb-6-Tags | S3 | todo |  |
| 1.8 | Onb-6b-Record | S3 | todo |  |
| 1.9 | Permissions | S3 | todo |  |
| 1.10 | Onb-7-Ready | S3 | todo |  |
| 1.11 | Locked | S3 | todo |  |
| 2.1 | Home | S6 | todo |  |
| 2.2 | Clients | S4 | todo |  |
| 2.3 | Calendar | S6 | todo |  |
| 2.4 | Notifications | S6 | todo |  |
| 2.5 | More | S3 | todo | Tab root; rows that open later screens arrive with those screens |
| 2.6 | WeekGlance | S6 | todo |  |
| 2.7 | FollowUps | S6 | todo |  |
| 2.8 | WinBack | S6 | todo |  |
| 2.9 | Waitlist | S8 | todo |  |
| 2.10 | BookingRequest | S8 | todo |  |
| 2.11 | RescheduleRequest | S8 | todo |  |
| 2.12 | RunningLate | S6 | todo |  |
| 3.1 | NewAppointment | S6 | todo |  |
| 3.2 | Appointment | S6 | todo |  |
| 3.3 | BeforeYouStart | S6 | todo |  |
| 3.4 | Reschedule | S6 | todo |  |
| 3.5 | CancelAppointment | S6 | todo |  |
| 3.6 | MessageClient | S6 | todo |  |
| 6.6 | BlockTime | S6 | todo |  |
| 3.7 | NoShowMark | S6 | todo |  |
| 4.1 | ClientProfile | S4 | todo |  |
| 4.2 | NewClient | S4 | todo |  |
| 4.3 | ClientEdit | S4 | todo |  |
| 4.4 | ClientKnowledge | S4 | todo |  |
| 4.5 | ClientHealth | S4 | todo |  |
| 4.6 | ImportClients | S4 | todo |  |
| 4.7 | RecordHistory | S7 | todo |  |
| 4.8 | SessionPlan | S6 | todo |  |
| 4.9 | Incident | S7 | todo |  |
| 4.10 | ExportRecord | S7 | todo |  |
| 4.11 | NoShowHistory | S6 | todo |  |
| 5.1 | Tx-1-Register | S7 | todo |  |
| 5.2 | Tx-2-Listening | S7 | todo |  |
| 5.3 | Tx-3-Organizing | S7 | todo |  |
| 5.4 | Tx-4-Review | S7 | todo |  |
| 5.5 | Tx-Form | S7 | todo |  |
| 5.6 | Tx-5-Saved | S7 | todo |  |
| 5.7 | Tx-6-Photos | S7 | todo |  |
| 5.8 | Camera | S7 | todo |  |
| 5.9 | Tx-7-NextSession | S7 | todo |  |
| 6.1 | Services | S5 | todo |  |
| 6.2 | ServiceEdit | S5 | todo |  |
| 6.4 | Products | S5 | todo |  |
| 6.5 | Availability | S5 | todo |  |
| 6.7 | BookingSettings | S5 | todo |  |
| 6.8 | ShareLink | S5 | todo | Built in S5 against the fake; live in S8 |
| 6.9 | QuickReplies | S5 | todo |  |
| 6.10 | Credentials | S5 | todo |  |
| 6.11 | Team | S5 | todo | Static 'later' screen (D5) |
| 6.12 | Tags | S4 | todo |  |
| 6.13 | RecordTemplate | S4 | todo |  |
| 6.14 | FormTemplates | S4 | todo |  |
| 6.3 | AddOns | S5 | todo |  |
| 6.16 | CancelPolicy | S5 | todo |  |
| 6.15 | NoShowPolicy | S5 | todo |  |
| 7.1 | Account | S10 | todo |  |
| 7.2 | LanguageRegion | S10 | todo |  |
| 7.3 | Plan | S10 | todo |  |
| 7.4 | NotificationSettings | S10 | todo |  |
| 7.5 | AISettings | S7 | todo |  |
| 7.6 | Integrations | S10 | todo |  |
| 7.7 | Privacy | S10 | todo |  |
| 7.10 | Help | S10 | todo |  |
| 7.11 | States | S6 | todo | Shared state components |
| 7.8 | ExportAll | S10 | todo |  |
| 7.9 | RecoveryKey | S10 | todo |  |
| 8.1 | Bk-1-Page | S9 | todo |  |
| 8.2 | Bk-2-Service | S9 | todo |  |
| 8.3 | Bk-3-Professional | S9 | todo | Route exists and redirects (no team in v1) |
| 8.4 | Bk-4-DateTime | S9 | todo |  |
| 8.5 | Bk-5-Info | S9 | todo |  |
| 8.6 | Bk-6-Verify | S9 | todo |  |
| 8.7 | Bk-7-Questions | S9 | todo |  |
| 8.8 | Bk-8-Confirmed | S9 | todo |  |
| 8.9 | Bk-9-Appointment | S9 | todo |  |
| 8.10 | Bk-10-Review | S9 | todo |  |
| 8.11 | Bk-11-Find | S9 | todo |  |
| 9.1 | Cl-1-Reminder | S9 | todo | Picture of a WhatsApp message (message templates), not a web page |
| 9.2 | Cl-2-Portal | S9 | todo |  |
| 9.3 | Cl-3-Rebook | S9 | todo |  |
| 9.4 | Cl-4-Intake | S9 | todo |  |
| 9.5 | Cl-5-CheckIn | S9 | todo |  |
| 9.6 | Cl-6-Cancel | S9 | todo |  |
| 9.7 | Cl-7-MyData | S9 | todo |  |
| 9.8 | Cl-8-Reminder | S9 | todo | Picture of a WhatsApp message (message templates), not a web page |
| 9.9 | Cl-9-Reschedule | S9 | todo |  |

## Spikes and reports
- `docs/spikes/SPIKE-swiftdata-cloudkit.md`: (S2)
- `docs/spikes/VOICE-LANGUAGE-MATRIX.md`: (S7)

## Release checklist
Mirror `docs/13-TESTING-QUALITY.md` section 8 and tick as achieved. Not started.
