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
`S4` (clients and the client record) · started: 2026-10-08 · branch: `build/v1` · `L` (legal drafts) is done, tag `stage-L`; S3 is done

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
| 1.x About you (new) | First setup step: name and optional business name; the prototype greets her by name but never asks | S3 | |
| 1.2 SignIn | No "Use email instead" (phone code only, D3); "Create your workspace" heading when she came from Get started | D3, S3 | |
| 1.6 Terminology | A "What do you call the people you see?" choice (client, patient, student, guest) above the names list | docs/07 section 4, S3 | |
| 1.3 to 1.8 | Progress bar has six segments (About to Record) instead of four | S3 | |
| 1.10 Ready | Booking link card says "Ready once you go online" (needs the server, S8); the import shortcut is hidden until S4 | S3 | |
| 2.1 to 2.4 | Honest empty states without a button until each screen is built | S3 | |

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
| 2.1 | Home | S6 | in-progress | Greeting and empty state exist since S3 |
| 2.2 | Clients | S4 | in-progress | Empty state with the term she chose since S3 |
| 2.3 | Calendar | S6 | in-progress | Empty state since S3 |
| 2.4 | Notifications | S6 | in-progress | Empty state since S3 (the tab is called Alerts) |
| 2.5 | More | S3 | done | Profile card, Lock now, Sign out; rows that open later screens arrive with those screens |
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
Mirror `docs/13-TESTING-QUALITY.md` section 8 and tick as achieved. Not started.
