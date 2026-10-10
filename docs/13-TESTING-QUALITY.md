# 13 · Testing and quality

Tests are written **with** the feature (`CLAUDE.md` §6). This document adds the product-specific strategy, budgets and the final acceptance list.

## 1. Pyramid and plans

| Level | Tool | What | Plan |
|---|---|---|---|
| Pure rules | Swift Testing, table-driven | `RecordLockPolicy`, `HabitsCalculator`, `FollowUpPlanner`, `FreeSlotsCalculator`, `CancellationEvaluator`, `NoShowEvaluator`, `QuietHours`, `WaitlistMatcher`, `SessionPlanProgress`, `Pricing`, formatters, grounding check, chunk-merge | `Fast` |
| Repositories and services | Swift Testing with fakes | Contract tests run against `InMemory…` **and** `SwiftData…` repositories; vault; mailbox; queue; sync; sessions | `Fast` |
| ViewModels | Swift Testing | State transitions, error and empty paths, re-entrancy guards, injected clocks | `Fast` |
| UI flows | XCUITest via `launchedForUITests()` | One test per user flow (list below), launch arguments for state | `UISmoke` |
| Everything | | Unit + UI + accessibility audit | `Full` (default) |
| Server | Vitest, `@firebase/rules-unit-testing`, emulators | Rules, functions, race conditions, TTL, deletion cascades | `npm test` in `firebase/functions` |
| Web | Vitest, Playwright, axe-core, Lighthouse CI | Units, flows in all fourteen localizations (and RTL), a11y, performance, network/egress, no-answer-in-clear | `npm test`, `npm run e2e` |
| End to end | `scripts/e2e-local.sh` | Emulators + web + iOS fake bridge: a client books, seals a form, the app imports | local and CI |

Test names are sentences (`@Test("A record is editable until 24h and needs a correction after")`). Build data with `makeX()` factories. Inject `now`. Wait on conditions (`Wait.until`), never sleep. Isolate `UserDefaults` per test.

## 2. UI flows (one XCUITest file each)

1. Onboarding → Home (per profession, in two locales) · 2. Add client (manual, contact import, CSV) · 3. New appointment with warnings · 4. Reschedule and cancel (free window and late) · 5. No-show marking and protection level change · 6. Block time and the cancel/invite choice · 7. Voice record → review → save (fake AI) · 8. Manual record → save → lock rule (time travel with `-uiTimeTravel`) · 9. Photos before/after · 10. Booking settings (pause, approval) and share link · 11. Policy editing updates the rule text · 12. Recovery key (generate, reveal with fake biometrics, confirm) · 13. Language and region change updates previews · 14. Mailbox: a sealed form arrives and appears in the client's health tab · 15. Export all (ZIP produced) · 16. Locked screen and relaunch · 17. Delete a client's data · 18. Offline banner and queue replay · 19. iCloud-full state.

Fixtures come from the prototype demo data (`design/PROTOTYPE-NOTES.md`). Fake system dialogs: provide `-uiPermissions granted|denied` handled in `LaunchOptions` (DEBUG) for notifications, camera, microphone, contacts.

## 3. Accessibility

- `try app.performAccessibilityAudit()` on the main screens in light and dark, default size and AX5, as part of `Full`.
- Manual list (S12): VoiceOver reads every screen in a sensible order with meaningful labels; the Calendar week grid has the day list alternative; custom controls expose adjustable values; Switch Control and Voice Control labels match visible text; Reduce Motion, Reduce Transparency, Bold Text, Increase Contrast, Smart Invert do not break layouts.
- Contrast tests (`PaletteContrastTests`) cover every text/background pair in `08-DESIGN-SYSTEM.md`, light/dark/increased.

## 4. Privacy and security tests

