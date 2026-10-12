# Plan on device (StoreKit 2) and the free registrations in the Keychain

Task: `docs/tasks` text from the owner, 2026-10-12 ("mover a verificação do plano do BelloHub para o aparelho"). One
agent, branch `plan-on-device` from `origin/build/v1` at `3e12e11`.

## Mapa do estado encontrado (phase 0, before any code change)

### Where this ran (differs from the task text)
- The task was written for the owner's Mac (`/Users/iagoxavierdelima/...`, `xcodebuild`, two iPhones). This session runs
  in a **Linux cloud container with no Swift toolchain and no Xcode**: `scripts/build.sh`, `test.sh`,
  `check-warnings.sh` and `run-device.sh` cannot run here. The Linux-only checks (`check-privacy.sh`,
  `check-strings.sh --final`, `check-localization-sources.sh`) do run. Nothing in this branch has been compiled.
- The Cue Studio reference (`/Users/.../CueStudio`) is not available here: the design follows the description in the
  task (generic-password Keychain item, `AfterFirstUnlockThisDeviceOnly`, never synchronised, errors logged without
  personal data).
- Checkout: one worktree, no other agent, no `xcodebuild` process. `build/v1` is 14 commits ahead of `main`
  (booking-status fix, motion). Another unmerged branch exists (`claude/practical-dijkstra-hy0d79`, client records);
  this work does not depend on it.
- Tag `before-plan-on-device` was created locally on `3e12e11`; **pushing tags is refused by this environment's git
  proxy (HTTP 403)**. The branch push works. The coordinator can create the tag on `3e12e11`.

