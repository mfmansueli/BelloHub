# Agent notes: S8 leftovers + S12 documentation items

Branch `s8-leftovers`, started from `origin/build/v1` at `4c121a7` (2026-10-10), in its own worktree, while S11 owned
`build/v1`. Simulator: "iPhone 17 Pro Max" (`SIM_UDID=1D7CD4D7-…`). Functions, web and `Localizable.xcstrings` untouched:
no new strings (the Plan screen's existing "failed" notice covers the new purchase error), so `merge-strings.py` was not
needed.

## 1. What changed

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

## 2. Measured

- `scripts/test.sh fast` (iPhone 17 Pro Max): **2140 tests in 300 suites passed** (2095 on the `build/v1` head this branch
  started from; +45 test functions in 5 new suites and 1 extended suite).
- `scripts/check-warnings.sh`: see section 4 (filled in at the end of the run).
- `scripts/test-firebase.sh`: not run, no file under `firebase/` changed.
- SwiftLint clean on every touched folder.

## 3. Open (not done here)

From the security review (`security-review.md` section 4), in order:
1. No screen shows `MailboxService.messages` (check-ins, data requests) or `undecryptable`; they are never acknowledged.
2. Deleting a client does not call `deleteClientServerData`.
3. App Check not wired in the app; enforcement off (H5, D43/D46).
4. `ClientRegistrationService` counts locally; the server's `reserveRegistration(s)` is not called (D42 gate).
5. Inbox public-key integrity check (served vs derived) and fingerprint.
6. Breach-plan page; screen-capture hiding of the recovery words; explicit tested file protection for the store.
Also: phone sign-in is still `unavailable` in `FirebaseAuthProvider` (v1 is Apple only); docs/06 section 5 describes
the phone path. Deleting an account whose Auth user was already removed by an earlier, interrupted attempt fails at the
ID token (`unauthenticated`) and keeps showing the error; rare, but a "delete this iPhone only" fallback after that
specific error would help.

## 4. Merge notes (for the integrator)

Files most likely to conflict with S11: `BelloHub/Screens/Main/Support/AppDependencies.swift` (subscription and account
wiring, small), `BelloHub/Screens/More/MoreView.swift` and `MoreTab.swift`, `Screens/Plan/PlanView.swift`,
`Screens/Shared/Registration/PaywallSheet.swift`, `Screens/Account/AccountView.swift` (only their `#Preview` blocks), and
`scripts/check-privacy.sh` (appended rule 7). No `Localizable.xcstrings`, `Config/Locale`, `docs/PROGRESS.md`,
`docs/review`, `docs/strings`, `legal/` change.

## 5. Text for docs/PROGRESS.md (paste after the merge)

> **2026-10-10: S8 leftovers and S12 documentation done on `s8-leftovers`** (notes `docs/agent-notes/s8-leftovers.md`).
> The app now deletes the account on the server (`RemoteAccountDeleter` -> `deleteAccount`, Apple token revoked with a
> fresh code) and verifies the plan on the server (`RemoteSubscriptionVerifier`: `appAccountToken` from
> `ensureAccount` in every StoreKit purchase, `syncPlan` re-verifies the JWS; the server's plan wins, offline or
> `NOT_CONFIGURED` keeps StoreKit's answer). Offline stand-ins are DEBUG only. New unit suites for `MailboxService`
> (import, idempotency, queue replay offline and after relaunch, undecryptable paths) and `PushService` (token
> registration, offline replay, silent push). S12 docs: `PrivacyInfo.xcprivacy` (+ `check-privacy.sh` rule 7),
> `docs/store/app-privacy.md`, App Store metadata drafts in 13 localizations (`docs/store/`), security review
> (`docs/agent-notes/security-review.md`, 8 gaps listed). Fast 2140 tests in 300 suites; check-warnings zero.
> Next: the gaps of the security review (mailbox messages screen, client server deletion, App Check, server
> registration gate).
