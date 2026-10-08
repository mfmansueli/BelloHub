# 03 · Build plan

Thirteen stages in four phases. Each stage is a **vertical slice**: domain rules, persistence or network behind a protocol, ViewModel, View, previews, tests, strings in all fourteen localizations, accessibility, `DESIGN.md` update. Do the stages **in order**; inside a stage the order is yours.

Screen ids (`1.1`, `7.9`…) are the ids shown in the prototype hub and in `docs/screens/SCREENS.md`. Use them in test names, commit bodies and the traceability table in `docs/PROGRESS.md`.

**A stage is done only when** its exit criteria hold, `scripts/test.sh fast` and `smoke` pass, `scripts/check-warnings.sh` and `scripts/check-project-settings.sh` are clean, and the `CLAUDE.md` §8 checklist is ticked for every feature in it.

Legend: *Human* = a task only a person can finish; create it in `14-HUMAN-TASKS.md`, build against the fake, move on.

---

## Phase A · Foundation

### S0 · Adopt the repo, preflight, baseline
- Run the preflight (`00-START-HERE.md` §5). Create branch `build/v1`.
- Confirm `docs/` and `design/` are present at the repo root (the owners copied them; do not edit `design/`). Create `docs/PROGRESS.md` from `docs/15-PROGRESS-TEMPLATE.md`.
- Apply the repo edits in `repo-patch/CLAUDE.md.edits.md`. Set `TARGETED_DEVICE_FAMILY = 1`, remove the iPad orientation key, keep iOS 26.0, and change the bundle ids to `com.bellohub` / `com.bellohub.BelloHubTests` / `com.bellohub.BelloHubUITests` (D38); search the repo for the old `com.iagoxavierdelima` ids and fix every hit. Record the Xcode version (D39).
- Add the repo's `.gitignore` entries you need (`build/`, `node_modules/`, `.firebase/`, `*.local.xcconfig`).
- Build the existing app and run all existing tests once; record the baseline.
- **Firebase provisioning check and Firestore creation** (the owners already created the projects, Auth, billing, APNs and App Check): run `firebase projects:list`, read `.firebaserc`, note the real project ids in `PROGRESS.md`. Create the Firestore `(default)` database in **`eur3`** in each of the three projects (`firebase firestore:databases:create '(default)' --location=eur3 --project <id>`; if the database already exists, read its location and stop if it is not `eur3`: that is a hard question for the owners). Make sure the default Storage bucket is in the EU location (create it with `gcloud storage buckets create … --location=eu` if absent, or add `TODO(HUMAN-H4)` if you cannot). Commit `firebase.json`, `.firebaserc`, `firestore.rules` (deny all for now), `firestore.indexes.json`, `storage.rules` (deny all). Deploy only the deny-all rules to all three projects; no functions or hosting yet. Set `FUNCTIONS_REGION = europe-west1` and `DATA_REGION = eu` in `firebase/config/<env>.json`.
- **Exit:** `scripts/build.sh`, `test.sh full`, `check-warnings.sh`, `check-project-settings.sh` pass on the untouched scaffold with the edits; `PROGRESS.md` has versions, baseline, and the screen traceability table (97 rows, all `todo`).

### S1 · Design system, fonts, motion, catalog (no business screens yet)
- Replace the placeholder palette with the real one (`08-DESIGN-SYSTEM.md`), light and dark, in `Palette`, plus area namespaces (`StatusPalette`, `AvatarPalette`). Typography scale with bundled **Fraunces** and **DM Sans** (variable fonts, `relativeTo:` so Dynamic Type works), spacing, radius, elevation tokens.
- Components (generic, no business rules): `PrimaryButtonStyle` variants, chips with a dot, status chip, avatar with gradient pair, section header, list card with inset dividers, insight tile, hero card (graphite), empty state, sheet header, field, inline notice (safety/coral, info/sage), skeleton, offline banner.
- Motion kit from `09-MOTION.md`: tokens, `MotionStaggerModifier`, press style, sheet and success helpers, Reduce Motion handling, ambient hero glow.
- A DEBUG-only **Design Catalog** screen (`#if DEBUG`, reachable by launch argument `-designCatalog`) that shows every token and component in light/dark and at the largest Dynamic Type.
- Contrast tests: every text/background pair in both appearances, with and without Increase Contrast (extend the existing `PaletteContrastTests`).
- **Localization infrastructure** (`07-LOCALIZATION.md`, `16-MARKETS.md`): `Localizable.xcstrings` and `InfoPlist.xcstrings` with all fourteen localizations and `knownRegions`; `scripts/check-strings.sh`, `scripts/derive-locales.py`, `scripts/export-strings.sh`; `Formatters`, `RegionPreset` + `regions.json` + `RegionCatalog`, `PhoneNormalizer`/`PhoneFormatter`, `DigitNormalizer`, `BidiIsolate`, the `Typography` line-height multiplier for `ar`/`hi`, the `Directional` motion helper; the glossary extended to all localizations. Launch argument `-uiLocale <id>` and a right-to-left pseudolanguage run.
- **Exit:** catalog renders without clipping at AX5 and in `ar` (right-to-left) and `hi`; `check-strings.sh` passes with all fourteen localizations present; all pairs ≥ 4.5:1 (text) / ≥ 3:1 (large text, UI parts); Reduce Motion test shows no animation; fonts load (a test asserts the PostScript names resolve); `DESIGN.md` documents tokens and components.

