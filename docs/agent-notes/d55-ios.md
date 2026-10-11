# Agent notes: D55 applied to the iOS app (`BelloHub/`)

Branch `d55-ios`, from `build/v1` at f77bb91. Nothing pushed, nothing merged. Scope: `BelloHub/`, `BelloHubTests/`,
`BelloHubUITests/`, `scripts/`, `Config/Locale/strings/`, `docs/05`, `docs/06`, `docs/07`, `legal/STATUS.md`.
`docs/PROGRESS.md` and `DESIGN.md` are untouched (DESIGN additions are in section 4 below).

D55: consents are the professional's own business; the app only records their status. The app writes no consent
text, shows none, and asks for no signature. Per client she keeps consent records: kind, her own label, signed or
not, the date, a note, and an optional photo or file of the real signed paper, sealed in the vault.

## 1. What changed

### Deleted
- Consent texts and their machinery: `Managers/Legal/*` (`LegalTextLibrary`, `BundleLegalTextLibrary`, renderer
  build), `Models/Health/{LegalDocument, LegalFileName, LegalText, LegalTextBlock, LegalTextRenderer, LegalTextValues,
  RenderedLegalText, ConsentKind+LegalDocument}`, the 42 bundled drafts under `BelloHub/Resources/Legal/`,
  `scripts/{sync-legal-resources.sh, sync-legal-resources.py, check-legal-resources.sh}` and the gate in
  `scripts/test.sh`. `scripts/check-legal-status.sh` stays (the drafts in `legal/` are history).
- Screens: 4.5's `ConsentCard`, `ConsentRow`, `HealthConsentSection` (text, language menu, "I agree", typed
  signature), `SignedConsentSheet` + VM, `ConsentPresentation`, `LegalTextView`, `LegalLanguagePicker`; 6.14's consent
  rows and `ConsentPreviewSheet` + VM.
- `ConsentSensitiveFields`; `HealthForm.signatureImage` and `HealthForm.guardianName` (sealed keys are now
  `answers`, `minorName`).
- Strings: `legal.*`, `signedConsent.*`, `consentPreview.*`, `formTemplates.consent.hint`, `healthForm.agree*`,
  `healthForm.signature*`, `health.consent.signedBy/signed/version`, `health.minor.guardian`,
  `exportRecord.doc.consent.{treatment,photos,guardian}`.
- Tests: `LegalTextLibraryTests`, `LegalFileNameTests`, `LegalTextRendererTests`, `ConsentTextViewModelTests`,
  `FakeLegalTextLibrary`.

### Added or rewritten
- **Model** (`Models/Record/`): `ConsentRecord` (replaces `Consent`; vault kind raw value stays `consent`):
  `kind: ConsentKind` (+ `other`, in the clear as the index), `isSigned`, `signedAt?`, `createdAt`, sealed `label?`,
  `note?`, `document?`. A custom decoder reads pre-D55 records (signed on their date; `textVersion`, `localeID`,
  `typedSignature`, `signatureImage` ignored). `ConsentDocument` (`kind` photo|file, `fileName?`, `contentType`
  UTI, `data`, `thumbnail?`, `maximumBytes` 10 MB), `ConsentDocumentKind`, `ConsentKind+Title`,
  `ConsentRecord+Rules` (`newestFirst`, `displayLabel(kindTitle:)`: shared by the vault, the screen and the export).
- **Persistence**: `ClientRepository.deleteConsent(id:)` (both implementations, `FlakyHealthRepository`);
  `consents(for:)` sorted by `ConsentRecord.newestFirst`; sensitive keys `["label", "note", "document"]`.
- **Managers/Documents**: `ConsentDocumentReading` (protocol) + `SystemConsentDocumentReader` (security-scoped
  read, PDF or image, size cap, bytes copied out, nothing kept). Photos go through the existing `PhotoProcessing`.
- **Screen 4.5** (`Screens/Health/`): `Cards/ConsentsCard` (list, count, "Add consent", footnote),
  `Rows/ConsentRecordRow` (label, Signed/Not signed chip, date line, "Photo kept · Note"), `Sheets/ConsentRecordSheet`
  + `ConsentRecordViewModel` (kind chips, label, signed switch with date, note, photo via `PhotosPicker` or file via
  `fileImporter`, preview, remove, delete with confirmation, save), `Components/ConsentDocumentPreview`,
  `Support/ConsentRecordDraft`, `Support/ConsentRecordRules`. `ClientHealthViewModel` owns the sheet
  (`startConsent()`, `open(_:)`), takes `photos`/`files` in `init` (fakes in tests); `ClientHealthView` passes
  `\.photoProcessing`.
- **Health form sheet**: questions and the minor switch + name only. `HealthFormDraft` loses `agrees`/`signature`;
  `HealthFormFillRules.canSave` / `form(draft:saving:)` replace `canSign` / `records`; `HealthFormViewModel` has
  no legal library or text language. `HealthHistoryCard` drops the guardian row.
- **Other users of consents**: `PhotoConsentRules.latestPhotoConsent` counts only a signed `photos` record;
  `PreVisitChecklist.consentSignedAt`, `ClientHealthSummary` use signed records; `RecordExportSelector` strips the
  document (`withoutDocument`); `RecordExportDocumentBuilder` prints label + "Signed <date>" / "Not signed"
  (`exportRecord.doc.notSigned`). `TreatmentFlowUITestSeeding`, `ClientsFixtures` build the new record.
- **Design system**: `DataImage` (promoted from `Screens/Treatment/Components/FlowPhotoImage`, now used by two
  features), `PDFDocumentView` (PDFKit from memory; nothing touches the disk).
