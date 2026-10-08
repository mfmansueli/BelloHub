# Agent notes: health-forms (S4, slice 3)

## STATE AT HANDOFF (read this first)
Everything is committed on branch `worktree-agent-a534192a1071f5248`. The work is functionally complete; what is left is
verification only.

| Check | Last known result |
|---|---|
| `scripts/test.sh fast` | **551 tests in 80 suites passed** at commit 4115d8f. Added after that and **not yet run**: `HealthContrastTests`, `HealthFormCatalogProviderTests`, `AppLocalizationLocaleTests`; and the sheets were restructured (header inside the scroll view, hint moved out of the Save bar). The app target built clean (no warnings) after the restructure because the UI runs below built it. |
| Gates in `test.sh` (`check-strings`, `check-privacy`, `check-legal-status`, `check-legal-resources`, `check-professions`, `check-health-forms`) | all pass (they run before every xcodebuild) |
| `HealthUITests` (smoke, the one flow) | passed (22:01, after the header move) |
| `FormTemplatesUITests` (smoke) | passed once (21:41, before the Save bar went back to a bottom inset; the audit run below walks the same screen after it) |
| `HealthMinorUITests` (Full only) | passed once (21:44, before the sheet restructure); not rerun |
| `HealthAuditUITests` in `en,ar`, default size and AX5, 4.5 + its sheets + 6.14 + consent text | **passed** (22:18, the final code); `pt-BR`, `de`, `hi` not run |
| `scripts/check-warnings.sh` (simulator, device, Release, test targets) | **not run**. Only Debug simulator builds were done; they showed no warnings at the end. Release must be checked: `InMemoryClientRecordRepository`, `HealthDebugRoute` and the previews that use it are under `#if DEBUG` |
| `scripts/test.sh smoke` (all smoke flows together) | **not run** as a whole; `HealthUITests` and `FormTemplatesUITests` pass alone |

Next commands, in this order (the machine was at load 500+ with four agents, so each run is slow; one at a time):
1. `SIM_UDID=581B8F64-5D7C-4D9F-B30F-177C13ED50A8 scripts/test.sh fast`
2. `SIM_UDID=581B8F64-5D7C-4D9F-B30F-177C13ED50A8 scripts/test.sh smoke`
3. `scripts/check-warnings.sh` (needs `SIM_UDID` too)
4. Optional: `TEST_RUNNER_AUDIT_LOCALES=pt-BR,de,hi SIM_UDID=... ONLY_TESTING=BelloHubUITests/HealthAuditUITests scripts/test.sh full`, and
   `ONLY_TESTING=BelloHubUITests/HealthMinorUITests scripts/test.sh full`.

UI-test findings worth keeping (they cost most of the time): XCUITest believes anything inside a scroll view is visible even
under a floating bottom bar, and a tap that lands while a scroll still coasts is lost; `XCUIApplication+Health.swift` has
`scrollAboveBottomBar` (drag then hold), `selectChip`, `typeIntoField`, `tapRow` for that. A text field already holding
focus does not give focus to the next one without a tap. The system keyboard's `TUIPredictionViewCell` is reported by the
audit and is ignored there. At AX5 the Save bar must stay small: the "answer every question" hint now sits at the end of
the form, not in the bar. Failure messages of the health UI helpers save a screenshot to the runner's temp folder.

Screens 4.5 (ClientHealth, "Health and consent") and 6.14 (FormTemplates, "Client forms"), the health form model per
profession and version, consent with its text version, the minors flow (D17), and the bundling of the legal texts.
Branch `worktree-agent-a534192a1071f5248`, based on `build/v1` at 407427e.

## What was built

### Legal text bundling
- `scripts/sync-legal-resources.sh` (+ `.py`) copies the three consent documents the app shows (`consent-health`,
  `consent-photo`, `consent-guardian`) from `legal/<doc>/<loc>/<version>.md` to `BelloHub/Resources/Legal/
  <doc>-<loc>-<version>.md`, byte for byte (42 files today). `scripts/check-legal-resources.sh` fails when a bundled
  copy is missing, differs or has no source; it runs in `scripts/test.sh` next to the other gates. The drafts in `legal/`
  were not touched.
- `LegalTextRenderer` (pure, `Models/Health/`): strips the header, fills `{{PROFESSIONAL_NAME}}`, `{{OPERATOR_NAME}}`,
  `{{OPERATOR_EMAIL}}`, `{{OPERATOR_ADDRESS}}`, `{{WEB_BASE_URL}}`, `{{EFFECTIVE_DATE}}`, splits the body into blocks
  (paragraph, numbered point, `☐` line) and turns `**bold**` into styled text. An unfilled or unknown placeholder
  renders as `[[NAME pending]]` in DEBUG (`PendingStyle.forThisBuild`) and as nothing in Release (it never shows a raw
  token; the S11 gate is what blocks a Release with the operator fields empty).