### S2 · Domain, persistence, vault, keys, sync spike
- Pure domain types and rules in `Models/` and `Screens/<Feature>/Support/` (see `05-DATA-MODEL.md`): `RecordLockPolicy`, `HabitsCalculator`, `FollowUpPlanner`, `FreeSlotsCalculator`, `WaitlistMatcher`, `SessionPlanProgress`, `CancellationEvaluator`, `NoShowEvaluator`, `QuietHours`, `Pricing` (display only). All take `now` as input.
- SwiftData schema (`@Model` types in `Managers/Persistence/Schema/`) mapped to domain types at the boundary; `ClientRecordRepository` protocol with `SwiftDataClientRecordRepository` and `InMemoryClientRecordRepository`; versioned schema and migration plan; `ModelConfiguration` with CloudKit private database behind a config flag.
- **Vault** (`06-PRIVACY-SECURITY.md` §4): `KeyManager` (seed, derived keys, iCloud Keychain storage), `SecretBox` (AES-256-GCM), `RecoveryPhrase` (BIP-39 encode/decode with checksum), `VaultFieldCodec` used by the repository for sensitive fields and photo blobs.
- `SyncStatus` (`synced`, `syncing`, `offline`, `iCloudUnavailable`, `iCloudFull`, `error`) exposed by a `SyncStatusService`.
- **Free registrations (D42):** pure `RegistrationQuota` and `PlanSavings`; a `RegistrationLedgerEntry` (client id and date only, no personal data) stored in the vault by the repository and **never removed when a client is deleted**; `ClientRecordRepository` appends an entry the first time a client id is saved and never for an edit.
- **Spike report** `docs/spikes/SPIKE-swiftdata-cloudkit.md`: what you verified on the simulator and what must be verified on two real iPhones (checklist), restrictions found, go/no-go for SwiftData. If SwiftData is a no-go on the facts you can establish, switch the implementation to Core Data + `NSPersistentCloudKitContainer` behind the same protocol and say so.
- *Human:* H3 (two real iPhones, same Apple ID) runs the on-device checklist.
- **Exit:** repository contract tests run against both implementations and pass; vault round-trip, tamper detection, recovery-phrase round-trip and **known-answer vectors** for key derivation pass; schema migration test (v1 → v1.1 additive) passes; photos are stored encrypted and thumbnails decrypt; no sensitive field is readable in the on-disk store (a test greps the store file for a sentinel string).

---

## Phase B · The professional's app (works fully offline, no server yet)

### S3 · Shell, onboarding, session, lock
Screens: `1.1` Onb-1-Welcome, `1.2` SignIn, `1.3` Onb-2-Profession, `1.4` Onb-3-Services, `1.5` Onb-4-CustomService, `1.6` Onb-5-Terminology, `1.7` Onb-6-Tags, `1.8` Onb-6b-Record, `1.9` Permissions, `1.10` Onb-7-Ready, `1.11` Locked, and the five-tab `MainView` (system `TabView`, iOS 26 floating glass bar).
- `RootView` state gate (`onboarding → login → setup → locked → app`) driven by `@AppStorage`/`DefaultsKey`.
- `SessionService` with an `AuthProvider` protocol. DEBUG provider `LocalDevAuthProvider` (accepts a fixed code) so the whole app is usable before Firebase exists; the Firebase provider arrives in S8.
- Profession catalog (data, not code) driving suggested services, terminology and record fields. Seed content for every language (`07-LOCALIZATION.md` §5; Brazil written first and most carefully, `16-MARKETS.md` §4). Onboarding preselects the business region from the device region (`RegionCatalog`) and lets her change it.
- Face ID lock with `LocalAuthentication`, grace period setting, blur on app switcher. Permissions flow with a pre-explanation before each system dialog.
- **Exit:** a new user can finish onboarding in each locale; relaunch lands on `Locked` then the app; UI smoke test covers onboarding → Home; all texts localized; VoiceOver reads each onboarding screen in a sensible order.