- **Intake item** `consentForm` kept (profession presets name it) and reworded: "Consents" / "Noted as signed or
  not; the paper is signed with you".
- **Strings** (`Config/Locale/strings/s4-health-forms.json`, `s3-setup.json`, `s7-record.json`, 14 localizations):
  `health.consent.{other,add,count,status.signed,status.notSigned,signedOn,notedOn,hasPhoto,hasFile,hasNote,
  openHint,footnote,empty}`, `consent.*` (sheet), reworded `health.title` ("Health and consents"),
  `healthForm.subtitle/save/incomplete`, `healthForm.minor.hint`, `health.minor.message`.
  `scripts/merge-strings.py --prune` is new: removes catalog keys no batch authors (keeps an unauthored key code
  still names unless it has no localizations, which is an Xcode `defaultValue:` extraction artifact).
- **Pre-existing breakage fixed on the way**: `scripts/check-strings.sh` failed on `build/v1` (f77bb91 let Xcode
  add `CFBundleName` to `InfoPlist.xcstrings` in `en` only and eleven empty extraction artifacts such as
  "Aftercare"; `recordTemplate.kind.multiChoice` was used in code and authored nowhere). `CFBundleName` is now
  manual in all 14, the artifacts pruned, `multiChoice` authored in `s4-tags-record-template.json`.
  `scripts/check-server-contract.sh` also failed (the backend half of D55 regenerated `schemas.json`); synced.

### Publish payload
`PublishProfileRequest` never carried `intake` (S8 iOS half is not built yet), so nothing sends `intake.consent`.
When the S8 iOS half adds `intake`, it is `{formVersion, template}` only (`docs/agent-notes/d55-web-backend.md`
section 5). `PublishAvailabilityPayloadTests` validate against the synced `schemas.json`.

## 2. Tests
- New: `ConsentRecordTests` (old-shape decoding, round-trip, unknown raws, order, display label, kinds),
  `ConsentRecordRulesTests`, `ConsentRecordViewModelTests` (new/edit/delete, photo and file attach, errors, size
  cap), `FakeConsentDocumentReader`.
- Rewritten: `HealthFormViewModelTests`, `HealthFormFillRulesTests`, `ClientHealthViewModelTests` (consent sheet,
  edit, no vault), `FormTemplatesViewModelTests`, `HealthStringsTests` (date placeholders), the persistence
  contract and encryption tests (new sentinels: label, note, file name, document bytes, thumbnail),
  `PhotoConsentRulesTests` (unsigned record unlocks nothing), `ClientProfileBuilderTests`,
  `RecordExportSelectorTests`, `RecordFixtures.makeConsent`, `HealthTestFactories.makeConsentRecord`.
- UI: `HealthUITests` (fill, no agreement/signature, add a consent, edit it to not signed, patch test),
  `HealthMinorUITests` (name only, guardian consent as a record), `FormTemplatesUITests` (no consent rows),
  `HealthAuditUITests` (walks the consent sheet, signed and not, and the edit sheet; the 6.14 consent text walk is
  gone), `XCUIApplication+Health` (`answerHealthForm`, `setSwitch`, `consent.saveButton` as a bottom bar).

Results: see section 5 (filled as the runs finish).

## 3. Not done / open
- The mailbox import (S8) does not exist yet in Swift; when it does, it must accept intake schema 2 and ignore the
  schema-1 consent block (`d55-web-backend.md` section 5 item 2).
- Older agent notes (`health-forms.md`) describe the consent texts as history; not rewritten.
- `docs/14-HUMAN-TASKS.md` / `docs/16-MARKETS.md` mentions of consent texts: not touched (same as the web half).

## 4. DESIGN.md additions (for the coordinator; DESIGN.md not edited here)
| Screen | Change | Why |
|---|---|---|
| 4.5 | Title "Health and consents". Section "Consents": a list card of records (label or kind title; chip Signed / Not signed, sage / amber; "Signed · date" or "Not signed · noted date"; footnote "Photo kept · Note"), an "Add consent" row in the card, a footnote "Your own record: what she signed with you, on paper…". Empty state text inside the card. | D55 |
| 4.5 | Sheet "New consent" / "Consent": kind chips (Treatment, Photo, Guardian, Other), label field (optional), "Signed" toggle row with "She signed the paper with you", date picker while signed, note field, "Photo or file of the signed paper" with Add photo / Choose file (secondary buttons), preview (photo, PDF via PDFKit, or file icon + "name · size"), Remove (tertiary), Delete consent (tertiary, destructive, confirmation dialog) when editing, Save consent (primary) in a bottom bar. | D55 |
| 4.5 | Health form sheet: questions and the under-18 switch + name only; subtitle says any consent is signed with you outside the app; Save is "Save answers". The signed-text sheet is gone. The minor notice says "Note their consent in the Consents list"; no guardian name row. | D55 |
| 6.14 | The consent texts section and preview sheet are gone. | D55 |
| Export PDF | The consent section prints her label (or the kind) with "Signed <date>" or "Not signed"; never the photo or file. | D55 |
| Design system | `DataImage` (bytes to image, promoted), `PDFDocumentView` (PDF from memory). | Two features share them |
| Accessibility ids | `health.addConsentButton`, `health.consent.<uuid>`, `health.consent.empty`, `health.consent.footnote`, `consent.{closeButton,kind.<kind>,labelField,signedToggle,datePicker,noteField,addPhotoButton,addFileButton,removeDocumentButton,documentPreview,preparingDocument,deleteButton,deleteConfirmButton,error,saveButton}` | |

## 5. Results and next commands
(filled below as each run finishes)
