# s8-publish: the booking link really works (S8 iOS half, slice "publish")

Branch `s8-publish`, worktree `agent-ae6aa117cf4712fe2`, based on `build/v1` at c3a65ad (after the S6 calendar merge).
The backend and the web are deployed to `bello-hub` (dev, D43); the app now talks to them through one HTTP client, and
nothing in any test plan reaches the network. Strings in `Config/Locale/strings/s8-publish.json` (24 keys, 14
localizations). The first agent died with 36 files uncommitted; the second committed them as three commits and finished
the tests and the notes.

## What was built (paths under `BelloHub/` unless noted)

### Server access (`Managers/Server/`)
- `CallableClient` (protocol) and `URLSessionCallableClient`: a Firebase callable is `POST <base>/<name>` with
  `{"data": …}`, `Authorization: Bearer <ID token>`; the answer is `{"result": …}` or `{"error": {status, message,
  details}}`. `HTTPTransport` (protocol) + `URLSessionTransport` so the client is tested with `FakeHTTPTransport`.
- `IDTokenProviding` + `SessionIDTokenProvider`: the token comes only from `SessionService.idToken()` (which asks the
  `AuthProvider`; `LocalDevAuthProvider` returns a fake token in DEBUG, `UnconfiguredAuthProvider` throws).
- `CallableErrorMapper` → `ServerError` (one case per code of `API.md` section 3, `INVALID_ARGUMENT` with field paths,
  `RATE_LIMITED` with the wait; a body that is not ours is judged by the HTTP status; `isRetryable`).
- `CallableJSON`: ISO-8601 UTC with milliseconds both ways, sorted keys (payloads compare byte for byte).
- `Models/Booking/ServerConfig`: `BELLO_FUNCTIONS_BASE_URL` and `BELLO_WEB_BASE_URL` from `Config/App.xcconfig` through
  `Config/App-Info.plist`; `BookingLink.defaultBaseURL` reads `webBaseURL` (D54: `https://bello-hub.web.app`).

### Booking server (`Managers/Booking/`)
- `BookingRepository` extended: `ensureAccount`, `claimSlug`, `publishProfile`, `publishAvailability`,
  `setOnlineBookingStopped`, `updateInboxKey`. `RemoteBookingRepository` implements it over `CallableClient`;
  `BookingRepositoryError` grew `busy`, `unauthenticated`, `slugTaken`, `slugInvalid`, `rejected`.
  `OfflineBookingRepository` (no server) throws `notPublishedYet`; `UITestBookingRepository` (DEBUG, `-uiOnline fake`)
  is an in-memory server with the taken addresses `ana`, `taken` and the reserved `admin`, `help`, `support`.
- `Models/Booking/Publishing/`: `PublishProfileRequest`, `PublishAvailabilityRequest`, `AccountInfo`, `InboxPublicKey`,
  `PublishInputs`, `PublishState`, `PublishFailure`, and `PublishPayloads` (pure, the one owner of what goes to the
  server): active services with lower-case ids, prices as she shows them, credentials she chose to show, locales (the
  business language first, at most six), the rules text from `PolicyRuleText` per locale, the policy snapshot, booking
  switches from the page settings and the pause, the public inbox key; the availability with hours, breaks, days off,
  buffer/notice/window and `busy` = manual appointments that hold a time (`kind:"appointment"`) plus time blocks
  (`kind:"block"`), never a link booking (`bookingID != nil` or `origin != .manual`), capped at 600, same `timeZoneID`
  as the profile. `blocker(_:)` says why a page cannot go online (`needsAddress`, `needsService`).
- `PublishingService` (`@MainActor @Observable`, created in `AppDependencies`, in the environment from `RootView`):
  `notOnline / publishing(wasOnline:) / online / paused(until:) / error(failure, wasOnline:)`. She decides with
  `goOnline()`; after that every vault change republishes by itself, debounced (2 s), one publish at a time with a
  dirty flag, idempotent (a payload equal to the last accepted one is not sent). Failures are honest: offline/busy/locked
  retry by themselves (15 s, 60 s, 5 min), the rest wait for `retry()` or a change; `addressTaken` forgets the claimed
  slug. `stop()` publishes the page as not taking bookings (there is no unpublish on the server) and forgets the
  choice. `clear()` on lock, `clearForSignOut(userID:)` on sign-out; the choice to be online is kept per user in
  `DefaultsKey.publishingOnlineUserID`, so a relaunch resumes. `PublishingSource` (protocol) + `VaultPublishingSource`
  read the vault and watch it (any vault write re-emits the appointments stream).
- `Managers/Vault/InboxKeyProviding` + `KeyManager+InboxKey`: the inbox key pair (X25519) is derived from the recovery
  seed (docs/06 section 4.1, generation 1), so there is nothing new to store; `KeyManager` already held
  `inboxPrivateKey(generation:)`. Only the public half leaves the phone, in `profile.inboxKey`.

### Screens
- `Screens/BookingSettings/Support/PublishStatusText` (pure): the one owner of what the More row, the link card and
  Share your link say for each state. `Cards/PublishFailureNotice`: the failure line with "Try again" when it helps.