### S4 · Clients and the client record
Screens: `2.2` Clients, `4.1` ClientProfile, `4.2` NewClient, `4.3` ClientEdit, `4.4` ClientKnowledge, `4.5` ClientHealth (filled in by the professional), `4.6` ImportClients, `6.12` Tags, `6.13` RecordTemplate, `6.14` FormTemplates.
- Search and filters (all, due to return, cancels often, new, tags). The "cancels often" rule and the 4-visit threshold come from `HabitsCalculator`.
- Health form model per profession and version; consent with text version; minors flow (D17).
- Contacts import (`Contacts` framework with the limited-access flow) and spreadsheet (CSV) import with mapping and duplicate detection.
- Sensitive text is vault-encrypted by the repository; lists must stay fast with 2,000 clients (measure, `13-TESTING-QUALITY.md` §6).
- **Registration gate (D42):** a `ClientRegistrationService` is the only way to create a client (manual, import, a booking approved from the link). It asks `RegistrationQuota` (ledger count, the server count when known, the subscription state) and returns `allowed` or `needsSubscription`; an import stops at the remaining free slots and offers the paywall for the rest. `NewClient` and `ImportClients` show "Your first 10 client registrations are free. Deleted clients still count toward this limit." and an "x of 10 used" counter. Duplicates (same id or same phone) and edits never count.
- **Exit:** CRUD for clients with tests on the repository fakes; habits tests (threshold at exactly 3 vs 4 visits, late-cancel counting, professional-initiated cancel never counted); import tests (duplicates, malformed rows); health and consent versioning test; filters tested as pure functions.

### S5 · Business setup
Screens: `6.1` Services, `6.2` ServiceEdit, `6.3` AddOns, `6.4` Products, `6.5` Availability, `6.7` BookingSettings, `6.8` ShareLink, `6.9` QuickReplies, `6.10` Credentials, `6.15` NoShowPolicy, `6.16` CancelPolicy, `6.11` Team (static "later").
- Services with contraindications and patch-test flag, add-ons, price visibility modes (`priceDisplay`), availability rules (weekly hours, breaks, days off, buffer), cancel and no-show policies as pure types that also **produce the client-facing rule text** (so the booking page and the app can never disagree).
- Slug generation and uniqueness check through `BookingRepository` (fake until S8). `ShareLink` shows the link and a QR code (`CoreImage`), share sheet.
- Quick replies with variables `{name} {service} {date} {time} {link}` and locale-aware rendering.
- **Exit:** policy → rule-text tests in all fourteen localizations; availability → free slots tests (breaks, buffer, days off, DST change days); contraindication and patch-test settings persist; the `BookingSettings` pause flow works with a return date.

### S6 · Home, calendar and appointments
Screens: `2.1` Home, `2.3` Calendar, `2.6` WeekGlance, `2.7` FollowUps, `2.8` WinBack, `2.4` Notifications (local part), `3.1` NewAppointment, `3.2` Appointment, `3.3` BeforeYouStart, `3.4` Reschedule, `3.5` CancelAppointment, `3.6` MessageClient, `3.7` NoShowMark, `2.12` RunningLate, `6.6` BlockTime, `4.8` SessionPlan, `4.11` NoShowHistory, `7.11` States.
- Day and week calendar (week grid is the dense exception to the 44 pt rule; the day view is the accessible alternative). Warnings in `NewAppointment` (overlap, lunch, break, end of day, buffer, missing patch test, contraindication, client who cancels often).
- Visit types (treatment, touch-up, reaction check), add-ons, guests in sequence (D19).
- All "send a message" actions open WhatsApp (`https://wa.me/<E.164>?text=<percent-encoded>`) with locale-aware text and log a `MessageLog` entry; fall back to the share sheet / SMS if WhatsApp is not installed.
- Local notifications: next-visit reminders to the professional, birthdays (day before), daily summary; **generic text, no names**; quiet hours with urgent exceptions (`QuietHours`).
- "Reminders ready" queue for client reminders (D31, `10-WEB-BOOKING.md` §9).
- Calendar → iPhone Calendar write-through is S10 (`Integrations`).
- **Exit:** `FreeSlotsCalculator`, `FollowUpPlanner`, `CancellationEvaluator`, `NoShowEvaluator`, `QuietHours` have table-driven tests including DST transitions in `Europe/Lisbon`, `Europe/Madrid`, `America/Mexico_City`, `America/Sao_Paulo`, `America/New_York`; a UI test books, reschedules and cancels an appointment; a test proves notification content contains no client name.

