# Agent notes: S8 leftovers + S12 documentation items

Branch `s8-leftovers`, started from `origin/build/v1` at `4c121a7` (2026-10-10), in its own worktree, while S11 owned
`build/v1`. Simulator: "iPhone 17 Pro Max" (`SIM_UDID=1D7CD4D7-…`). Functions and web untouched. The first batch
(section 1) added no strings; the second batch (section 2) adds two new string batch files only.

## 1. What changed (first batch: Fast 2140 tests in 300 suites, check-warnings zero)

### Server account deletion (S8 leftover)
- `Managers/Account/RemoteAccountDeleter.swift`: calls the owner function `deleteAccount` (`{confirm: true,
  appleAuthorizationCode?}`, API.md 6.7). `appleRevocation` maps to the done screen: `revoked` -> `.deleted`; `failed` ->
  `.deletedWithoutAppleRevocation`; `skipped` -> `.deleted` for a phone account, `.deletedWithoutAppleRevocation` when a
  code was sent (the Apple key is not configured on that server). Every failure throws, so `AccountService` touches
  nothing on the phone (unchanged cascade: server first, then vault, seed, settings, session).
- `OfflineAccountDeleter` is now `#if DEBUG`: UI-test launches, `-devLogin` runs (fake token the server refuses) and
  previews. `AccountService.init` lost its default deleter; `AppDependencies` passes the remote one in the live app.
- `AccountDeletionOutcome.deviceOnly` documented as DEBUG/no-server only.

### Server-side plan verification (S8 leftover, D33/D42)
- `Managers/Subscription/RemoteSubscriptionVerifier.swift`:
  - `purchaseToken()` asks `ensureAccount` (through `RemoteBookingRepository`, region and language from the profile)
    for `appAccountToken`; `StoreKitSubscriptionProvider.purchase` passes it as `.appAccountToken(uuid)`, so `syncPlan`
    and App Store Server Notifications can tie the transaction to her account. No token (offline, no profile) ->
    `SubscriptionError.accountUnavailable` and the store is never asked (the Plan screen shows its existing "failed"
    notice).
  - `verify(_:signedTransaction:)` sends the current entitlement's JWS to `syncPlan`; the server's plan wins
    (`active`/`grace` with the server's dates and the store's period/renewal flag; `none`/`expired`/`revoked` -> no
    plan). `VERIFICATION_FAILED` -> no plan. Offline / `NOT_CONFIGURED` (H14 root certificates) / busy -> thrown, and
    `SubscriptionService` keeps StoreKit's on-device verified answer, as before.
- Protocol changes (all implementations updated): `SubscriptionProviding.purchase(_:appAccountToken:)` and
  `currentSignedTransaction()`; `SubscriptionVerifying.purchaseToken()` and `verify(_:signedTransaction:)`.
- `OfflineSubscriptionVerifier` is `#if DEBUG`; `SubscriptionService.init` has no defaults; `SubscriptionService.preview(
  hasPlan:)` (DEBUG) serves UI-test launches and `#Preview`s. The previews of `PlanView`, `PaywallSheet`, `MoreView`,
  `MoreTab` are now inside `#if DEBUG`.

### Tests (BelloHubTests)
- `RemoteAccountDeleterTests` (request validated against the server contract schema, Apple code, outcome table,
  failures throw, AccountService keeps the device on failure), `RemoteSubscriptionVerifierTests` (token, failures,
  `syncPlan` request against the schema, state mapping, `VERIFICATION_FAILED`, transient errors, no transaction,
  NOT_CONFIGURED through the service), 3 new `SubscriptionServiceTests`.
- `MailboxServiceTests` + `MailboxUndecryptableTests` (over the new `Support/MailboxRig.swift`): sealed intake opened
  and imported once into the right client, Storage envelope fetched, idempotent re-sync, acknowledge replayed after
  offline and after a relaunch (new `OutboundQueue` over the same defaults), check-in waits for her and is acknowledged
  on "handled", stop forgets, unmatched -> imported later, locked keys retry, offline list, unknown key (persisted,
  dismiss acknowledges), tampered, misaddressed item id, unsupported version, bad payload, sign-out.