The numbered list in `06-PRIVACY-SECURITY.md` §11 is mandatory. They run in `Fast` (iOS) and `npm test` (server/web). Add to CI a **grep check** (`scripts/check-privacy.sh`) that fails when: a `Firebase*` import appears outside `Managers/Booking`; `SwiftData`/`CloudKit` imports appear outside `Managers/Persistence`; `print(`/`NSLog(` appear outside DEBUG; analytics SDKs are added; `console.log` appears in `firebase/functions/src` or `web/src` on request bodies; `localStorage`/`sessionStorage` is used under `web/src/routes/{form,checkin,data}`.

## 5. Localization tests

See `07-LOCALIZATION.md` §9. In CI, `scripts/check-strings.sh` is part of the `Fast` plan wrapper.

## 6. Performance budgets (measure on an iPhone 12-class device or the closest simulator proxy and record numbers)

| Area | Budget |
|---|---|
| Cold start to `Locked`/`Home` | ≤ 1.5 s |
| Clients list with 2,000 clients | scroll with no hitch > 8 ms; search result ≤ 150 ms |
| Calendar week with 80 appointments | first render ≤ 120 ms |
| Photo save (resize, strip, encrypt, write) | ≤ 800 ms for a 12 MP photo |
| Vault encrypt/decrypt of 400 KB | ≤ 20 ms |
| Memory in `Tx-6-Photos` with 200 photos | ≤ 250 MB (thumbnails only in grids, lazy full-size) |
| Mailbox import of 5 items | ≤ 2 s after wake |
| Voice → structured draft for 90 s of speech | ≤ 12 s on a supported device |
| Web | initial JS ≤ 80 KB gz, LCP ≤ 2.5 s throttled, Lighthouse perf ≥ 90, a11y ≥ 95 |

Use `XCTMetric`/`measure` tests (opt-in plan `Perf`, not in `Fast`) and Instruments for hitches; put results in `PROGRESS.md`.

## 7. CI (GitHub Actions; no secrets needed for the default jobs)

- `ios`: macOS runner with Xcode 26 or newer (the owner has Xcode 27): `scripts/check-project-settings.sh`, `scripts/build.sh`, `scripts/test.sh fast`, `scripts/test.sh smoke` on pull requests; nightly `full` and `check-warnings.sh`.
- `server`: Ubuntu: Node 22, Java 17, `firebase emulators:exec` running rules and function tests.
- `web`: Ubuntu: lint, typecheck, unit, Playwright (Chromium, WebKit, Firefox), Lighthouse CI, `npm audit --audit-level=high`.
- All jobs: privacy and strings checks. Branch protection is a human task.

## 8. v1 acceptance (the project is ready for TestFlight when all are true)

Checked by the S12 agent on 2026-10-10 against `build/v1` at tag `v1.0.0-rc1` (evidence after each item; "device" parts
are human tasks with their H-number in `docs/14-HUMAN-TASKS.md`). Final regression numbers: `docs/PROGRESS.md`, stage
log "S12".

**Product and screens**
- [x] All 97 screens are implemented, mapped in the traceability table, each matching its screenshot within design-system tolerances, and each has its states (empty, loading, error, offline) defined. *Evidence: traceability table 97/97 `done` (4.7, 4.9, 4.10 corrected in S12); states in DESIGN.md "Empty, loading and error states"; one UI flow per screen group in UISmoke; `LocalizationScreenshotUITests` renders the key screens in 14 localizations. Pixel comparison with the prototype is the designer's review (design additions below).*
- [x] Every "Design addition" is listed in `PROGRESS.md` with a screenshot for the designer. *Evidence: `PROGRESS.md` "Design additions" plus the DESIGN.md "Changes from the prototype" sections (S3 to S12); screenshots are generated, not committed: `LocalizationScreenshotUITests` and `ColorReviewUITests` write them to `build/screenshots/` (commands in `docs/review/README.md` and H10).*
- [x] No financial feature exists anywhere (code search for payment/invoice/charge terms; only the StoreKit subscription). *Evidence: S12 search of `BelloHub/`, `web/src`, `firebase/functions/src` for invoice, payment, charge, deposit, commission, revenue, checkout, Stripe, PayPal: the only hits are BIP-39 recovery words.*

