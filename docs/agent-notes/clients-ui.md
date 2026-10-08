# clients-ui: Clients list, profile, new client, edit, knowledge (S4 slice 2)

Branch worktree based on `build/v1` at 407427e. Screens 2.2 Clients, 4.1 ClientProfile, 4.2 NewClient, 4.3 ClientEdit
(with archive, restore and merge), 4.4 ClientKnowledge. Everything written in English; strings in 14 localizations.

## What was built

- **2.2 Clients** (`Screens/Clients/ClientsView`, `ClientsViewModel`): a native `List` (lazy, pull to refresh, native
  search), filter chips (All, Due to return, Cancels often, New, one per tag, Archived while someone is archived), the
  count in the word she chose (`1 patient`, `12 patients`), the "have not been back in 2+ months" strip (plain text, no
  dead tap until WinBack 2.8 exists), loading skeleton, empty state (Add + Import, no "Share your link" until S8), error
  state with retry, and a warning notice when a refresh fails over old data. Toolbar: Import and Add.
- **4.1 ClientProfile**: hero (avatar, name, labels, Call), important note and allergies card, session-plan progress
  card, last visit and next appointment tiles, client-knowledge chips with an Edit action, Health and consent row
  (`ClientsRoute.health`), habits card, "Edit" in the navigation bar (`ClientsRoute.edit`).
- **4.2 NewClient** (sheet): name (required), WhatsApp (normalized with `PhoneNormalizer` in the business region, problem
  inline), email (light check), tags with "+ New tag" (saved through the business repository), private note, the
  free-registration note with the live counter, "Import many at once" (opens `ImportClientsView(onViewClients:)`),
  Save through `ClientRegistering.register`: `.registered` opens her profile, `.needsSubscription` shows `PaywallSheet`,
  `.duplicate` shows a notice with "Open existing profile". Unsaved changes ask before the sheet closes.
- **4.3 ClientEdit** (pushed on the stack, back button replaced by Cancel): name, WhatsApp, email, birthday (day and
  month menus, optional year), tags, stop online booking with a private reason, reminders switch, Archive (confirmation)
  or Restore, Merge with a duplicate (sheet, picker with search, confirmation). Saves go through `register` (`.updated`).
- **4.4 ClientKnowledge** (pushed, Cancel/Done): the private note plus the lists `sensitivities`, `preferences`,
  `recurringRequests` in a native `List` kept in edit mode (delete and reorder handles, always visible). Done saves.
- **Merge** (`ClientRepository.mergeClient(keeping:merging:)`, added to the protocol, `SwiftDataClientRecordRepository`
  (new file `+Merge`) and `InMemoryClientRecordRepository`) with the pure `ClientMerger` in `Models/Client/`.
- **Call**: `PhoneLaunching` protocol + `PhoneLauncher` (`tel:` through `UIApplication.open`) in `Managers/Clients/`.

## Files and folders owned

- `BelloHub/Screens/Clients/**` (View, ViewModels, `Cards/`, `Rows/`, `Profile/`, `Form/`, `Knowledge/`, `Support/`,
  `Placeholders/`), `BelloHub/Screens/Shared/Observation/TaskBag.swift`.
- `BelloHub/Managers/Clients/PhoneLaunching.swift`, `PhoneLauncher.swift`.
- `BelloHub/Models/Client/ClientMerger.swift`; merge in `ClientRepository.swift`, `InMemoryClientRecordRepository.swift`
  (an extension at the end of the file, because the stores are `private`), `SwiftDataClientRecordRepository+Merge.swift`.
- Wiring: `BelloHub/Screens/Main/MainView.swift` (the Clients tab is now `ClientsTabView()`, and the preview got the
  Services it needs), `BelloHub/SupportFiles/UITestSeeding.swift` (`-uiSeed clients`, DEBUG).
- Design system, additive only: `EmptyState` accepts `Text` title and message (the old `LocalizedStringKey` init is
  unchanged), `Icon.chevronUpDown`.
- Tests: `BelloHubTests/Screens/Clients/**`, `Models/Client/ClientMergerTests`,
  `Managers/Persistence/RepositoryClientMergeContractTests`, `Managers/Clients/PhoneLauncherTests`,
  `Fakes/FakePhoneLauncher`, `BelloHubUITests/ClientsUITests`, `ClientsAuditUITests`, `Support/XCUIApplication+Clients`.
- Strings: `Config/Locale/strings/s4-clients-ui.json` (144 keys). The row `clients.empty.title` moved out of
  `s3-shell.json` into it (its text changed to "No %@ yet" and takes the term).

## Integration notes for the coordinator

1. **Delete `BelloHub/Screens/Clients/Placeholders/`** (`ClientHealthView(clientID:)` and
   `ImportClientsView(onViewClients:)`) when the health-forms and import slices land. `ImportClientsView` is presented
   as a sheet with no wrapper, so the real one must bring its own `NavigationStack` (the placeholder does).
2. `ClientsTabView` reads `VaultService`, `ProfileService` and `ClientRegistrationService` from the environment (all
   three are already injected by `RootView`).
3. `Localizable.xcstrings` was regenerated here (`merge-strings.py`); regenerate it again after merging the batches.
4. `scripts/check-strings.sh` passes; `clients.empty.title` is defined only in `s4-clients-ui.json`.
5. `Config/TestPlans/UISmoke.xctestplan` skips `ClientsAuditUITests` like the other audits.
6. The tags slice (6.12) will probably change `ProfileService`; the new-client sheet only needs `profile.tags`,
   `profile.profile` and `profile.load()` (called after it saves a tag through `repository.save(tag)`). If that slice
   adds a `ProfileService.saveTag`, `ClientFormViewModel.addTag(named:)` should call it instead.