- `BookingLinkCard`: the status line is the real state ("Preview only. The link works once you go online." /
  "Online. Clients can book you with this link." / paused / updating / stale) and a `Go online` button on the hero
  before she is online. `BookingSettingsContentView`: failure notice, `Stop` button (confirmation dialog) when live.
  `ShareLinkView`: online or preview notice, `Go online`, failure notice; the address check goes through
  `publishing.repository`. `MoreView`: the Booking page row says "Not online yet" until the page is published, then
  the page summary ("Taking bookings", "Paused until …"), "Needs attention" after a failure with no page yet.

### Tests
- Unit: `CallableErrorMapperTests`, `URLSessionCallableClientTests` (fake transport), `ServerConfigTests`,
  `PublishPayloadsTests`, `PublishAvailabilityPayloadTests` (both check every request against the backend's published
  schemas with `ServerContract`, a byte-for-byte copy of `firebase/functions/contracts/schemas.json` in
  `BelloHubTests/Resources/ServerContract/`; `scripts/check-server-contract.sh` fails on drift, runs in `test.sh`),
  `RemoteBookingRepositoryTests`, `PublishingServiceTests` + `PublishingServiceFailureTests` (state machine with
  `FakeBookingRepository` scripts and `FakePublishingSource`, injected sleeper and clock), `InboxPublicKeyTests`,
  `InboxVectorsTests` (opens every envelope of `web/test/vectors/inbox-v1.json` with CryptoKit `HPKE.Recipient` and
  the suite of docs/06, rejects the tampered ones, and checks the key id derivation: pins the suite shared with the
  web and the backend; the vector file is copied by the same sync script), `PublishStatusTextTests`.
- UI: `PublishUITests` (UISmoke): go online from Share your link against the fake server, the card and the More row
  follow, Stop; and without a server the page stays a preview with an honest failure. `BookingSetupAuditUITests` got
  `testPublishStatesAtDefaultSize` (en, ar; preview, online, paused online, stop confirmation) and
  `testPublishFailureAtDefaultSize` (en, ar), both in the Full plan.

## Assumptions and deviations
- ASSUMPTION: "public services" = active services (`Service.isActive`); there is no separate "show on the page" flag
  in the model yet. Add-ons are published when active.
- ASSUMPTION: the More row hides the pause summary while the page is not published ("Not online yet" wins), because
  a pause of a page nobody can reach is not information for her. `BookingSetupUITests` was updated for this.
- Stop = publish as "not taking bookings" (no unpublish on the server); the address stays hers.
- The inbox private key is derived from the seed, not stored in a key-store slot of its own (docs/06 §4.1 already
  says so); reading the mailbox is the next slice.
- `UITestBookingRepository` is the only "server" any test plan touches; `-uiOnline fake` is a DEBUG launch argument.

## DESIGN.md additions (to fold in at integration)
- 6.7 Booking page: hero status line per publish state; `Go online` (`.belloOnHero`) on the hero before online;
  `Stop` (`.belloSecondary`) under the share row with a destructive confirmation dialog; failure notice
  (`ErrorNotice`, "Try again" only for offline/busy/locked/rejected).
- 6.8 Share your link: `InlineNotice` "online" / "not online yet", `Go online` (`.belloPrimary`), failure notice.
- More: Booking page row subtitle "Not online yet" / "Needs attention" before the page exists.
- Identifiers: `bookingSettings.{notOnline,onlineStatus,goOnlineButton,stopButton,stopConfirmButton,publishError}`,
  `shareLink.{online,notOnline,goOnlineButton,publishError}`.

## Results (2026-10-09, sim `9094A22B`)
- `scripts/test.sh fast`: 1630 unit tests in 203 suites, all pass.
- `scripts/test.sh smoke`: 27 UI tests, 0 failures (742 s), `PublishUITests` and `BookingSetupUITests` included.
- `scripts/check-warnings.sh`: zero warnings on simulator, device, Release and the test targets (SwiftLint included).
- `scripts/check-strings.sh`: 1222 keys, all 14 localizations complete. `scripts/check-server-contract.sh`: ok.
- Not run: the Full plan (the two new audit walks in `BookingSetupAuditUITests` compiled but were not executed; run
  `TEST_RUNNER_AUDIT_LOCALES=en,ar scripts/test.sh full` or the two tests alone at integration).

## Not done (later slices)
- Reading the sealed mailbox (`MailboxService`, HPKE open in the app, outbound queue), FCM and silent push.
- `BookingSyncService` (bookings from the server into the agenda): the availability `busy` already excludes link
  bookings so they are not blocked twice once they arrive.
- Passing the Apple authorization code at deletion (S10).
- Live verification against `bello-hub` on a real iPhone (needs a signed-in Apple user; the dev auth is a stub).

## State at the checkpoint
Everything is committed on `s8-publish` (clean tree); nothing was left running. Ready to merge into `build/v1`
(regenerate the catalog with `python3 scripts/merge-strings.py`, then fast, smoke, warnings; fold the DESIGN.md
additions above and this note into `docs/PROGRESS.md`).

## Next commands
```
cd .claude/worktrees/agent-ae6aa117cf4712fe2
SIM_UDID=9094A22B-D96D-4AB6-8132-AAC9C1D88AFE scripts/test.sh fast
SIM_UDID=9094A22B-D96D-4AB6-8132-AAC9C1D88AFE scripts/test.sh smoke
scripts/check-warnings.sh
scripts/check-strings.sh
```
