# s7-record: record history, incident, export and AI settings, front end only (S7 slice, D53)

Branch `s7-record` (worktree `.claude/worktrees/agent-af16371e7560af324`, sim `0FBF1349`), based on `build/v1` at
c527125 and merged with `build/v1` at f22c582 (s6-home). The first agent died of a usage limit with one commit (the
whole front end, strings, placeholders deleted) and the unit tests uncommitted; they were reviewed, committed and
finished here.

## What was built

- **4.7 RecordHistory**: `Screens/Records/History/` (`RecordHistoryView` thin wrapper → `RecordHistoryContentView`
  owns `RecordHistoryViewModel`). The client's records newest first, each as a `RecordHistoryCard` with its edit trail
  (`RecordTrailRow`: created, locked, every correction with old → new text and the reason) and one button: "Edit"
  while the record is open, "Add correction" once it is locked. `RecordCorrectionSheet` picks the field
  (`RecordCorrectableField`: notes, technique, aftercare, result detail, next session), shows what it says now, and
  refuses an unchanged text or a locked record without a reason (`RecordEditRules.Problem`). Her incidents
  (`IncidentRow`) and her photos: `RecordPhotosSection` with a before/after compare (`BeforeAfterCompareView`, pairs
  per visit from `PhotoComparisonRules.pairs`) and a timeline; `PhotoDetailSheet` opens one photo and changes its
  visibility within what the photo consent allows. Lock notice when any record is locked; empty, loading, missing and
  error states.
- **4.9 Incident**: `Screens/Records/Incident/` sheet with chips for symptoms (several), severity, area (optional),
  what she did (several), the visit it belongs to (or none), notes and "Follow up with the client". Save needs at least
  one symptom (`IncidentRules.canSave`). `IncidentRules.incident` keeps the chip titles as text in her language. Saved
  state offers "Book a check visit" (opens the new appointment sheet for the client) and Done.