### Decisions in force
- D33 (StoreKit 2, one group "Bello Hub Pro", `com.bellohub.pro.monthly` / `.yearly`, same features, no trial, no
  introductory offer; EUR/USD 14.99 / 149.99, BRL 39.90 / 399.90; prices always `Product.displayPrice`; "server
  verification through App Store Server Notifications").
- D42 (10 free registrations, cumulative, deletes never return a slot, every way a client is created counts,
  duplicates and edits do not, paywall at the 11th, existing data stays accessible; counter "at account level" on the
  server, backed by a ledger in the iCloud vault; item 8: a new client booking online after the free ones are used and
  without a plan arrives as "waiting for approval" and the paywall appears when she approves).
- D58 is the newest decision: the new one is **D59**. Nothing newer changed prices, products or the limit.

### App (as found)
- `Managers/Subscription/`: `SubscriptionService` (state, offers, purchase, restore, manage; listens to the provider's
  updates and passes every state through a verifier), `SubscriptionProviding` + `StoreKitSubscriptionProvider` (the
  only StoreKit importer: products, purchase with `appAccountToken`, `AppStore.sync()`, `currentEntitlements`,
  `Transaction.updates`, grace period from `subscriptionStatus`; no revocation or expiry check, no cache),
  `SubscriptionVerifying` + `RemoteSubscriptionVerifier` (`ensureAccount` for the account token, `syncPlan` for the
  verdict) and `OfflineSubscriptionVerifier` (DEBUG), `UITestSubscriptionProvider` (DEBUG, `-uiPlan none|active`).
  Product ids are written in `Models/Plan/PlanProduct` (not configuration).
- `Managers/Clients/ClientRegistrationService` (the only gate, `ClientRegistering`): count = max(vault ledger, last
  server count); every new client is first reserved on the server (`reserveRegistrations`, 200 per call, queued in the
  `OutboundQueue` when offline); the vault ledger (`registrationLedger()`, client ids and dates, iCloud) grows on every
  first save of a client id.
- `Models/Plan/RegistrationQuota` (the only owner of "10"), `RegistrationUsage`, `ImportPlan` (import preview: free
  left, registered now, waiting for a plan; reads `RegistrationUsage`).
- Plan screen and paywall: `Screens/Plan/` (`PlanContentView`, `PlanViewModel`, `PlanPresentation`) and
  `Screens/Shared/Registration/PaywallSheet`. Restore is on both. **No links to the Terms and the Privacy Policy**
  (App Review 3.1.2). The footer says "Billed by Apple. Cancel any time…".
- `Config/BelloHub.storekit` exists. UI-test hooks: `-uiPlan none|active`, `-uiRegisteredClients N`, `-uiInbox
  paywall`. (The task's `-uiPaywall` is `-uiPlan` here.)
- Legal texts: the app bundles `terms-dpa` and `privacy-policy` (`LegalNoticeLibrary`, `LegalNoticeSheet` in
  Privacy). The site has `https://bellohub.app/privacy`; **there is no `/terms` page on the site** (the slug is only
  reserved).

### Server (as found; not changed by this task)
- `syncPlan` and `appStoreNotifications` verify with Apple's root certificates, which were **never installed**
  (`certs/apple` holds only a README, `APPLE_APP_ID` empty): every `syncPlan` answers `NOT_CONFIGURED`, so
  `accounts/{uid}.plan` is `none` for everyone today.
- The server still applies D42 itself, with its own count and that plan:
  - `reserveRegistrations`: refuses new clients past 10 when its plan is not active. **Today this refuses a paying
    professional's 11th client in the app** (the plan never reaches the server).
  - `createBooking` (`approvalReason`): a new phone booking online after the server counted 10 becomes
    `pendingApproval` (`freeRegistrationsUsed`); confirmed new-phone bookings increment the server count.
  - `respondBookingRequest`: approving such a booking answers `needsSubscription` when the server's plan is not active.
- `ensureAccount` is also used by publishing (the booking page account); only its `appAccountToken` is purchase-related.
- No new server feature depends on "who pays" since 2026-10-12 (no cost limit per plan was found in e-mail, pages or
  functions).

### Conflict found, and the safe choice
Stopping `syncPlan` and `reserveRegistrations` in the app is what the owner decided, and it removes today's in-app
block for paying users. But the **online booking path keeps using the server's count and a plan the server never sees
active**: once the server has counted 10 registrations, new clients booking online always arrive for approval, and
approving them answers `needsSubscription` even for a paying professional. This was already true before this change
(no certificates), and fixing it needs a function change and a deploy, which this task forbids. So:
- the app change goes ahead as decided;
- the functions stay untouched; the server follow-up is written below and in the final report;
- the app stops sending a paying professional to the paywall when the server answers `needsSubscription` to an
  approval: it says the request could not be approved online instead.

## What changed (D59)

### App
- `Managers/Subscription/`:
  - `StoreKitSubscriptionProvider` hands on only verified facts as `StoreEntitlement` (no StoreKit type outside it):
    `Product.SubscriptionInfo.status` per subscription (subscribed, expired, billing retry, grace period, revoked)
    with the signed renewal info (`willAutoRenew`, `gracePeriodExpirationDate`). Offline it falls back to the locally
    signed `Transaction.currentEntitlements`. Unverified results are ignored and logged by product id. `updates()`
    finishes verified transactions and fires on every change.
  - `DeviceSubscriptionVerifier` replaces `RemoteSubscriptionVerifier` and `OfflineSubscriptionVerifier` (deleted). It
    decides with `EntitlementRules` and keeps a `SubscriptionSnapshot` through `DefaultsSubscriptionSnapshotStore`
    (`DefaultsKey.subscriptionSnapshot`), and `EphemeralSubscriptionSnapshotStore` in DEBUG launches.
  - `SubscriptionService` shows the cached plan at launch, then reads the store; it listens to `updates()` for the
    session (`start()` / `stop()`); when the store cannot be read, the cached state stands (until its signed end).
    Purchase has no account token; Restore calls `AppStore.sync()` and reads the entitlements again.
- `Models/Plan/`: `PlanProducts` (ids from `Config/App.xcconfig` → `Config/App-Info.plist`, replaces `PlanProduct`),
  `StoreEntitlement`, `EntitlementRules`, `SubscriptionSnapshot`. `RegistrationReservation` deleted.
- `Managers/Clients/`: `RegistrationAllowanceStoring`, `KeychainRegistrationAllowanceStore` (app),
  `InMemoryRegistrationAllowanceStore` (UI tests, previews, default). `ClientRegistrationService` no longer takes a
  server or a queue.
- Inbox: `reserveRegistrations` removed from `InboxRepository` and its implementations. The `OutboundAction` case
  stays so an older saved queue still decodes; replaying it is a no-op.
- Plan screen and paywall: `PlanLegalSection` (auto-renewal sentence, Terms of Use, Privacy Policy) and the Legal
  notice sheet moved to `Screens/Shared/Legal/`. BookingRequest: `serverMissesPlan` notice.

### Migration and old data
- First read after the update: Keychain count = max(Keychain, vault ledger). The vault ledger is untouched and still
  counts, so the count can never go down. The same rule runs on every read, so clients that arrive through the
  booking page (saved by the sync, counted by the ledger) also raise the Keychain.
- A client id the ledger already holds (a deleted client coming back with the same id) is not counted twice.
- Purchases made before: StoreKit already holds them; the first read after the update proves them on the iPhone. No
  server state is read or migrated.
- `accounts/{uid}` on the server keeps its count and plan as they were; nothing writes the plan any more.

### Documentation and human tasks
- D59 in `docs/02-DECISIONS.md` (D33 and D42 item 5 marked as superseded).
- `docs/14-HUMAN-TASKS.md`: H14 rewritten (no Apple root certificates, no notifications URL, no `APPLE_APP_ID` /
  `APPLE_ENVIRONMENT`; Billing Grace Period on; Terms and Privacy links; App Review notes).
- `docs/store/app-privacy.md` and `PrivacyInfo.xcprivacy`: Purchase History no longer collected; the account token is
  no longer listed. The Keychain is not a required-reason API (`scripts/check-privacy.sh` passes).
- `docs/06-PRIVACY-SECURITY.md`: who sees the purchase, the allowance Keychain item, the modified-app threat.
- `firebase/functions/API.md`, `docs/11-BACKEND-FIREBASE.md`: `reserveRegistration(s)`, `syncPlan`,
  `appStoreNotifications` marked "unused since D59, can be removed after v1". The functions are untouched.
- `DESIGN.md`: Plan legal section, BookingRequest notice.

## How to test

- **Simulator with `Config/BelloHub.storekit`** (already set in the scheme): buy monthly or yearly, then in Xcode →
  Debug → StoreKit → Manage Transactions: refund (the plan leaves through `Transaction.updates`), expire, or turn on
  billing retry and grace period for the subscription; "Restore purchases" calls `AppStore.sync()`.
- **UI tests**: `-uiPlan none|active` and `-uiRegisteredClients N` as before (scripted store, in-memory snapshot and
  allowance). `AccountUITests.testPlanScreenAndPaywall` now also opens the Terms from the paywall.
- **Sandbox on a real iPhone** (a sandbox Apple ID in Settings → App Store → Sandbox Account), with the products
  created in App Store Connect (H14).

## Needs a real iPhone
- A sandbox purchase, and Restore purchases on a second iPhone with the same Apple ID.
- A refund (sandbox: Settings → App Store → Sandbox Account → Manage) reaching the app while it runs.
- Deleting and reinstalling the app keeps the free count (Keychain this-device-only survives the app's deletion).
- Offline use with a plan (flight mode), and the clock moved back and forward in Settings.
- A new iPhone restored from a backup starts with the vault ledger's count (the Keychain item does not move).

## Not run here (no Swift toolchain)
`scripts/build.sh`, `scripts/test.sh fast|smoke`, `scripts/check-warnings.sh`, the UI tests and the device runs. Ran:
`scripts/check-privacy.sh`, `scripts/check-strings.sh --final`, `scripts/check-localization-sources.sh`,
`scripts/check-project-settings.sh` (its first two checks pass; the `plutil` step cannot run on Linux).

## Server follow-up (not done: forbidden by this task)
To stop the online-booking path from asking a paying professional for a plan, the server must stop applying D42 with
a plan it cannot know: for example, `approvalReason` without the `freeRegistrationsUsed` branch and
`respondBookingRequest` without the `needsSubscription` branch, leaving the decision to the app when she approves (the
app's gate already registers the client through `ClientRegistering`). That is a function change plus a deploy, and the
shared rules fixture (`firebase/scripts/rules-fixtures`) would change with it.
