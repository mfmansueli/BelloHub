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
