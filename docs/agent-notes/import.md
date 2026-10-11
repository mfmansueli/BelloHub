# Agent notes: `import` slice (S4, screen 4.6 ImportClients)

Branch based on `build/v1` at 407427e. Everything below is in English; the owner reads Portuguese.

## What was built

Screen 4.6 ImportClients, end to end, plus the tests of the registration gate (D42).

- **Flow** (`ImportClientsView(onViewClients:)`, presented as a sheet by other slices, with its own navigation bar):
  sources, then (spreadsheet only) column mapping, then "Choose clients", then the result.
  - Sources: "Phone contacts", "Spreadsheet", "Other booking apps" (not a button, "Coming soon"), the
    `RegistrationLimitNote` (explainer plus "x of 10 used") under the choices, a footnote that Excel/Numbers files must
    be exported as CSV, and a footnote on contact privacy.
  - Choose: native lazy `List` (2,000 rows stay fast), select all / clear, "Selected: n of m", the primary button
    "Import n clients" (disabled with "Choose at least one"), rows that cannot be imported listed apart with the reason.
    When the batch is larger than the free slots left, an amber notice says how many go through now and that the rest
    need a plan (`ImportBatchFit`).
  - Result: `n new registrations` (or "Nothing new was added"), duplicates skipped, entries skipped (malformed), and
    when `blocked > 0` a card "n more need a plan" with a "See plans" button that opens `PaywallSheet`. "View clients"
    calls `onViewClients`, then dismisses.
  - Imports go through `ClientRegistering.importClients` only; clients have `source = .importedClients` and new UUIDs.
    `ClientImportResult.malformed` is filled by the ViewModel (rows that never reached the gate).
- **Contacts**: `ContactsImporting` protocol + `SystemContactsImporter` over the system `CNContactPickerViewController`
  (`ContactPickerSheet`, presented by the `.contactPicker(for:)` modifier). The picker runs outside the app, needs no
  permission and returns only the contacts she ticked, so nothing else of the address book is ever read.
  `ContactCandidateMapper` (the only place that reads a `CNContact`, key by key with `isKeyAvailable`) returns plain
  `ImportCandidate` values. Name = given + family, else nickname, else organization. A contact with several numbers
  uses the first **mobile** one that normalizes (CNLabelPhoneNumberMobile/iPhone or a label that says mobile in any of
  the languages, `PhoneLabelClassifier`), else the first valid one.
- **Spreadsheet**: `.fileImporter` (CSV, TSV, plain text), `SystemImportFileReader` (security-scoped, 20 MB cap,
  off the main actor), `ImportTextDecoder` (BOM, UTF-16 without BOM, UTF-8, Windows-1252, Latin-1), `CSVParser`
  (RFC 4180, `,` `;` TAB auto-detected, quotes with delimiters/newlines/`""`, CRLF/LF/CR, BOM, blank lines dropped but
  still counted so row numbers match Excel), `ImportTable` (drops "ghost" rows of commas), `ImportColumnMapper`
  (header synonyms in the fourteen localizations plus Google Contacts/Outlook headers, then content sniffing for phone,
  e-mail and name; greedy best-match so "Ad Soyad" is a name and "Phone 1 - Label" is never the phone), mapping screen
  with native `Picker` menus (Name, Last name, Phone, Email), a "first row has column titles" switch and a 3-row
  preview, per-row validation in `ImportClientMapper`.
- **Validation** (`ImportClientMapper`, one owner): name cleaned with `OnboardingRules.cleaned` and 2 to 60
  characters; phone optional but must normalize (`PhoneNormalizer` with the business region) if present; e-mail light
  check (`ImportEmailRules`, placeholders such as "-" and "n/a" mean no e-mail); a cell with several numbers
  ("a / b", "a; b") is split.
- **Ready screen** (`ReadyStepView`): the "Import your clients" shortcut is now shown (prototype card) and presents
  `ImportClientsView` as a sheet. The profile does not exist yet during setup, so `ImportClientsView` takes optional
  `businessRegionCode` and `clientTerm` (defaults come from `ProfileService`). The "Clients" tile now shows
  `registration.usage.used` instead of a fixed 0.
- DEBUG hooks (never in Release): `-uiContacts four`, `-uiSpreadsheet clients`, `-uiRegisteredClients <n>`
  (`LaunchOptions`, `Managers/Import/FixtureContactsImporter|FixtureImportFileReader|ImportUITestSeeding`).

## Files and folders owned

- `BelloHub/Screens/Clients/Import/**`: `ImportClientsView`, `ImportClientsFlowView`, `ImportClientsViewModel`,
  `ImportWorkingOverlay`, `ImportClientsPreviews` (DEBUG), `Steps/` (Sources, Mapping, Choose, Result), `Rows/`
  (SourceRow, EntryRow, SkippedRow, ColumnPickerRow, PreviewRow), `Support/` (ImportClientMapper, ImportStep,
  ImportSource, ImportProblem, ImportBatchFit, ImportRegion, ImportColumnOption).
