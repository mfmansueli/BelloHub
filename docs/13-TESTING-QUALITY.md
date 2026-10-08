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

**Product and screens**
- [ ] All 97 screens are implemented, mapped in the traceability table, each matching its screenshot within design-system tolerances, and each has its states (empty, loading, error, offline) defined.
- [ ] Every "Design addition" is listed in `PROGRESS.md` with a screenshot for the designer.
- [ ] No financial feature exists anywhere (code search for payment/invoice/charge terms; only the StoreKit subscription).

**Data and privacy**
- [ ] The record, photos and health data exist only in the vault; the on-disk sentinel test passes.
- [ ] The server holds no clinical data; the sealed-mailbox flow works end to end (browser seals, iPhone opens, server deletes) with cross-implementation vectors green.
- [ ] Recovery key flow works including restore into an empty store.
- [ ] Notifications contain no client names; no logs/analytics contain client text.
- [ ] Delete client / delete account cascade to device and emulator server.
- [ ] Export all (device-generated ZIP with CSV + PDF) works.

**Behavior**
- [ ] Policies (cancel, no-show, pause, approval) change the app and the web page consistently, in all fourteen localizations (rule text equality test).
- [ ] The 24-hour lock and corrections work; AI path always passes through review; manual path complete; the grounding check is tested.
- [ ] Offline: every professional flow works without network; the outbound queue replays; conflict detection works.
- [ ] Booking race condition test passes (two clients, same slot, one wins).
- [ ] WhatsApp opening, reminders-ready queue, running late and birthday messages work with fallbacks when WhatsApp is absent.

**Localization, accessibility, motion**
- [ ] `check-strings.sh` clean for all fourteen localizations (reviewer-pending strings listed, none missing); formatter, `PhoneNormalizer`, `DigitNormalizer` and `BidiIsolate` tests pass; locale-resolution tests pass; pseudolanguage and right-to-left screenshots show no truncated primary actions and correct mirroring in `ar`.
- [ ] `legal/STATUS.md` exists and `check-legal-status.sh` runs; the wave 1 sets (Brazil `pt-BR`; Europe `pt-PT`, `es`, `it`, `fr`, `de`, `en-GB`, with a common GDPR core) are complete and marked ready for legal review; `docs/store/` has metadata drafts for the ten languages.
- [ ] Voice capability matrix (`VoiceCapability`) tested for every language, including `none` and `transcribeOnly`.
- [ ] Accessibility audit clean at AX5 and in dark mode; contrast tests green including Increase Contrast; Reduce Motion verified.
- [ ] Motion kit used everywhere; no per-screen keyframes; hitch budget met; Reduce Motion and Low Power behaviors verified.

**Engineering**
- [ ] `scripts/build.sh`, `test.sh full`, `check-warnings.sh`, `check-project-settings.sh` clean; zero warnings; SwiftLint clean without new disables.
- [ ] Server and web suites green; Lighthouse and bundle budgets met; CSP in place; `npm audit` clean at high severity.
- [ ] `DESIGN.md`, `README.md` (how to build, run emulators, run e2e) and `docs/PROGRESS.md` are current; `docs/14-HUMAN-TASKS.md` lists only human items.