- `LegalTextLibrary` (protocol) + `BundleLegalTextLibrary` (`Managers/Legal/`): `latest(document, localization)` returns
  the newest version (compared as numbers) or falls back to `en`; `text(document, localizationID, version)` is the exact
  signed text, **no fallback** (showing another version as "what was signed" would be false). `LegalFileName` (pure)
  owns the flat naming and the rule that `en` is not mistaken for `en-GB`.
- Every `Consent` stores `textVersion` and the `localeID` of the text that was **actually read** (after a fallback to
  `en` it stores `en`). Opening a consent shows that exact file.

### Health form model
- Questions are data: `Resources/HealthForms/healthform-<localization>.json` for the 14 localizations (13 questions,
  41 choices, `needs_review`), same keys/kinds/professions/defaults everywhere, checked by
  `scripts/check-health-forms.sh` (in `test.sh`) and by `HealthFormCatalogTests`. Kinds: `yesNo`, `choices` (with an
  exclusive reserved `none` key), `text`. Which profession is offered which question, and which start on, is in the file.
- `HealthFormTemplate` (`Models/Health/`): one template per professional with `version`, `questionKeys` (the on/off
  choice) and `reviewEveryMonths` (3, 6, 12 or 24, default 12). Stored in the clear (not clinical), **one vault record
  per version**, id derived from the version. `HealthForm.formVersion` points at it, so a form is always read against the
  questions of the version it was signed on.
- `HealthFormTemplateRules` (pure, `now` injected): offered questions per profession, default template, `edited(...)`
  (changing the questions makes the next version; changing only the months updates the current one; unknown keys from a
  newer build are kept), `accepts(_:over:)` (a stored version keeps its questions), review due date (`signedAt` plus N
  calendar months on the business wall clock, clamped for short months; due **at** the instant the period ends), latest
  form, version lookup.
- `ContraindicationMatcher` (pure): token grammar `question`, `question.choice`, `minor`. Warns, never blocks (D16).
  Returns matches, `unchecked` tokens (free text she wrote, keys from a newer build) and `hasHealthForm`. It also lists
  every token the catalog can decide (`choices(in:)`) for S6's service editor. S6 calls it; nothing calls it yet.
- `PatchTest` + `PatchTestResult`: see decision 2.