- `BelloHub/Managers/Import/**`: `ContactsImporting`, `SystemContactsImporter`, `ContactPickerSheet`,
  `ContactPickerPresenter`, `ContactCandidateMapper`, `ImportFileReading`, `SystemImportFileReader`,
  `SettingsOpening`, `SystemSettingsOpener`, `ImportDependencies`, DEBUG fixtures and seeding.
- `BelloHub/Models/Import/**` (pure): `ImportCandidate`, `ImportEntry`, `ImportRowIssue`, `CSVParser`, `ImportTable`,
  `ImportColumnMapping`, `ImportColumnMapper`, `ImportHeaderSynonyms`, `ImportTextDecoder`, `ImportPhoneRules`,
  `ImportEmailRules`, `ImportNameComposer`, `PhoneLabelClassifier`.
- Tests: `BelloHubTests/Managers/Clients/ClientRegistrationServiceTests`, `Models/Client/ClientDuplicateRulesTests`,
  `Models/Import/*`, `Managers/Import/ContactCandidateMapperTests`, `Screens/Clients/Import/*`, fakes
  (`FakeContactsImporter`, `FakeImportFileReader`, `FakeSettingsOpener`, `FakeSubscriptionStatus`,
  `FailingClientRegistrar`), `Support/CPUTime`. UI: `ImportClientsUITests` (2 flows), `ImportAuditUITests`.
- Strings: `Config/Locale/strings/s4-import.json` (67 keys, 14 localizations; merged and `check-strings.sh` passes).

## Small edits outside my folders (the coordinator may see conflicts)

- `ReadyStepView.swift` (the shortcut, the tile count).
- `SupportFiles/LaunchOptions.swift` (3 DEBUG properties and their parsing), `SupportFiles/UITestSeeding.swift`
  (one line: `await ImportUITestSeeding.seedIfRequested(...)` before the `onboarded` guard).
- `Config/TestPlans/UISmoke.xctestplan`: `ImportAuditUITests` added to `skippedTests`.
- `Models/Client/ClientDuplicateRules.partition`: same rule and same signature, now linear (sets of ids and phones)
  instead of a scan per row; 2,000 rows against 2,000 clients was quadratic. Covered by `ClientDuplicateRulesTests`.
- `BelloHub/SupportFiles/Localizable.xcstrings` regenerated by `scripts/merge-strings.py` (the coordinator regenerates
  it again at integration).

## Decisions and assumption candidates

- **ASSUMPTION candidate: contacts use the system picker, not an authorization flow.** `CNContactPickerViewController`
  needs no permission and hands over only the ticked contacts, which is stricter than the iOS 18+ limited-access flow
  (no `ContactAccessButton`, no enumeration of "what the app may see", no full-access state where the whole address
  book would be readable). Consequence: there is no "no access, open Settings" state for denied contacts, because
  denied does not matter to the picker. The one state kept is `.restricted` (Screen Time or a device-management
  profile): the screen explains it and offers "Open Settings" through `SettingsOpening`. Not verified on a real
  iPhone (the simulator cannot drive the picker): H-task to confirm the picker returns phone numbers and birthdays and
  that multi-select works inside a sheet. The permission step of the onboarding still asks `.contacts`; it is not
  needed by the import.
- **Excel `.xlsx` is not parsed in v1.** The Spreadsheet row says "A CSV file with name and phone" (the prototype says
  "Excel or CSV with name and phone"), and a footnote tells her to export CSV from Excel or Numbers. Reason: an
  honest label, since `.xlsx` is a zip of XML and would need its own reader. Deviation from HANDOFF 4.6.
- **"Send my booking link" is omitted** from the result (needs S8 and WhatsApp S6); the prototype row and its switch
  are not built.
- Result copy talks about **registrations** ("2 new registrations", "2 more need a plan"), not about clients, so no
  participle has to agree with the professional's own word (some are feminine in pt-PT, slashed in es/it). The word
  itself is used only where it needs no agreement: the title "Import {term}", "Choose {term}", "View {term}", the
  headline and the result subtitle (`ProfileService.clientTerm`, plural).
- The paywall is opened from the result ("See plans"), not automatically; with 0 free slots left the gate runs anyway and
  returns all rows as `blocked`.
- Rows without a phone cannot be detected as duplicates (`ClientDuplicateRules` compares ids and phones only), so
  importing the same phone-less contacts twice creates two clients. Open point for the owner.
- A partial failure inside `importClients` (a throw after some saves) leaves the saved ones in place; the message says
  so. A retry would skip those with a phone as duplicates but duplicate the phone-less ones.
- Contacts are listed sorted by name; a spreadsheet keeps the order of its file. The gate registers the first rows of
  the list when the free slots run out, so the order shown is the order imported.
- Phone numbers of an import use the **business region** for numbers without a country code. During setup that is
  the region she just picked (`OnboardingDraft.regionCode`).

## Design additions (for the designer; none of these are in the prototype)

- Column mapping screen (4.6 only draws sources and the contact list): title, file name and row count, "First row has
  column titles" switch, four native menus, preview of the first three rows, "Choose the column that has the names".