- `PushServiceTests` (serialized: pushes travel through the default `NotificationCenter`): token registered with the
  language, once per token, offline replay, remembered per user across a relaunch, sign-out unregisters, silent mailbox
  push syncs the mailbox, booking pushes sync bookings, stopped service ignores pushes, payload parsing.
- New fakes: `FakeInboxKeys`, `FakeImmediateNotifier`, `FakePushTokenProvider` (replays the current token to each new
  listener, like FCM); `FakeInboxRepository` serves a mailbox, records reads and can fail reads.

### S12 documentation-only items
- `BelloHub/SupportFiles/PrivacyInfo.xcprivacy`: no tracking; collected types (all linked, App Functionality): User ID,
  Name, Email, Phone Number, Other User Content, Purchase History, Device ID; required-reason API: UserDefaults `CA92.1`
  only (no file-timestamp, disk-space, boot-time or keyboard API in the app's code).
- `scripts/check-privacy.sh` rule 7: the manifest exists, says no tracking, and declares every required-reason API
  category the code uses (fails the day someone adds `creationDate` or `systemUptime` without a manifest entry).
- `docs/store/app-privacy.md` (App Privacy answers + manifest explained), `docs/store/README.md`, and metadata drafts
  for `pt-BR`, `pt-PT`, `es`, `it`, `fr`, `de`, `en-GB`, `en`, `es-MX`, `tr`, `id`, `hi`, `ar` (name, subtitle, keywords,
  promotional text, description, what's new, TestFlight notes; all lengths checked).
- `docs/agent-notes/security-review.md`: docs/06 section 9 + sections 3 to 8 + section 11, each item checked against the
  code, with the gap list.

## 2. Second batch (same branch): security gaps and S12 performance

### Security gaps closed (details and evidence: `security-review.md` section 5)
- **Client data deletion reaches the server**: "Delete data" in 4.3 (`ClientDeleteDataRow`, coral row, destructive
  confirmation) -> `ClientDataDeletionService` (built with the inbox services, in the environment): vault cascade, then
  `OutboundAction.deleteClientServerData` per `ClientServerDeletionPlan` (phone once, booking ids in chunks of 200).
  `InboxRepository.deleteClientServerData` in Remote/Offline/UITest/Fake.
- **Server registration count (D42)**: `ClientRegistrationService(server:queue:)` asks `reserveRegistrations` before a
  new client is saved (one claim, or an import in chunks of 200); the vault ledger and `serverCount` are the cache. The
  cache answers "paywall" without asking; offline the client is saved and `.reserveRegistrations` waits in the queue
  (its outcome `.registrations` refreshes the cache); a permanent refusal (no server, refused token) falls back to the
  cache. Models `RegistrationClaim`, `RegistrationReservation`. **Note:** until H14 the server's plan stays `none`
  (`syncPlan` answers NOT_CONFIGURED), so after 10 clients a sandbox purchase does not lift the server's limit; the
  TestFlight note "buy Bello Hub Pro after the 10th client" only works once H14 is done.
- **Inbox key integrity + fingerprint**: `InboxKeyVerifier` (+ `BookingRepository.servedInboxKey` via `getPublicPage`)
  after every profile change: mismatch -> one republish -> still wrong -> `PublishFailure.keyMismatch`, publishing
  blocked until she taps Try again. Privacy shows "Form key <keyId>" (the code the booking form prints).
  `PublishingService` mapping moved to `PublishingService+FailureMapping.swift` (type body length).
- **Store protection**: `VaultFileProtection` sets `completeUntilFirstUserAuthentication` on the store, `-wal`, `-shm`
  and folder (`VaultContainerFactory`); read back in tests.
- **Recovery words**: `hiddenWhileCaptured()` (DesignSystem, `SceneCaptureObserver` over
  `UITraitCollection.sceneCaptureState`) replaces the words while the screen is recorded, mirrored or shared. A
  screenshot cannot be refused with a public API; the app-switcher snapshot is `PrivacyCover` (already there).
- **Account deletion after a half-finished attempt**: `AccountService` stores the server's answer
  (`DefaultsKey.accountDeletionConfirmed`, format in `AccountDeletionConfirmation`) until the wipe succeeds, so a retry
  goes straight to the wipe. Server already idempotent (`deletion.test.ts` "is safe to call again"): no function change,
  so `scripts/test-firebase.sh` was not needed.
- **"From your clients" in Alerts** (`MailboxAlertCards`, pure `MailboxAlerts`, `AlertsViewModel(mailbox:)`): check-ins,
  copy/deletion requests, unopened and unmatched forms, imported-form count; each action acknowledges on the server.
  Found and fixed on the way: the first mailbox sync raced the bookings' first sync, so the fixture form waited as
  "unmatched" until the next push; `MailboxService` now waits (at most ~5 s) for the bookings' first sync.
- Strings: two new batches, `Config/Locale/strings/s8-inbox-unopened.json` (18 keys) and
  `Config/Locale/strings/s8-leftovers.json` (10 keys), merged with `scripts/merge-strings.py <both files>` (catalog
  diff is additions only). On the S11 merge: keep both sides of `Localizable.xcstrings`, then run
  `python3 scripts/merge-strings.py` to regenerate.

Not done by instruction: App Check (owner task H5) and phone sign-in (v1 is Apple only, D44). Still open: a breach-plan
page; check-in photos are not shown in the Alerts card (dropped when handled).

### S12 performance (`BelloHubUITests/PerformanceUITests`, opt-in)
Run: `TEST_RUNNER_BELLO_PERF=1 ONLY_TESTING=BelloHubUITests/PerformanceUITests scripts/test.sh full`. Seeding
(DEBUG): `-uiPerfClients N`, `-uiPerfPhotos N` (`PerformanceUITestSeeding`; photos are distinct 1200 x 1600 JPEGs).
Measured 2026-10-10 on the "iPhone 17 Pro Max" simulator (iOS 26), **Debug build**, in-memory UI-test vault:

| Budget (docs/13 section 6) | Metric | Result |
|---|---|---|
| Cold start to Locked/Home ≤ 1.5 s | `XCTApplicationLaunchMetric` (first frame responsive), 5 runs | **1.39 s** to Welcome (no seeding); 1.67 s to Home with the UI-test seeding of the onboarded workspace included in the launch |
| 2,000 clients: search ≤ 150 ms | signpost `clientSearch` (`PerformanceSignposts`, no values) | **12 ms** per search |
| 2,000 clients: scroll with no hitch > 8 ms | `scrollDecelerationMetric` / `scrollDraggingMetric` | deceleration 2.43 s, dragging 0.14 s per fling; the simulator reports no hitch ratio, so the hitch budget needs a device run (Instruments, Animation Hitches) |
| Memory with 200 photos ≤ 250 MB | `XCTMemoryMetric` while flinging the photo strip of 4.7 back and forth | **peak 97 MB**, absolute 91 MB |

Regression found and fixed: the record history kept every decrypted full-size photo for as long as the screen was open.
In the in-memory UI-test vault the bytes are shared, so the metric could not show it, but in the SwiftData vault each
decrypted photo is a new buffer (200 camera photos would be hundreds of MB). `PhotoMemoryCache` now keeps every
thumbnail and only the last four full-size images (`PhotoMemoryCacheTests`). The treatment flow (Tx-6-Photos) holds
the full images of the photos of the visit being recorded until it is saved; that is a handful, not 200.
Not measured: battery of the voice flow (voice capture is unavailable in v1).

## 3. Measured (end of the second batch)

- `scripts/test.sh fast` (iPhone 17 Pro Max): **2172 tests in 307 suites passed** (2140 / 300 after the first batch).
- `scripts/check-warnings.sh`: **zero warnings** on simulator, device, Release and the test targets.
- UI: `ClientDataDeletionUITests`, `MailboxAlertsUITests`, `ClientsUITests`, `InboxUITests`, `AccountUITests`,
  `PublishUITests`, `MoreUITests` pass. `RecordUITests.testHistoryCorrectsALockedRecordOnlyWithAReason` fails on the
  Pro Max simulator ("no keyboard focus" typing the reason) **with and without this branch's change** to
  `RecordHistoryViewModel` (checked by running it with the old file): environmental, worth a look on "iPhone 17".
- `scripts/test-firebase.sh`: not run, no file under `firebase/` changed.

## 4. Third batch: accessibility audit, remaining S8 items, breach plan

- **RecordUITests on another simulator**: `testHistoryCorrectsALockedRecordOnlyWithAReason` passes on "iPhone 17e"
  (581B8F64-…): the failure on the Pro Max ("no keyboard focus") is simulator-specific; nothing changed.
- **Accessibility (S12)**: opt-in `AccessibilityAuditUITests` (all audit types except pixel contrast; en and pt-BR;
  default size and AX5; Increase Contrast and Reduce Motion on through the new DEBUG hooks `-uiIncreaseContrast`
  (`HighContrastTraitOverride`, window-scene trait) and `-uiReduceMotion`). Fixed: onboarding step bar hit region,
  logo read as one image, `MoreRow` and Services link rows wrap, Services add-row icon follows Dynamic Type, no isolate
  marks around the form key. Documented exceptions (system bars, scrolling text fields, capped insight numbers, two
  Services rows that do grow): see `docs/agent-notes/accessibility-audit.md`, which also holds the manual VoiceOver
  pass list with the rotor order per screen. Contrast: XCTest's pixel check flagged 187 pairs far above 4.5:1 with and
  without Increase Contrast; contrast stays measured exactly by `PaletteContrastTests`.
- **Suggest another time (2.10)**: new owner function `suggestBookingTime` (`firebase/functions/src/owner/
  suggestBookingTime.ts`, contract, API.md 6.3, schemas, 3 emulator tests in `ownerBookings.test.ts`): declines the
  request and holds the proposed time like a waitlist offer; booking through it keeps the `bookingLink` origin
  (`bookingCreate.ts` now marks `waitlist` only for offers tied to a waitlist entry). App: `SuggestTimeSheet` (picker
  in the business time zone, "Keep this time", then a `ShareLink` with the offer link `<web>/<slug>/time?offer=…`),
  `BookingSyncService.suggest`, `InboxRepository.suggestBookingTime` in every implementation; tests
  `BookingRequestSuggestionTests`, `SuggestTimeUITests`. Strings: `Config/Locale/strings/s8-suggest-time.json`.
  `scripts/test-firebase.sh`: lint, types, build, audit ok; unit 943, rules 66, use cases 289, transport 19 passed.
- **"Cancels often"** on waitlist rows and the booking request (`CancelsOftenBadge`, same words as the client list):
  `CancelsOftenLookup` matches by phone and uses `HabitsCalculator` (docs/05: ≥ 30 % of the last ten past
  appointments, from four completed visits); tests `CancelsOftenLookupTests`.
- **Check-in photo** on its Alerts card (from the opened envelope, in memory only, spoken "Photo the client sent").
- **Breach plan**: `docs/BREACH-PLAN.md` and H18 in `docs/14-HUMAN-TASKS.md`.
- **Measured at the end of the third batch** (iPhone 17 Pro Max): `scripts/test.sh fast` **2179 tests in 309 suites
  passed**; `scripts/check-warnings.sh` **zero warnings**; `scripts/test-firebase.sh` green (above); the accessibility
  audit passes both tests (en and pt-BR, default and AX5, Increase Contrast and Reduce Motion); UI suites
  `SuggestTimeUITests`, `MailboxAlertsUITests`, `InboxUITests`, `OnboardingUITests`, `ServicesUITests`, `MoreUITests`,
  `LaunchUITests` pass.
- Noticed, not changed: on the `-uiRoute recordHistory` UI-test route the trail reads "Created by " with no name (the
  profile is not loaded yet on that debug route; in the app it is).

## 5. Merge notes (for the integrator)

Most likely to conflict with S11:
- `BelloHub/SupportFiles/Localizable.xcstrings` (additions only; keep both, then `python3 scripts/merge-strings.py`).
- `BelloHub/Screens/Main/RootView.swift` (one `@State`, one init line, one `.environment`),
  `BelloHub/Screens/Main/Support/AppDependencies.swift`, `BelloHub/Screens/Main/Support/InboxServices.swift`.
- `DESIGN.md` (new section "Changes from the security review (S8 leftovers)" before "Client web app (S9)").
- `BelloHub/Screens/Alerts/AlertsContentView.swift`, `AlertsView.swift`, `AlertsViewModel.swift`;
  `BelloHub/Screens/Clients/Form/ClientEditView.swift`, `Screens/Clients/ClientsTabView.swift`;
  `BelloHub/Screens/Privacy/PrivacyContentView.swift`, `PrivacyView.swift`;
  `BelloHub/Screens/RecoveryKey/RecoveryKeyContentView.swift`; `BelloHub/Screens/BookingSettings/Support/PublishStatusText.swift`.
- `#Preview` blocks of `MoreView`, `MoreTab`, `PlanView`, `PaywallSheet`, `AccountView`; `HomePreviewHost`,
  `ClientsPreviewHost`.
- `BelloHub/SupportFiles/DefaultsKey.swift` (one key), `BelloHub/SupportFiles/UITestSeeding.swift` (one line),
  `scripts/check-privacy.sh` (rule 7 appended).
Third batch adds: `firebase/functions` (new `suggestBookingTime`, `contracts/owner.ts`, `app/registry.ts`, `index.ts`,
`lib/bookingCreate.ts`, `lib/docs.ts`, `API.md`, `contracts/schemas.json`, `test/integration/ownerBookings.test.ts`) and
`BelloHubTests/Resources/ServerContract/schemas.json` (regenerate with `npm run gen:schemas` +
`scripts/sync-server-contract.sh` if both sides changed); `docs/14-HUMAN-TASKS.md` (H18 row and section);
`BelloHubTests/Models/Locale/NavigationTitleFitTests.swift` (one key); `BelloHub/SupportFiles/LaunchOptions.swift`
and `View+UITesting.swift` (two hooks); `DesignSystem/Components/StepProgressBar.swift`, `BrandLockup.swift`,
`Screens/More/Rows/MoreRow.swift`, `Screens/Services/ServicesContentView.swift`, `Screens/Inbox/**`,
`Managers/Inbox/BookingSyncService.swift` (error text moved to `BookingSyncService+ErrorText.swift`).
Not touched: `docs/PROGRESS.md`, `docs/review`, `docs/strings`, `legal/`, `web/`. Functions are **not deployed**:
`suggestBookingTime` needs a functions deploy before the button works against dev.

## 6. Text for docs/PROGRESS.md (paste after the merge)

> **2026-10-10: S8 leftovers, security-review gaps and S12 documentation, performance and accessibility done on
> `s8-leftovers`** (notes `docs/agent-notes/s8-leftovers.md`, reviews `docs/agent-notes/security-review.md` and
> `docs/agent-notes/accessibility-audit.md`). Server account deletion (resumable after a half-finished attempt) and
> server plan verification (`appAccountToken` + `syncPlan`); client data deletion reaches the server through the
> outbound queue ("Delete data" in 4.3); the registration count asks `reserveRegistrations` (ledger as cache, offline
> replay); the page's inbox key is checked against the derived one (`keyMismatch` stops publishing) and Privacy shows
> the form key; store protection set explicitly; recovery words hidden while recorded or shared; "From your clients"
> in Alerts (check-ins with their photo, data requests, unopened forms) acknowledges each item; "Suggest another time"
> on booking requests (new function `suggestBookingTime`, emulator tests; **needs a functions deploy**); "Cancels
> often" on waitlist and requests. Unit suites for `MailboxService`, `PushService`. S12: `PrivacyInfo.xcprivacy`
> (+ `check-privacy.sh` rule 7), App Privacy answers, App Store metadata in 13 localizations (`docs/store/`),
> `PerformanceUITests` (cold start 1.39 s to Welcome, search over 2,000 clients 12 ms, peak 97 MB with 200 photos;
> bounded full-size photo cache), `AccessibilityAuditUITests` (en and pt-BR, default and AX5, Increase Contrast and
> Reduce Motion: clean after fixes; VoiceOver pass list for a device), breach plan `docs/BREACH-PLAN.md` (H18).
> Fast 2179 tests in 309 suites, check-warnings zero, test-firebase green. Open: App Check (H5), hitch measurement and
> the VoiceOver pass on a device, H14 before the server lifts the 10-client limit for a sandbox purchase.