### Storage (`FormTemplateRepository`)
- New protocol `Managers/Forms/FormTemplateRepository` (templates + patch tests), composed into `ClientRecordRepository`.
  Implementations: `SwiftDataClientRecordRepository+Forms.swift` and `InMemoryClientRecordRepository+Forms.swift` (both in
  `Managers/Persistence/`, because they use the actor's internals). New `VaultKind.healthFormTemplate` and `.patchTest`
  (append-only). `deleteClient` also deletes patch tests. `FormTemplateError.versionLocked` when a stored version is
  saved again with other questions.
- Sealed (D26): `PatchTest.product/area/result/notes`. `HealthFormTemplate` has no sensitive keys. Existing `HealthForm`
  and `Consent` sensitive keys unchanged. `ConsentKind` gains `guardian` (older builds read it as `treatment`).

### Screens (`Screens/Health/`)
- `ClientHealthView(clientID:)` (entry, reads the environment) -> `ClientHealthContentView` + `ClientHealthViewModel`;
  `Cards/` (history, consent, patch tests), `Rows/`, `Sheets/` (health form, patch test, signed text), `Components/`
  (`LegalTextView`, `LegalLanguagePicker`, `YesNoChips`), `Support/` (pure rules and presenters), `FormTemplates/`
  (`FormTemplatesView()` -> content view + VM + consent preview sheet).
- Empty, loading (skeletons) and error (notice + retry) states; the empty state offers the professional-filled path.
- The professional-filled sheet: yes/no and choice questions start **unanswered** (never defaulted to "no"); "None" is
  exclusive; "Is this visit for someone under 18?" switches the consent to `consent-guardian`, asks for the young
  person's name and makes the typed signature the guardian's; changing the text or its language asks for the agreement
  again; **the consent is saved first, then the form** (a failure in between leaves a consent with no answers, never
  answers with no consent); ids are made once so a retry updates instead of duplicating.
- Nothing from these screens goes to a log, a notification, a URL or the network (the only IO is the repository).

### Tests
- Pure: `HealthFormTemplateRulesTests` (applicability, defaults, version bump, `accepts`, 12-month boundary at exactly /
  one second / one day before and after, DST in Lisbon, New York and Madrid, clamping), `ContraindicationMatcherTests`,
  `HealthFormCatalogTests` (14 shipped files load, same keys), `LegalTextRendererTests`, `LegalFileNameTests`,
  `AppLocalizationLocaleTests`, `HealthFormFillRulesTests`, `HealthAnswerSummaryTests`, `PatchTestRulesTests`,
  `HealthStringsTests` (plurals, Arabic six forms), `HealthContrastTests`.
- Library against the real bundle (`LegalTextLibraryTests`: 3 documents x 14 localizations exist, newest chosen,
  fallback to `en`, exact text without fallback) and against a temporary bundle.
- Contract on both flavors (`RepositoryFormsContractTests`), on-disk sentinel scan (`FormsEncryptionTests`).
- ViewModels with `InMemoryClientRecordRepository` / `FlakyHealthRepository` (a fake that fails chosen writes):
  `ClientHealthViewModelTests`, `HealthFormViewModelTests`, `PatchTestViewModelTests`, `FormTemplatesViewModelTests`,
  `ConsentTextViewModelTests`.
- UI: `HealthUITests` (one flow: fill, sign, signed text version, patch test), `FormTemplatesUITests` (6.14),
  `HealthMinorUITests` (Full only), `HealthAuditUITests` (textClipped + element description; the locales come from
  `TEST_RUNNER_AUDIT_LOCALES`, default `en,pt-BR,de,ar,hi`).

## Files and folders owned
`BelloHub/Screens/Health/**`, `BelloHub/Managers/Legal/**`, `BelloHub/Managers/Forms/**`, `BelloHub/Models/Health/**`,
`BelloHub/Resources/Legal/**`, `BelloHub/Resources/HealthForms/**`, `scripts/{sync-legal-resources,check-legal-resources,
check-health-forms}.*`, `Config/Locale/strings/s4-health-forms.json`, `BelloHubTests/**/Health*`, `Legal*`, `Forms*`,
`Fakes/{FlakyHealthRepository,FakeLegalTextLibrary,FakeHealthFormCatalogProvider}`, the UI test files listed above.

## Edits to files other slices or earlier stages own (for the integration merge)
Small and additive; listed so a conflict is easy to resolve.
- `Managers/Persistence/`: `VaultKind` (+2 cases), `ClientRecordRepository` (composes `FormTemplateRepository`),
  `InMemoryClientRecordRepository` (2 stored properties made internal, `changes` no longer `private`, patch tests removed
  in `deleteClient`), `SwiftDataClientRecordRepository+Clients` (`.patchTest` in the `deleteClient` list),
  new `Mapping/VaultStorable+Forms.swift`.
- `Models/Record/ConsentKind` (+ `guardian`).
- `Screens/Main/RootView` (the `.app` stage goes through a small `app` view that shows `HealthDebugRoute` under DEBUG when
  `-uiRoute` is given), `SupportFiles/LaunchOptions` (`route`), `SupportFiles/UITestSeeding` (`clientWithHealth` seed).
- `DesignSystem/Components`: `FlowLayout` (+ `wrapsLongChildren`, default off), `SheetHeader` (+ `closeIdentifier`), new
  `BelloNoteField` (multi-line field).
- `scripts/test.sh` (two gates), `Config/TestPlans/UISmoke.xctestplan` (skips the audit and the minor flow).
- `SupportFiles/Localizable.xcstrings` is regenerated by `merge-strings.py` (86 keys); regenerate it again at integration.

## Decisions and assumptions (ASSUMPTION candidates)
1. **One health form template per professional, not per profession.** `HealthForm.formVersion` is a single Int (and the
   mailbox payload carries one), so versions must be one sequence. The professions decide which questions are *offered* and
   which start on; the editor lists what applies to her professions plus anything already on.
2. **A patch test is its own sealed vault kind (`patchTest`), not a `Consent` or `HealthForm`.** The brief allowed reusing
   existing types, but a `HealthForm` is one signed snapshot with a version and a consent (the "latest form", review due
   and contraindication rules would all have to filter out patch tests), and a `Consent` has no product or result. A new
   `kindRaw` costs no CloudKit schema change (ASSUMPTION-21). Product, area, result and notes are sealed.
3. **`ConsentKind.guardian`.** A guardian consent is a different legal text, so it is a different kind (`legalDocument`
   maps each kind to its document). The guardian's typed name is also stored as `HealthForm.guardianName`.
4. **Forms are never defaulted.** A yes/no or choice question needs an explicit answer to sign. The prototype's intake
   starts "No" on every yes/no; on a health form that silently says "no" it is a clinical risk.
5. **Review is due at `signedAt` + N calendar months on the business wall clock, and "due" includes the instant itself.**
6. **Contraindication tokens** are `question`, `question.choice` or `minor`; text she wrote herself is returned as
   `unchecked`, never dropped. S6's service editor should offer `ContraindicationMatcher.choices(in:)`.
7. **The text she reads is saved with its language.** If the business language has no text it is shown in English and
   the consent says `en`. A menu lets her show the text in another of the 14 languages (a client may read another one).
8. **A placeholder is filled when the text is shown**, so a signed text opens with her *current* business name, not the
   name at signing time (it is not stored). Operator fields stay pending until H17.
9. The "Recent procedures" question (isotretinoin, peel, laser, injectables, microneedling) is **on** by default for
   estheticians, tattoo and Other, following `docs/05` and the client form (`Cl-4-Intake`), not the prototype's template
   screen where it is off.
10. DEBUG hooks: `-uiSeed clientWithHealth` (onboarded + client "Ana Costa" with a fixed id) and `-uiRoute health|
    formTemplates` (shows the screen directly, because the tabs that push them belong to other slices).

## Deviations from the prototype / design additions (for DESIGN.md)
| Screen | Change | Why |
|---|---|---|
| 4.5 | "Send form again" and its footnote are omitted | Needs the server (S8). The bottom button is "Fill in the form again" (secondary), and the empty state offers "Fill in the form" (primary) | Professional-filled path |
| 4.5 | Review line shows a status chip ("Up to date" / "Review due") and the date, next to "Review every N months" | "Review every 12 months with the due state" |
| 4.5 | Consent card: one row per signed consent, titled by kind (Treatment, Photo, Guardian), tap opens the signed text; the prototype's scope label "Facial treatments" has no field | There is no scope in `Consent` |
| 4.5 | Loading skeleton, error notice with retry, empty state | CLAUDE.md section 8 |
| 4.5 | Notice "Filled in for someone under 18" plus rows for the guardian and the young person | D17 |
| 4.5 | New sheets: health form (questions then consent, one signature), record patch test, signed text | The professional-filled path, the log, the "exact signed text" |
| 6.14 | The consent text is **not editable**: three read-only rows (treatment, guardian, photo) open the versioned draft in a sheet with a draft note and a language menu | Legal texts are versioned files (ASSUMPTION-24) |
| 6.14 | "Ask again every" has 3, 6, 12 and 24 months (the prototype has 6, 12, 24); a footnote says editing the questions starts a new version | Brief |
| 6.14 | "Preview as client" omitted | S9 |
| Design system | `BelloNoteField` (multi-line, same look as `BelloTextField`), `FlowLayout(wrapsLongChildren:)`, `SheetHeader(closeIdentifier:)` | Notes that wrap, chips with long labels, a UI-test hook |

## Findings
- The worktree was created on an older commit than `build/v1` (the scaffold); it was fast-forwarded to 407427e first.
- The scratchpad directory is shared between the parallel agents; generator scripts were given a unique prefix (`hf_`).
- A SwiftUI `Toggle` outside a list only toggles on the switch, not on its text. The agreement card taps as a whole; the UI
  helper also taps the switch's edge.
- Xcode's string catalog resolves plural variations through `LocalizedStringResource(..., defaultValue: "\(n) ...")` with
  an explicit locale (tested for `en`, `pt-PT`, `fr`, `id`, and all six Arabic forms).
- `legal/STATUS.md` says "the professional-facing app does not show the word draft"; the coordinator's brief asks for a
  note that the consent text is a draft the professional reads, so `legal.draftNote` is shown above the text in the
  health form sheet and in the 6.14 preview. Remove that key's three uses if the owner prefers the other rule.

## Open questions
- Where do `{{OPERATOR_*}}`, `{{WEB_BASE_URL}}` and `{{EFFECTIVE_DATE}}` come from? `Config/Legal/operator.json` (H17) does
  not exist, so `LegalTextValues(profile:)` fills only the professional's name. Today only `consent-health` in `es-MX`
  uses `{{WEB_BASE_URL}}` (a pending marker in DEBUG, empty in Release).
- Should a client who is a minor become an adult automatically change the form? Not modeled: `isForMinor` is per form.
- The mailbox import (S8) must write `formVersion` = the current template version and a `Consent` whose `textVersion` and
  `localeID` come from the envelope's `consent` block; the key names in `answers` are the catalog's question keys and the
  choice values are option keys (`none` is the reserved "None").

## Strings
`Config/Locale/strings/s4-health-forms.json`: 86 keys in 12 authored languages (es-419 and en-GB derived), prefixes
`health.*`, `healthForm.*`, `patch.*`, `legal.*`, `signedConsent.*`, `formTemplates.*`, `consentPreview.*`. All
`needs_review`. The health form catalog files (`needs_review` too) are the other localized content.

## Wiring for the coordinator
- Slice 2 pushes `ClientHealthView(clientID:)` for `ClientsRoute.health`; slice 4 pushes `FormTemplatesView()` from
  More > Client forms. Both read `VaultService` and `ProfileService` from the environment (already provided by `RootView`).
- Regenerate the string catalog (`python3 scripts/merge-strings.py`) and run `scripts/check-legal-resources.sh` after any
  merge that touches `legal/`.
