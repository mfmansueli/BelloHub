# s10-account: Account and settings (S10: 7.1 to 7.4, 7.6 to 7.10)

Branch `s10-account`, worktree `.claude/worktrees/agent-a498cf63dedef1f7d`, based on `build/v1` at `7721870`.
Simulator `581B8F64-5D7C-4D9F-B30F-177C13ED50A8`. A first agent built the screens and services and died with 70
uncommitted files; this agent committed them, wired them in, fixed the build, wrote the strings, the tests and
these notes. 7.5 AISettings belongs to S7 and is not here.

## What was built

- **7.1 Account** (`Screens/Account/`): name and business name (saved with the bar's Save, `AccountRules` cleans and
  limits them), the read-only facts (WhatsApp number from the session, profession, booking link), the Language and
  region row, **Sign out moved here from More** (same confirmation dialog, `account.signOutButton`), and **Delete
  account** as a sheet (`DeleteAccountSheet`) driven by the pure `AccountDeletionFlow`: export offered first
  ("Export my data first" opens 7.8 in a sheet), then an explicit "Delete everything?" confirmation, then the
  cascade in `AccountService`: the server (`AccountDeleting`, default `OfflineAccountDeleter` answering `deviceOnly`
  until S8 wires the Firebase function; the request carries the **fresh Apple authorization code**, D44), then
  `wipeEverything()` on the vault, the seed leaves the key store, the account's `UserDefaults` keys go
  (`DefaultsKey.clearedOnAccountDeletion`; the lock settings stay), and only then the session ends, after she reads
  the done screen. Nothing local is touched before the server answered, and nothing before `AccountDeletionFlow
  .deleting` (`allowsWipe`).