**Data and privacy**
- [x] The record, photos and health data exist only in the vault; the on-disk sentinel test passes. *Evidence: `VaultEncryptionTests`, `FormsEncryptionTests`, `Repository*ContractTests` (Fast, green); `VaultFileProtectionTests`.*
- [x] The server holds no clinical data; the sealed-mailbox flow works end to end (browser seals, iPhone opens, server deletes) with cross-implementation vectors green. *Evidence: `EnvelopeOpenerTests` (js-sealed and swift-sealed vectors), web `crypto.cross-implementation.test.ts`, `MailboxServiceTests`; `scripts/e2e-local.sh` 7 passed (sealed intake story); functions use cases 289.*
- [x] Recovery key flow works including restore into an empty store. *Evidence: `RecoveryKeyServiceTests` (BIP-39 vectors, `restoreFromWords`), `RecoveryPhraseTests`, `AccountUITests.testRevealingAndConfirmingTheRecoveryKey`; two-iPhone restore is H3/H19.*
- [x] Notifications contain no client names; no logs/analytics contain client text. *Evidence: `NotificationPlannerTests` (every localization), `MailboxServiceTests`, `check-privacy.sh` rules 3, 6 (no print/NSLog, no body logging) and the analytics-SDK ban; Apple Calendar events follow the same name switch (`CalendarEventPlannerTests`, S12).*
- [x] Delete client / delete account cascade to device and emulator server. *Evidence: `ClientDataDeletionServiceTests`, `ClientDataDeletionUITests` (Export data then Delete data, S12), `AccountServiceTests`, `RemoteAccountDeleterTests`, functions `deletion.test.ts`.*
- [x] Export all (device-generated ZIP with CSV + PDF) works. *Evidence: `DataExportServiceTests` ("Prepare writes a ZIP with the spreadsheets and the PDF…"), `PDFRecordExporterTests`, `RecordUITests.testExportBuildsAClientCopyWithoutPrivateNotes`.*

**Behavior**
- [x] Policies (cancel, no-show, pause, approval) change the app and the web page consistently, in all fourteen localizations (rule text equality test). *Evidence: one shared rule table both sides (`CancellationEvaluator` tests and web `policy.test.ts`, docs/11 section 4), `PolicyRuleTextTests`, D47 snapshots (`policySnapshot.test.ts`, web `bookingRules.test.ts`, `manage.spec.ts`), web i18n 401 keys in 14 localizations with 0 problems.*
- [x] The 24-hour lock and corrections work; AI path always passes through review; manual path complete; the grounding check is tested. *Evidence: `RecordLockPolicyTests`, `RecordEditRulesTests`, `RecordUITests.testHistoryCorrectsALockedRecordOnlyWithAReason`; manual form complete (`TreatmentFlowUITests`). Voice and AI ship as "not available yet" in v1 (D53, `VoiceFlowRulesTests`), so there is no AI draft and no grounding check to run; review stays locked on (`RecordUITests.testAISettingsKeepCloudHelpOffAndReviewLocked`).*
- [x] Offline: every professional flow works without network; the outbound queue replays; conflict detection works. *Evidence: the vault is local (every screen reads it); queue replay after offline and relaunch (`MailboxServiceTests`, `ClientDataDeletionServiceTests`, `ClientRegistrationServerTests`, `InboxRig` tests); `BookingImporterTests` (conflict with a manual visit, S12).*
- [x] Booking race condition test passes (two clients, same slot, one wins). *Evidence: functions `createBooking.test.ts` "lets exactly one of two simultaneous requests for the same slot win" and the ten-caller variant (use cases 289 green).*
- [x] WhatsApp opening, reminders-ready queue, running late and birthday messages work with fallbacks when WhatsApp is absent. *Evidence: `MessageDispatchPlanTests` (WhatsApp, then Messages, share sheet always last; no number = share sheet), `MessageLinksTests`, `MessageServiceTests`, `NotificationServiceTests` (reminders ready), `AppointmentUITests`.*