- "Can't be imported" list (entries skipped, with the reason) under the people list, the amber partial-import notice,
  the "n more need a plan" card with "See plans", the restricted-contacts notice, the working overlay.
- The result has no booking-link invitation (see above).
- The spreadsheet row uses the `document` icon (the prototype draws a table; adding `tablecells` to `Icon` would touch a
  shared file).
- At accessibility sizes the partial-import notice and the selection count move from the bottom bar into the list (a
  plain footer, not a box) so the bar stays a single button; found in the AX5 screenshots, and the system audit
  flagged the boxed notice as a list row.

## Findings

- A UTF-16 file in ASCII letters is also valid UTF-8 (every other byte is NUL), so the UTF-16-without-BOM test must run
  before UTF-8, or the text arrives full of NULs.
- `performAccessibilityAudit(.textClipped)` flags a text inside a boxed `List` row that scrolls and shows fully on
  screen, and "Label not human-readable" flags a bare file name ("clients.csv"). Both are cured by structure: a plain
  footer, and "clients.csv . 6 rows" as one line.
- Swift Testing runs suites in parallel on a slow Debug build: a wall-clock bound on 2,000 rows once took 14 s. The
  2,000-row bounds on pure code are measured in thread CPU time (`CPUTime.measure`); the ViewModel and gate tests keep
  generous wall-clock bounds.
- `ClientRegistrationService.importClients` saves one client at a time. 2,000 clients through the in-memory SwiftData
  vault take about 7 s on a Debug simulator, nearly all of it the repository (`save` per client). A batch `save` on
  `ClientRepository` would be the fix; the screen shows a spinner meanwhile.
- `#expect(array.allSatisfy(\.isReady))` does not compile in Swift Testing (the key path is passed as a throwing
  function); use a closure.
- `-AppleInterfaceStyle Dark` as a launch argument does not switch an XCUITest run to dark; `xcrun simctl ui <udid>
  appearance dark` does (restore with `light`).

## Measured

- Fast plan: 567 unit tests in 78 suites on my branch (the S4 contract had about 410), all passing; mine are roughly
  155 across 16 files. 2,000-row CSV: parse in a few milliseconds, parse plus mapping plus validation under 2 s of CPU
  in the bound (about 0.1 s in practice).
- UISmoke: `ImportClientsUITests` (contacts past the free registrations with the paywall, and a spreadsheet through
  mapping, validation and result) passes, about 55 s each (the onboarding walk is most of it).
- `ImportAuditUITests` (clipped text and element descriptions, contacts and spreadsheet paths, Ready screen): clean in
  `en`, `pt-BR`, `de`, `ar`, `hi` at the largest text size (AX5), and at the default size (one run hit a 5 s wait in the
  shared `type(intoField:)` helper on the setup walk in `ar`; rerun of `ar,hi` at the default size passed).
- `scripts/check-warnings.sh`: zero warnings on simulator Debug, device Debug, simulator Release and the test targets.
- `scripts/check-strings.sh`: passes (67 `import.*` keys).

## State at the end of the work (all done, nothing unfinished)

- Commits on this branch after 407427e: engines and managers (158c624), screen plus Ready shortcut plus strings
  (8e163c2), then UI tests, test plan entry and these notes.
- Last results: Fast 567 tests in 78 suites passed; UISmoke 14 tests passed (2 are mine); check-warnings zero;
  audits as above. Nothing is WIP and nothing is failing.
- Next command for the coordinator after merging the four slices: `python3 scripts/merge-strings.py`,
  `scripts/check-strings.sh`, then `SIM_UDID=<udid> scripts/test.sh fast` and `smoke`; the full audit is
  `ONLY_TESTING=BelloHubUITests/ImportAuditUITests scripts/test.sh full` (about 7 min per size).

## Open questions and things the coordinator must do at integration

- Present `ImportClientsView(onViewClients:)` from the Clients tab (empty state and toolbar), `NewClient` and (later)
  More and Integrations. The sheet inherits `ClientRegistrationService` and `ProfileService` from the environment.
  `onViewClients` should select the Clients tab or pop to the list; the sheet dismisses itself afterwards.
- Regenerate `Localizable.xcstrings` (`python3 scripts/merge-strings.py`, then `scripts/check-strings.sh`). There are no
  placeholders to delete.
- `UITestSeeding` / `LaunchOptions` / `UISmoke.xctestplan` edits may conflict with the other slices; each is a few lines.
- `DESIGN.md`: add the screen inventory rows (4.6 flow, mapping screen), the design additions above and the identifiers
  (`importClients.*`, `onboarding.ready.importButton`).
- PROGRESS.md traceability: 4.6 ImportClients done; Onb-7-Ready import shortcut done.
- Human task suggestion: on a real iPhone check the contact picker (multi-select, phone numbers with labels,
  birthdays), the file importer with a CSV from Excel for Windows (Windows-1252) and from Numbers, and a contact
  without a phone.

## Strings batch

`Config/Locale/strings/s4-import.json`: `import.*` (67 keys). All 14 localizations, `needs_review` except English.