### S7 · Treatment record: voice, AI, photos, history
Screens: `5.1` Tx-1-Register, `5.2` Tx-2-Listening, `5.3` Tx-3-Organizing, `5.4` Tx-4-Review, `5.5` Tx-Form, `5.6` Tx-5-Saved, `5.7` Tx-6-Photos, `5.8` Camera, `5.9` Tx-7-NextSession, `4.7` RecordHistory, `4.9` Incident, `4.10` ExportRecord, `7.5` AISettings.
- Speech and AI per `12-AI-AND-VOICE.md`: availability and locale checks, chunking for the 4096-token window, structured output into the profession's record fields, mandatory review, `aiAssisted` flag, manual fallback that is equally polished.
- The 24-hour lock and corrections (`RecordLockPolicy`), edit trail view, incidents with the same lock.
- Camera with framing guide, photos never written to the camera roll, EXIF location stripped, max side 2048 px, ≈400 KB, 320 px thumbnail, encrypted blobs, per-photo visibility and consent. Before/after side by side, slider and timeline.
- PDF export of a client's record through `ImageRenderer`/`PDFKit` (client copy or doctor copy), shared with the share sheet; the file lives in a temp directory with complete file protection and is deleted afterwards.
- **Exit:** on a simulator without Apple Intelligence the whole flow works through `Tx-Form`; with a fake `StructuringService` the review screen shows what the AI proposed and nothing saves without review; lock tests (`23:59:59` editable, `24:00:00` requires correction); photo pipeline test checks size, EXIF removal and that nothing reaches `PHPhotoLibrary`.

---

## Phase C · Server and the client web app