**Localization, accessibility, motion**
- [x] `check-strings.sh` clean for all fourteen localizations (reviewer-pending strings listed, none missing); formatter, `PhoneNormalizer`, `DigitNormalizer` and `BidiIsolate` tests pass; locale-resolution tests pass; pseudolanguage and right-to-left screenshots show no truncated primary actions and correct mirroring in `ar`. *Evidence: `check-strings.sh --final` (2,273 keys + 6 InfoPlist keys) in every `test.sh` run; `FormattersTests`, `PhoneNormalizerTests`, `DigitNormalizerTests`, `BidiIsolateTests`, `AppLocalizationTests`; `LocalizationScreenshotUITests` (14 localizations, Arabic mirroring, double-length pseudolanguage) in the final Full run; `InfoPlistUsageTests` (every permission text in 14 localizations, S12).*
- [x] `legal/STATUS.md` exists and `check-legal-status.sh` runs; the wave 1 sets (Brazil `pt-BR`; Europe `pt-PT`, `es`, `it`, `fr`, `de`, `en-GB`, with a common GDPR core) are complete and marked ready for legal review; `docs/store/` has metadata drafts for the ten languages. *Evidence: `check-legal-status.sh` and `check-legal-resources.sh` in every `test.sh` run (98 documents, 56 bundled texts); `legal/EUROPE.md`; `docs/store/` 13 storefront localizations, lengths re-checked in S12 (all within limits). Legal review itself is H11 (after sales, D40).*
- [x] Voice capability matrix (`VoiceCapability`) tested for every language, including `none` and `transcribeOnly`. *Evidence: v1 ships voice as unavailable (D53): `VoiceAvailability` (`available`, `notAvailableYet`, `permissionDenied`, `languageUnsupported`) is tested in `VoiceFlowRulesTests` and `TreatmentFlowViewModelTests`; the per-language matrix belongs to the voice release and needs a device (H3, `docs/spikes/VOICE-LANGUAGE-MATRIX.md`).*
- [x] Accessibility audit clean at AX5 and in dark mode; contrast tests green including Increase Contrast; Reduce Motion verified. *Evidence: `AccessibilityAuditUITests` clean in en and pt-BR at the default size and AX5 with Increase Contrast and Reduce Motion (S12, 16 min; in every Full run in en since S12), 14 per-feature audit suites (en, pt-BR, de, ar, hi; default and AX5), `PaletteContrastTests` and the per-screen contrast tests (light, dark, Increase Contrast), web contrast 152/152; dark mode through `-uiDark` (`ColorReviewUITests`). The manual VoiceOver pass is H19.*
- [x] Motion kit used everywhere; no per-screen keyframes; hitch budget met; Reduce Motion and Low Power behaviors verified. *Evidence: `MotionTests` (policy for Reduce Motion and Low Power), every animation through `Motion`/`motionPolicy`; simulator scroll metrics in `PerformanceUITests` (no hitch ratio on the simulator); the device hitch measurement is H19.*

**Engineering**
- [x] `scripts/build.sh`, `test.sh full`, `check-warnings.sh`, `check-project-settings.sh` clean; zero warnings; SwiftLint clean without new disables. *Evidence: final regression in `PROGRESS.md` stage log "S12".*
- [x] Server and web suites green; Lighthouse and bundle budgets met; CSP in place; `npm audit` clean at high severity. *Evidence: `test-firebase.sh` (lint, types, build, audit; unit 943, rules 66, use cases 289, transport 19), `test-web.sh full` (unit 248, Playwright 191 + 15 skipped, Lighthouse 0.99/1.00 on both pages, initial JS 48.4 KB gzip of 80), CSP headers in `firebase/firebase.json` checked by `security.spec.ts`.*
- [x] `DESIGN.md`, `README.md` (how to build, run emulators, run e2e) and `docs/PROGRESS.md` are current; `docs/14-HUMAN-TASKS.md` lists only human items. *Evidence: DESIGN.md "Release hardening (S12)"; PROGRESS "v1 complete" block; H1 to H20 are accounts, devices, legal, store and owner decisions only.*