## Decisions and assumptions (ASSUMPTION candidates)

- **"New" = no completed visit yet** (the badge, the chip and the filter). It is the only rule not owned by
  `HabitsCalculator` or `FollowUpPlanner`. "Cancels often" and "Due to return" read those owners' results; the unit tests
  pin the exact boundaries (3 vs 4 visits, 30 percent of the last ten, 27 vs 28 days with a 4-week follow-up).
- **Archived clients** leave every chip but "Archived", which only appears while someone is archived; the way back is the
  "Restore" row on the edit screen (also reachable from the archived chip).
- **The registration gate does not catch a phone clash on an edit**: `ClientDuplicateRules.existing` returns the client
  with the same id first, so giving client A the number of client B comes back `.updated`. `ClientFormViewModel` checks
  that with `ClientDuplicateRules` (excluding the client herself) before it calls `register`. If the gate should own
  this, move the check there; the form's test `editDuplicate` documents the behavior.
- **Merge**: the kept profile wins; the other fills the gaps (phone, email, birthday, no-show reset); tags and the four
  lists join without duplicates (case, accent and width insensitive); two different notes become two paragraphs;
  booking stays stopped and reminders stay off if either profile had them that way; two archived stay archived, an
  active one merged into an archived one brings her back; `createdAt` is the earlier of the two. A phone number that the
  kept profile already has a different one for is dropped (the other's number is not kept anywhere). The ledger is never
  touched. The repository reads every record strictly first (an unreadable record stops the merge instead of being
  orphaned) and rolls the SwiftData context back on any write failure. A merge bypasses the 24-hour record lock because it
  changes only the owner.
- **Edit and knowledge are pushed**, with Cancel in place of the back button (a confirmation when something changed),
  because `ClientsRoute` already models them as stack routes. New client is the only sheet.
- **Knowledge screen also edits the private note** ("Important to know"), the only place to change it after creation;
  `allergies` stay with the health screen (4.5). The profile shows both.
- **Pending text in an "add" field is added by Done** instead of being lost.
- **Neutral wording**: no "she" in the copy that mentions the client (the stop-booking subtitle, the reminders switch, the
  archive message), the stop-booking and archive titles carry the client's first name or the professional's term; French
  uses "fiche (client)" for titles so there is no article or agreement; "Found you via" became "Source" and "New"
  became "First visit" in the Romance languages, Hindi and Arabic (neutral); the "have not been back" strip uses a colon
  form in French, Hindi and Arabic. The two existing sign-in sentences for a bad phone number are reused.
- Empty-state title uses the professional's plural term ("No patients yet") with wording that needs no agreement.

## Deviations from the prototype and design additions

- Omitted on purpose (their stages do not exist yet): Message and Book quick actions, the history, photos and products
  tabs, the "Send my booking link" switch, "Save and book appointment", "Add photo" and "Change photo" (photo pipeline,
  S7), "Delete client data" (S10), "Share your link" in the empty state (S8), no-show history, export and incident rows.
- The profile has no segmented Overview/History/Photos/Products control (only Overview exists).
- "Late cancellations" shows the count only, not "1 · Jun 3": the date would need the "late" definition again, which
  `HabitsCalculator` owns.
- Design additions: an "Archived" filter chip, a Restore row, a warning notice over a list showing old data after a
  failed refresh, a "this profile is no longer here" state, a merge picker with search, an inline "this number is
  already saved" notice with a button to open her, hero labels "cancels often" and "archived".
- The prototype's dashed "+ New tag" chip is a regular outline chip (the chip style has no dashed variant).

## Findings

- `ClientRegistrationService.register` treats the same id as an edit before it looks at the phone (see above).
- `FakeClientRegistrar` records but does not save, so VM tests that need the vault to change use the real
  `ClientRegistrationService` over `InMemoryClientRecordRepository`.
- `InMemoryClientRecordRepository` was at the type-body limit of SwiftLint (250 lines): the merge lives in a same-file
  extension.
- `SwiftUI`'s `move(fromOffsets:)` and `remove(atOffsets:)` pull SwiftUI into a ViewModel (`MemberImportVisibility`), so
  `KnowledgeListRules.moving` and `removing` are pure Foundation versions with tests that pin the `onMove` convention.
- 2,000 clients with 16,000 appointments: building the entries, four chips, a name search, a phone search and a sort
  are each well inside the bounds the performance test asserts (see the test for the measured values in its message).

## Open questions

- Should the gate own the phone-clash check on edits (see decisions)?
- Is "First visit" the right neutral word for "New" in pt, es, it, fr, hi and ar? (needs_review like the rest.)

## Tests

See the final report of the session for counts. Pure suites: `ClientListFilter`, `ClientSearch`, `ClientSort`,
`ClientListBuilder` (with the 2,000-client speed test), `ClientFormRules`, `BirthdayInput`, `KnowledgeListRules`,
`ClientProfileBuilder`, `ClientMerger`, `Formatters` client dates, `PhoneLauncher`, contrast; ViewModels: `ClientsViewModel`,
`ClientProfileViewModel`, `ClientFormViewModel` (new and edit), `ClientKnowledgeViewModel`, `ClientMergeViewModel`;
repository contract: merge on both vaults. UI: `ClientsUITests` (one flow), `ClientsAuditUITests` (list, empty, new client,
profile, edit, merge, knowledge; `AUDIT_LOCALES` narrows the run).

## Strings batch

`Config/Locale/strings/s4-clients-ui.json` (es-419 and en-GB are derived; no override needed).