### S8 · Firebase backend and iOS integration
Screens completed: `2.10` BookingRequest, `2.11` RescheduleRequest, `2.9` Waitlist (server-fed), `6.8` ShareLink (live), plus the mailbox import into `4.5` ClientHealth.
- Everything in `11-BACKEND-FIREBASE.md`: `firebase/` (rules, indexes, functions, emulator tests), App Check, slug and public profile publishing, availability blocks, booking transaction (D32), **the account-level registration counter and the "waiting for approval because the free registrations are used" branch of `createBooking` (D42)**, manage tokens, reschedule requests, waitlist, inbox (sealed envelopes), TTL jobs, cascade deletes, push, `ClientMessenger` with email provider and a disabled WhatsApp provider.
- iOS: `RemoteBookingRepository` + `FakeBookingRepository`, `BookingSyncService`, persistent **outbound queue** with idempotent ids, `MailboxService` (fetch, HPKE open, import, acknowledge), FCM + silent push, `FirebaseAuthProvider`, App Check provider, conflict detection.
- *Human:* H4 (Firebase project, billing, Auth, APNs key, App Check), H6 (domain), H7 (email provider key). Everything runs against the **Firebase emulators** in CI-like conditions without them.
- **Exit:** emulator test suite green (rules: no professional can read another's data, no direct writes to `bookings` and `inbox`, public reads limited to `publicProfiles`; functions: validation, rate limits, double-booking race, token expiry); iOS tests with the fake repository cover queue replay after offline, conflict flow, mailbox idempotency (crash between import and acknowledge) and undecryptable items; a script `scripts/e2e-local.sh` starts the emulators, the web app and runs the end-to-end flow (S9) headlessly.

### S9 · Client web app (booking, portal, sealed forms)
Screens: `8.1`–`8.11` (Bk-1…Bk-11), `9.1`–`9.9` (Cl-1…Cl-9).
- Everything in `10-WEB-BOOKING.md`: Preact SPA, fourteen localizations including right-to-left Arabic (logical CSS, `dir`, bidi isolation, digit normalization), per-page language chooser, booking flow with add-ons and guests, phone verification, no-show/approval branches, personal management link (confirm, running late, reschedule, cancel, ICS), "Find my appointment", portal, rebook, intake form with **in-browser HPKE sealing**, skin check-in, my data (copy/deletion request).
- Shared test vectors with iOS (`web/test/vectors/`): the browser encrypts what Swift decrypts and vice versa.
- Strict CSP, SRI, no third-party scripts, hosted on Firebase Hosting with rewrites for `/{slug}` and `/m/{token}`.
- **Exit:** Playwright suite passes on Chromium, WebKit and a throttled "low-end Android" profile; the WhatsApp/Instagram in-app-browser checklist is run on real devices by a human (H8) and any failure is logged; Lighthouse: performance ≥ 90 mobile, accessibility ≥ 95; initial JS ≤ 80 KB gzip; a test asserts **no network request leaves the allowed origins** and that no health answer ever appears in a request body in clear text (only the envelope).

---

## Phase D · Account, language, polish, ship

### S10 · Account and settings
Screens: `7.1` Account, `7.2` LanguageRegion, `7.3` Plan, `7.4` NotificationSettings, `7.6` Integrations, `7.7` Privacy, `7.8` ExportAll, `7.9` RecoveryKey, `7.10` Help.
- `RecoveryKey` (generate, mask, reveal with Face ID, save to Files, print, confirm, status shown in `Privacy`), restore flow on a new phone, key rotation model.
- `LanguageRegion`: region presets (`16-MARKETS.md`), business localization, currency, week start and clock, previews of the message templates, booking-page languages.
- `Plan` with StoreKit 2 (local `.storekit` configuration for tests): **one complete plan, monthly and yearly with identical features, no trial** (D33, D42); localized `displayPrice`s from StoreKit; the yearly plan highlighted with the saving computed by `PlanSavings` (about 17 %); restore purchases; server verification hook. The same screen opens as the **paywall** when `ClientRegistrationService` answers `needsSubscription`, with a headline that explains the limit and a reminder that existing clients and records stay available.
- `Integrations`: Apple Calendar through EventKit (limited-access flows), contacts import entry; Google Calendar is shown as "coming soon" unless a human provides OAuth (H9).
- Delete account: export first, then cascade (device and server).
- **Exit:** restore-from-recovery test (wipe vault, re-enter 12 words, previous records decrypt); changing region changes previews and web-page language set; ExportAll builds the ZIP (CSV + PDF) on the device from fixtures and offers it through the share sheet; account deletion leaves no documents on the emulator and clears the local vault only after explicit confirmation.

### S11 · Localization completion and market readiness
- Read every string in all fourteen localizations against the glossary (`docs/strings/glossary.csv`), message templates (`message-templates.json`), plural rules (six categories for `ar`), gender and address rules; pseudo-localization, right-to-left and long-string tests; formatter tests per localization; ICS and email templates per localization; profession catalog complete; legal drafts for every region set with `legal/STATUS.md` and `scripts/check-legal-status.sh`; `scripts/export-strings.sh` / `import-strings.sh` ready for reviewers.
- Prepare the **wave 1 release candidates** (Brazil and Europe): `pt-BR`, `pt-PT`, `es`, `it`, `fr`, `de`, `en` and `en-GB` strings, templates and profession catalogs finished with the same extra care, the LGPD texts for Brazil, and the European legal set as a common GDPR core plus national annexes (PT, ES, IT, FR, DE, UK). For each of those languages write `docs/review/<localization>.md`: the screens and strings a native reader should read, in order.
- **Exit:** `scripts/check-strings.sh` passes: no missing key, empty value, missing plural category, placeholder mismatch or stale derived localization; the only `needs_review` strings are those the report lists as awaiting reviewers (they are expected: no reviewers exist yet); the screenshots test (`13-TESTING-QUALITY.md` §5) renders the key screens in all fourteen localizations without truncation at the default size and mirrored correctly in `ar`; `PROGRESS.md` shows the "Market readiness" table.

### S12 · Hardening and release readiness
- Accessibility audit with `XCUIApplication.performAccessibilityAudit`, manual VoiceOver pass list, AX5, Increase Contrast, Reduce Motion.
- Performance: cold start, scrolling 2,000 clients, 200 photos, memory in `Tx-6-Photos`, battery of the voice flow; fix regressions.
- Security review against `06-PRIVACY-SECURITY.md` §9 checklist; `PrivacyInfo.xcprivacy`; App Privacy answers draft; `Info.plist` usage strings in all fourteen localizations; no analytics SDK with client text.
- App icon (placeholder from tokens if none supplied), launch screen, App Store metadata drafts for all ten languages in `docs/store/<localization>.md` (name ≤ 30 characters, subtitle ≤ 30, keywords ≤ 100, description, what's new; Brazil and Europe first), TestFlight notes.
- Final regression: `scripts/test.sh full`, `check-warnings.sh`, web suite, emulator suite, e2e script.
- **Exit:** `13-TESTING-QUALITY.md` §8 v1 acceptance fully checked; `PROGRESS.md` final report; open items are only `HUMAN` tasks.