- **4.10 ExportRecord**: `Screens/Records/Export/` sheet: audience (client copy or health professional), what to
  include (health, consent, treatments, photos, internal notes), period. The client's copy can never carry internal
  notes: `ExportOptions.allowsInternalNotes` is the one owner of that rule (switch off and disabled; the selector
  ignores the flag). `RecordExportSelector` cuts the vault data down, `RecordExportDocumentBuilder` lays the
  `RecordExportDocument` out (sections of text, with the included photos scaled in), and `RecordExporting` (protocol,
  `Managers/Export/`) renders it: `PDFRecordExporter` (attributed text and images through UIKit's PDF renderer) writes
  a temp file with `.completeFileProtection`, deleted after sharing or when
  the sheet closes (`discardFile`). Ready state shows the file name (`ExportFileName`), Share (`ActivityShareSheet`,
  `UIActivityViewController` behind `UIViewControllerRepresentable`) and Back.
- **7.5 AISettings**: `Screens/AISettings/` (`AISettingsView` thin wrapper → `AISettingsContentView` owns
  `AISettingsViewModel`). Where it runs (always this iPhone, state from `VoiceCapturing.availability`), cloud help
  shown, off, disabled and marked "Not available yet", how it works (does / never does), settings: voice, AI, review
  before saving (on and locked, D23), delete recordings, voice language (read only), link to `RecordTemplateView`.
  Preferences: `Models/AI/AIPreferences.swift`, stored as JSON under `DefaultsKey.aiPreferences` through
  `AIPreferencesStoring` / `UserDefaultsAIPreferencesStore`.
- **Wiring**: `ClientProfileView` gets a "Record" section with rows Records, Report a reaction, Export record
  (`clientProfile.recordsRow` / `incidentRow` / `exportRow`); `ClientsTabView` uses a `NavigationPath`, adds
  `.recordDestinations()` and `.recordSheet(item:)`. The four placeholders under
  `Screens/Shared/Treatment/Placeholders/` were deleted. More does not have the AI settings row yet (S10 changes
  `MoreRoute`; the coordinator wires it).
- **Debug hooks** (DEBUG only): `-uiRecords` (`Managers/Business/RecordUITestSeeding.swift`: a record locked two days
  ago with one correction, an open record from an hour ago, one incident, for the seeded Ana Costa; fixed ids),
  `-uiRoute recordHistory` and `-uiRoute aiSettings` (in `HealthDebugRoute`).

## Tests

- Unit (Fast): `BelloHubTests/Screens/Records/` (`RecordEditRulesTests`: lock at 23:59:59 vs 24:00:00, edit trail,
  unchanged and reason-missing problems; `RecordTrailBuilderTests`, `RecordHistoryBuilderTests`,
  `PhotoComparisonRulesTests`, `IncidentRulesTests`, `ExportFileNameTests`, `RecordExportSelectorTests` (client copy
  never includes private notes), `RecordExportDocumentBuilderTests`, `RecordHistoryViewModelTests`,
  `IncidentViewModelTests`, `ExportRecordViewModelTests`, `RecordContrastTests`), `Screens/AISettings/
  AISettingsViewModelTests`, `Managers/Export/PDFRecordExporterTests` (file protection, client copy text),
  `Managers/AI/UserDefaultsAIPreferencesStoreTests`; fakes `FakeRecordExporter`, `FakeAIPreferencesStore`; helper
  `Support/IDCounter`.
- UI: `RecordUITests` (UISmoke, 4 tests: correction on a locked record refused without a reason then logged,
  incident from the profile, client-copy export without private notes, AI settings with cloud off and review locked).
  `RecordAuditUITests` (skipped by UISmoke through `Config/TestPlans/UISmoke.xctestplan`) walks history, correction
  sheet, incident and saved, export form and ready, AI settings; run with
  `TEST_RUNNER_AUDIT_LOCALES=en,ar ONLY_TESTING=BelloHubUITests/RecordAuditUITests scripts/test.sh full`.
- Strings: `Config/Locale/strings/s7-record.json` (201 keys, 14 localizations), merged, `check-strings.sh` passes.

## Lessons

- `draft?.newValue = draftCurrentValue` in an `@Observable` class aborts at runtime (exclusivity conflict: the write
  on `draft` is open while the getter reads `draft`). The unit tests did not catch it because the fake world never
  went through the button; the UI test did. Read into a local first.
- A combined card around a disabled `Toggle` reports `isEnabled == true` to XCUITest; prove the lock by tapping and
  checking the value did not change. A `ToggleRow` is flipped with `app.flip(_:)` (coordinate tap), not `tap()`.

## ASSUMPTION candidates (for the coordinator to list in PROGRESS.md)

- ASSUMPTION: a correction can target notes, technique, aftercare, result detail and next session; products and the
  template's own fields are not corrected in v1 (they would need a per-field editor).
- ASSUMPTION: the incident stores the chip titles as text in her language at the time (the vault keeps what she
  read), not the enum keys.
- ASSUMPTION: the PDF is a plain document (sections of text, photos scaled in when included); a branded layout can
  come later.
- ASSUMPTION: the export's "period" is all time or the last 12 months.
- ASSUMPTION: the voice language on 7.5 is read only (the device language) until a voice technology exists.

## Deviations from the design

- 4.7 has no `addOpen`/`added` inline states: the correction is a sheet, and the trail refreshes when it closes.
- 4.9 "Back to alerts" and "Open Ana's profile" are not there (the sheet opens from the profile; Notifications are S8).
- 7.5 has no "Ready / unavailable / language not supported" pill beyond what `VoiceCapturing.availability` says.

## DESIGN.md additions (the coordinator applies them)

Screens 4.7, 4.9, 4.10, 7.5 and their states (history: loading, missing, error, empty, overview with lock notice,
correction sheet with the two problems; incident: form, save error, saved; export: loading, missing, failed, form,
ready, shared; AI settings: one screen). Components: `RecordHistoryCard`, `RecordTrailRow`, `IncidentRow`,
`RecordPhotosSection`, `BeforeAfterCompareView`, `RecordPhotoImage`, `RecordStateView`, `ActivityShareSheet`.
Navigation: `RecordRoute.history` pushed on the Clients stack; `RecordSheet.incident` / `.exportRecord` as sheets.
New tokens: none.

## What is not done

- Audit in `pt-BR`, `de`, `hi` (the default list); only `en,ar` were run.
- The More row for AI settings (after S10 merges).
- The deviation items above.

## State at the checkpoint (2026-10-09, evening)

Everything is committed on `s7-record` (merged with `build/v1` at f22c582). Passed: `scripts/test.sh fast` (1888
tests in 248 suites), `scripts/check-warnings.sh` (zero warnings: simulator, device, Release, test targets),
`scripts/check-strings.sh`, the `en,ar` record audit at default size and AX5 (`RecordAuditUITests`), and the 4
`RecordUITests` in UISmoke. Bugs found and fixed on the way: `RecordHistoryViewModel.syncDraftText` aborted on an
exclusivity conflict when "Add correction" was tapped; `PDFRecordExporter` ended the PDF context in a `defer` after
the bytes were copied, so every exported PDF was unreadable (zero pages); the exported file card had no spoken label.

`scripts/test.sh smoke`: 35 of 36 pass. The one failure is `CalendarUITests.testBookFromAFreeHourThenRescheduleIt`
(line 27: tapping `calendar.slot.9` does not open the new appointment sheet), reproduced twice between 18:30 and
19:00 CEST. Nothing in this slice touches the calendar; the seed used is `clients -uiCalendar`. It looks like a
time-of-day case (the first hittable hour is already past) that arrived with the `s6-home` merge or the day's clock;
to be rerun in the morning or checked on `build/v1` by the coordinator before blaming this branch.

## Next commands

```
cd .claude/worktrees/agent-af16371e7560af324
TEST_RUNNER_AUDIT_LOCALES=pt-BR,de,hi ONLY_TESTING=BelloHubUITests/RecordAuditUITests SIM_UDID=0FBF1349-DF6C-4957-9953-449129046931 scripts/test.sh full
```