- **7.2 LanguageRegion** (`Screens/LanguageRegion/`): the 24 region presets as rows (`RegionPresetRow`), the business
  language (any of the 14), "What this sets" (currency, date, time, week start, phone, messaging channel, privacy law,
  all from `LocalePreview`), the currency menu, week start and clock (`WeekClockCard`, overrides stored on the
  profile as `firstWeekday` / `use24Hour`, nil = the region's default), two quick-reply previews and the cancellation
  rule lines rendered in the chosen language, the client term, and the booking page languages as switches (the
  business language is always on). Rules in `LanguageRegionRules`, draft in `LanguageRegionDraft`, saved through
  `ProfileService.saveProfile`.
- **7.3 Plan** (`Screens/Plan/`, `Managers/Subscription/`): StoreKit 2 behind `SubscriptionProviding`
  (`StoreKitSubscriptionProvider`, the only file importing StoreKit), server verification behind
  `SubscriptionVerifying` (`OfflineSubscriptionVerifier` keeps the store's signed answer until S8),
  `SubscriptionService` as the one reader (feeds `ClientRegistrationService` as `SubscriptionStatusProviding`,
  listens to `Transaction.updates`), `PlanPresentation` with the saving from `PlanSavings` (17 % EUR/USD, 16 % BRL,
  from the store's prices), the yearly card highlighted and chosen by default, buy, restore, manage, grace-period
  state, `Config/BelloHub.storekit` referenced by the scheme. **The paywall is the same screen** (`PlanView(mode:
  .paywall)` inside `PaywallSheet`) with the D42 headline and the reassurance notice; `-uiPlan none|active` picks
  the UI-test store (`UITestSubscriptionProvider`).
- **7.4 NotificationSettings** (`Screens/NotificationSettings/`, `Managers/Notifications/`): the permission flow
  (ask once, then Settings), every switch saved as tapped (`NotificationPrefs` as JSON in `UserDefaults` behind
  `NotificationPrefsStoring`), quiet hours with the 22:00 to 07:00 default and the urgent-alerts note, reminder time,
  the pointer to Privacy for hidden names. **No scheduling here** (S6 "home" owns it).
- **7.6 Integrations** (`Screens/Integrations/`, `Managers/Calendar/`): Apple Calendar on/off through
  `CalendarAccessProviding` (`EventKitCalendarAccess`, the only EventKit import; `UITestCalendarAccess` grants without
  a dialog), the switch remembered in `DefaultsKey.appleCalendarEnabled` (the write-through of appointments is S6's),
  Google Calendar "Coming soon" (H9), WhatsApp / Messages by region, Instagram bio link (opens 6.5 ShareLink), Import
  contacts (opens 4.6 as a sheet).
- **7.7 Privacy** (`Screens/Privacy/`): where the data lives (iPhone, iCloud, servers, nowhere else), recovery-key
  status ("Not saved yet" / "Saved on <date>"), Face ID lock switch and lock-after menu (new `AppLockService
  .setEnabled` / `setGraceSeconds`), photos-stay-in-app, hide names on the lock screen, export all, per-client export
  and deletion pointer, retention, and the **legal texts** (terms + DPA and the privacy policy) read in
  `LegalNoticeSheet` from the bundle (`BundleLegalNoticeLibrary`, files synced by `scripts/sync-legal-resources.py`,
  now also the two notices). The word "draft" never appears; pending operator fields render as the consent screens do.
- **7.8 ExportAll** (`Screens/ExportAll/`, `Managers/Export/`, `Models/Export/`): D18 copy (Save to Files or share;
  no e-mail link), photos optional, "Prepare my export" reads the vault (`ExportSnapshot`), `ExportBundleBuilder`
  writes `clients.csv`, `appointments.csv`, `records.csv` (UTF-8 with BOM, CRLF, escaped), `SummaryPDFRenderer`
  draws `summary.pdf`, `ZipWriter` (store method, CRC-32 from zlib) builds the ZIP, `ProtectedTemporaryFile` writes
  it with complete protection in the app's temp folder, `ShareLink` offers it, and the file is deleted on "Start
  over" and when the screen leaves.
- **7.9 RecoveryKey** (`Screens/RecoveryKey/`, `Managers/Vault/RecoveryKeyService.swift`): 12 masked cells, reveal
  behind Face ID / Touch ID / passcode (`RecoveryKeyService.reveal` asks on every call, never caches), Save to Files
  (protected text file through `ShareLink`), Print (`DocumentPrinting` / `SystemDocumentPrinter`), the
  "I saved it somewhere safe" switch + "I saved my key" (stores a date in `DefaultsKey.recoveryKeySavedAt`), the
  done notice. **Restore on a new phone**: `RestoreKeySheet` from the Locked screen when the key is missing
  (`locked.restoreKeyButton`), words parsed by `RecoveryPhrase`, errors named by position. **Rotation model**:
  `KeyRotationPlan` (generations, retired list, openable set) with tests; no screen in v1. `Managers/Vault/` was
  extended only through `KeyManager.recoveryPhrase()` / `restore(from:)`; the vectors still pass.
- **7.10 Help** (`Screens/Help/`): six common questions as rows that open their answer (`HelpTopics`; not a
  `DisclosureGroup`: outside a List only its chevron toggles, so a tap on the question did nothing), "Write to support" and
  "Send feedback" as `mailto:` links with a localized subject and no body.
- **More**: Preferences section (plan with its status, notifications, integrations, privacy with "Save your recovery
  key" until confirmed, help) and the Account row; the profile card opens Account; sign out left More. `MoreRoute`
  gained nine cases and a `section`; `MoreTab.destination(for:)` now switches per section (four small helpers), under
  SwiftLint's cyclomatic limit without disabling the rule.
- **Root wiring**: `AppDependencies` creates `SubscriptionService`, `RecoveryKeyService`, `AccountService`,
  `NotificationSettingsService`, `CalendarIntegrationService`, `DataExportService` (live and UI-test flavors);
  `RootView` injects them and starts the store listener. `LaunchOptions.uiPlan` (`-uiPlan none|active`).
- **Strings**: `Config/Locale/strings/s10-account.json`, 325 keys in the 12 authored localizations (+ the two derived),
  catalog regenerated, `scripts/check-strings.sh` passes (1359 keys).

## Files and folders owned

`BelloHub/Screens/{Account,LanguageRegion,Plan,NotificationSettings,Integrations,Privacy,ExportAll,RecoveryKey,Help}/`,
`BelloHub/Managers/{Account,Calendar,Export,Notifications,Print,Subscription}/`, `Managers/Legal/LegalNoticeLibrary.swift`
+ `BundleLegalNoticeLibrary.swift`, `Managers/Vault/RecoveryKeyService.swift`, `Managers/Persistence/VaultWipingRepository.swift`
+ the two `+Wipe` extensions, `BelloHub/Models/{Account,Export,Integrations,Legal,Vault}/`, `Models/Plan/{PlanOffer,PlanPeriod,
PurchaseOutcome,SubscriptionState}.swift`, `Resources/Legal/{privacy-policy,terms-dpa}-*.md`, `Config/BelloHub.storekit`,
`Config/Locale/strings/s10-account.json`. Touched: `MoreTab`, `MoreView`, `MoreRoute`, `PaywallSheet`, `LockedView`,
`RootView`, `AppDependencies`, `LaunchOptions`, `DefaultsKey`, `ProfileService` (`saveProfile`), `AppLockService`
(`setEnabled`, `setGraceSeconds`), `ProfessionalProfile` (`firstWeekday`, `use24Hour`), `ClientRecordRepository`
(+ `VaultWipingRepository`), `InMemoryClientRecordRepository` (tables no longer private), the scheme, `UISmoke.xctestplan`.
Tests: `BelloHubTests/Screens/{Account,LanguageRegion,Plan,NotificationSettings,Integrations,Privacy,RecoveryKey,Help}/`,
`Managers/{Account,Subscription,Export}/`, `Managers/Vault/RecoveryKeyServiceTests`, `Managers/Persistence/
RepositoryWipeContractTests`, `Models/{Export,Vault}/`, seven new fakes in `Fakes/`; `BelloHubUITests/AccountUITests`,
`AccountAuditUITests`.

## Integration notes for the coordinator

1. Regenerate `Localizable.xcstrings` after merging (`python3 scripts/merge-strings.py`); the batch is self-contained.
2. `PaywallSheet` no longer has its own texts: `paywall.title`, `paywall.message`, `paywall.reassurance` are shown by
   `PlanContentView` in paywall mode (the `paywall.title` static text that `ImportClientsUITests` waits for is the
   in-content headline). The sheet is no longer `.medium`: it is a full plan screen with a Close button.
3. `MoreView` lost `onSignOut`; `MoreTab` still takes it and hands it to `AccountView`.
4. The in-memory repository's tables are no longer `private` (the `+Wipe` extension needs them). The `+Catalog`,
   `+Forms`, `+BookingSetup` extensions were already using the non-private ones.
5. S8 replaces `OfflineAccountDeleter` with the Firebase function call (`deleteAccount.appleAuthorizationCode`) and
   `OfflineSubscriptionVerifier` with the server check; both are one-file swaps in `AppDependencies.makeLive()`.
6. S6 "home" reads `NotificationSettingsService.prefs` (and `hideNamesOnLockScreen`) for scheduling; S6 "calendar"
   reads `CalendarIntegrationService.isConnected` for the EventKit write-through.
7. 7.5 AISettings is wired: `MoreRoute.aiSettings` (`.preferences`), `MoreTab.preferencesDestination`, the
   `more.aiSettingsRow` row (`more.row.aiSettings`), walked by `AccountAuditUITests`.
8. `UISmoke.xctestplan` skips `AccountAuditUITests` like the other audits.

## Decisions and assumptions (ASSUMPTION candidates)

- **Delete account order** (plan: "export first, then cascade"): the sheet offers the export, then asks "Delete
  everything?"; the server is called first so a refusal never leaves an empty iPhone with a live account; the vault,
  seed and account keys go only after the server answered; the session ends after the done screen. Before S8 the
  outcome is `deviceOnly` and the done screen says the booking side is closed by the team shortly after.
- **The Apple authorization code is taken at the moment of deletion** and never stored (five-minute, single-use).
  An Apple account (`AuthUser.method == .apple`) confirms the deletion with the native `SignInWithAppleButton` on
  the confirmation step (`deleteAccount.appleButton`, same look as Welcome); `AccountViewModel` reads the credential
  through `AppleCredentialProviding` (the VM imports `AuthenticationServices` only for the button's request/result
  types, like `AppleSignInViewModel`) and calls `deleteAccountAsync(appleAuthorizationCode:)` with the fresh code.
  Without a code (nil, or an Apple answer without one) the server is never called and nothing is wiped
  (`account.delete.apple.error`); closing the sheet shows nothing. A phone account keeps the plain destructive
  button. UI tests tap the shared `UITestAppleOverlay` (now its own file), which calls `deleteWithDevStub()`; the
  dev credential carries `authorizationCode: "dev-code"`.
- **Device settings survive deletion**: `lock.enabled` and `lock.graceSeconds` stay; everything in
  `DefaultsKey.clearedOnAccountDeletion` goes.
- **Yearly saving rounds plainly**: 149.99 vs 12 x 14.99 = 17 %; 399.90 vs 12 x 39.90 = 16 % (D42 says "about 17 %").
  The number comes from `Product.price`, never typed in code.
- **The paywall is the Plan screen in a sheet**, with an inline bar title "Your plan" and the D42 headline in the
  content (ASSUMPTION-20 stands).
- **Plan default choice**: the highlighted (yearly) card is chosen once the offers arrive, unless she tapped a card
  before (`PlanViewModel.choose`).
- **Week start and clock overrides live on the profile** (`firstWeekday`, `use24Hour`, nil = region default) so the
  booking page and the messages read the same values as the app.
- **Choosing a region resets the overrides and the page languages** to the region's defaults; changing only the
  language keeps the other page languages.
- **Notification preferences are a device setting in `UserDefaults`** (not in the vault): they are not client data.
  The reminder time is minutes from local midnight.
- **Apple Calendar "connected" = switch on and iOS allows writing**; the switch alone is remembered. Write-only access
  (iOS may answer that) counts as connected for the write-through.
- **Export**: everything is always in except photos (her choice, they make the file large); the ZIP uses the store
  method (CSV and PDF do not need compression, and Files/Numbers/Excel open it); photo folders are named after the
  client (file-safe) with ISO timestamps; the file name is `bellohub-export-<yyyy-mm-dd>.zip`.
- **Recovery key reveal asks on every call** (`unavailable`, no passcode, counts as passed like the app lock); the
  revealed phrase lives only in the ViewModel and leaves with the screen; the saved status is a local date, nothing
  secret is ever in `UserDefaults`.
- **Restore lives on the Locked screen** when the key is missing (ASSUMPTION-29 stands), not in Privacy.
- **Key rotation**: model only (`KeyRotationPlan`), no screen in v1; every generation derives from the same seed, so a
  rotation needs no new secret.
- **Help**: static questions (six) and `mailto:support@bellohub.app`; no chat ("Chat with support" of the prototype
  is not built: there is no support desk yet).
- **Legal texts**: the newest version in her language, else English; the status field is read but never shown.

## Deviations from the prototype

- 7.1: no photo (initials stand in; a note says so), no "Change photo" sheet; the email field is not editable (the
  session has no email); city is not a field (the region row covers it). Sign out's subtitle says "any time" instead of
  "with your phone" (Apple sign-in, D44).
- 7.3: no trial lines (D33/D42); the two price cards replace "Free trial · ends Oct 12".
- 7.6: Google Calendar is a "Coming soon" row (H9); Apple Calendar is a switch, "two-way sync" is not claimed (the
  write-through is one way in S6).
- 7.8: D18 copy (no e-mail link, no format choice, no 7-day text).
- 7.9: the words are real (behind Face ID), not the prototype's example.
- 7.10: no chat; the feedback sheet is a mail subject.

## DESIGN.md additions (for the coordinator to fold in)

- Screens: 7.1 Account, 7.2 Language and region, 7.3 Plan / paywall, 7.4 Notifications, 7.6 Integrations, 7.7 Privacy
  and security (+ Legal notice sheet), 7.8 Export all my data, 7.9 Recovery key (+ Restore key sheet from Locked),
  7.10 Help. Navigation tree: More → Preferences {Plan, Notifications, Integrations, Privacy {Recovery key, Export
  all, Legal notice}, Help}, More → Account {Language and region, Delete account sheet {Export all}}, Locked →
  Restore key sheet, New client / Import → Paywall sheet (Plan).
- Components reused: `SettingsSection`, `ToggleRow`, `ChoiceCard`, `MoreRow`, `ListCard`, `HeroCard`, `InlineNotice`,
  `ErrorNotice`, `FooterNote`, `SuccessSeal`, `Skeleton`. New in this slice (feature-local, not Design System):
  `RegionPresetRow`, `WeekClockCard`, the 12-word grid (three columns up to the default size, two at the larger sizes, one at
  accessibility sizes, no line limit or shrinking, `privacySensitive`,
  forced left-to-right), the preview bubbles (`Palette.surface`, tile radius, the chosen language's direction).
- States: Plan (checking / none / active renews / active ends on / grace; offers loading skeleton; store error with
  retry; purchased / restored / nothing to restore / pending / failed notices), Export (idle / preparing / ready /
  error), Recovery key (masked / revealed / not recognized / no key / done), Delete account (offer / confirm /
  deleting / done per outcome / error), Notifications (ask / denied / granted), Integrations (available / connected /
  denied in Settings / coming soon).
- No new tokens, colors or fonts: every pair already has a contrast test.

## Results

- `scripts/test.sh fast`: 1448 tests in 189 suites pass (the strings, legal, profession and health-form gates
  included). Two `SyncStatusService` tests flaked once under the full parallel run (timing waits) and passed on the
  rerun; they are untouched by this slice.
- `scripts/test.sh smoke`: see "State at the checkpoint".
- `scripts/check-warnings.sh`, audit in `en,ar`: see "State at the checkpoint".

## Merge of build/v1 (commit 4b96ada)

82 commits merged. Conflicts and how they were resolved, both sides kept: `AppDependencies` / `RootView` (S10's six
services next to S6/S7/S8's; `NotificationService` gets the prefs store of the same `defaults` suite);
`ClientRecordRepository` (union: `TimeBlockRepository`, `MessageLogRepository`, `VaultWipingRepository`);
`DefaultsKey` (both key sets; `aiPreferences` and `publishingOnlineUserID` join `clearedOnAccountDeletion`);
`LaunchOptions` (`uiPlan` next to `uiVoice`/`uiCamera`/`uiOnline`); `MoreTab`/`MoreView` previews and environment;
`UISmoke.xctestplan` (both audit skips). `NotificationPrefsStoring` / `DefaultsNotificationPrefsStore` existed on
both sides: build/v1's `Sendable` struct shape won, with S10's throwing `save` kept so the settings screen keeps its
error state (`FakeNotificationPrefsStore` is now lock-based). `Localizable.xcstrings` was taken from build/v1 and
regenerated. Two things found on the way: the owner's "saving progress" commit had let an Xcode build write 22
extracted stubs into the catalog (and a `CFBundleName` stub into `InfoPlist.xcstrings`), so `merge-strings.py` now
drops every entry that is not `extractionState: manual`, the InfoPlist stub was removed, and the one real key among
them (`recordTemplate.kind.multiChoice`, used by `RecordFieldKind`) got a row in `s4-tags-record-template.json`.
`scripts/sync-server-contract.sh` had to run (the merged contract was not in the test bundle).

## Not done

- No photo on the Account screen (camera/library) and no email field: a later stage.
- Server deletion and server subscription verification are S8 (`OfflineAccountDeleter`, `OfflineSubscriptionVerifier`).
- Google Calendar (H9), a support chat, key rotation screen.
- Notification scheduling and the calendar write-through are S6's.

## State at the checkpoint

Updated at the end of the session; see the last commits on `s10-account`.

## Next commands

```
cd .claude/worktrees/agent-a498cf63dedef1f7d
export SIM_UDID=581B8F64-5D7C-4D9F-B30F-177C13ED50A8
scripts/test.sh fast
scripts/test.sh smoke
scripts/check-warnings.sh
AUDIT_LOCALES=en,ar scripts/test.sh full   # or run AccountAuditUITests alone
```
