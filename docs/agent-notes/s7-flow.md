# s7-flow: treatment flow, front end only (S7 slice, D53)

Branch `s7-flow` (worktree `.claude/worktrees/agent-a1d5e53e13c286df5`), based on `build/v1` at b63707e. Screens 5.1 to
5.9 as one flow in a full-screen cover with its own `NavigationStack`. The previous agent died of a usage limit with 27
uncommitted files; they were reviewed, kept and committed, then finished here.

## What was built

- **Entry**: `TreatmentFlowView(request:)` (placeholder deleted) reads `VaultService`, `ProfileService` and the
  environment entries `voiceCapture`, `recordStructuring`, `photoProcessing` and builds `TreatmentFlowHost`, which owns
  `TreatmentFlowViewModel` and the stack (`path: [TreatmentFlowStep]`). Closing asks first when she would lose work.
- **5.1 Register**: voice offer only when `availability == .available`; otherwise a calm reason (not available yet,
  permission denied with an Open Settings button, language not supported) and the form as the primary action.
- **5.2 Listening / 5.3 Organizing / 5.4 Review**: live transcript, soft limit 3 min (wrap-up notice) and hard limit
  10 min; organizing is an honest spinner with "keep my words as notes"; review is one card per field (Keep, Edit, Drop,
  Change), Save stays off until every card has a decision, `aiAssisted` is set only from a finished review that kept
  something (`ReviewMerge.isAIAssisted`), proposals that cannot be a valid answer are counted and turned away, fields
  not mentioned are listed as empty (never guessed).
- **5.5 Form**: every field of her `RecordTemplate` for her profession (text, number with unit, choice, multi-choice,
  yes/no, products list with her product names as suggestions), result chips, the 24-hour lock explained, save through
  `TreatmentRepository.save`. The record id is fixed at the start, so a retry updates the same record.
- **5.6 Saved**: summary rows (first four, "Show all details"), link to record history, lock notice, photos status, Set
  next session / Add before and after / Done.
- **5.7 Photos / 5.8 Camera**: before/after pair, list with kind and visibility menu, delete, library via the system
  `PhotosPicker` (no library permission), camera through `CameraCapturing` (`AVCameraCapture`), permission through
  `PermissionService` with a denied state (explanation, Open Settings, back), a no-camera state, flash, ghost overlay of
  the other photo, review with a visibility picker (only "Only me" unless a photo consent is signed). Photos are
  processed by `PhotoProcessing` (`ImageIOPhotoProcessing`: longest side 2048, JPEG about 400 KB, no EXIF/GPS/TIFF, 320 px
  thumbnail) and saved at once through `save(_:data:)`. Nothing writes to the camera roll
  (`scripts/check-privacy.sh` now fails on `PHPhotoLibrary`, `UIImageWriteToSavedPhotosAlbum`, `PHAssetChangeRequest`).
- **5.9 Next session**: interval chips (service default or 4 weeks), suggested date, "Book now" opens the new
  appointment sheet for this client at that date, "Save suggestion" writes the interval into the record, Skip.
- Pure rules in `Screens/Treatment/Support/`: `VoiceFlowRules`, `ReviewMerge`, `ReviewProposal`, `TreatmentDraft`,
  `TreatmentFormFields`, `TreatmentFormField`, `TreatmentAnswerFormat`, `TreatmentRecordBuilder`, `PhotoConsentRules`,
  `NextSessionRules`, `SavedSummary`, `FlowPhoto`, `TreatmentFlowStep`.
- Debug hooks (DEBUG only): `-uiVoice scripted` (`ScriptedVoiceCapture`, `ScriptedRecordStructuring`), `-uiCamera
  scripted` (`ScriptedCameraCapture`), `-uiRoute treatmentFlow` (in `HealthDebugRoute`), `-uiTreatmentFlow` (seed
  `Managers/Business/TreatmentFlowUITestSeeding.swift`: a signed photo consent for the seeded Ana Costa). Launch:
  `-uiSeed clientWithHealth -uiRoute treatmentFlow -uiTreatmentFlow -uiCamera scripted [-uiVoice scripted]`.

## Tests

- Unit (Fast): `BelloHubTests/Screens/Treatment/` (`SavedSummaryTests`, `NextSessionRulesTests`,
  `PhotoConsentRulesTests`, `VoiceFlowRulesTests`, `ReviewMergeTests`, `TreatmentRecordBuilderTests`,
  `TreatmentFlowViewModelTests`, `TreatmentFlowContrastTests`), `Managers/Treatment/ImageIOPhotoProcessingTests`
  (size, no upscaling, EXIF/GPS/TIFF removal, garbage refused), fakes `FakeVoiceCapture`, `FakeRecordStructuring`,
  `FakePhotoProcessing`. Fast: 1426 tests passed.
- UI: `TreatmentFlowUITests` (UISmoke: manual path to saved, next session and a camera photo; scripted-voice path
  through the review) passes. `TreatmentFlowAuditUITests` (skipped by UISmoke) passes for `en,ar` at default size and
  AX5 (`TEST_RUNNER_AUDIT_LOCALES=en,ar`).
- Strings: `Config/Locale/strings/s7-flow.json` (141 keys, 14 localizations), merged, `check-strings.sh` passes.

## Lessons

- A screen-level `.accessibilityIdentifier` placed after `.safeAreaInset` replaced the identifiers of the bottom bar
  buttons. Put the screen identifier on the ScrollView before the inset, and do not put one on a container whose
  children have their own (the Saved summary lost its row ids that way).

## ASSUMPTION candidates (for the coordinator to list in PROGRESS.md)

- ASSUMPTION: the camera opens for the missing kind (before, then after, then progress); a library photo takes the same.
- ASSUMPTION: "Save suggestion" on 5.9 writes `nextSessionSuggestion` ("4 wk") into the record (allowed inside the 24 h);
  it does not send any reminder (the "Remind client" and "Remind automatically" parts of the design need S6/S8 services).
- ASSUMPTION: a record from the voice path is `source: .voice` as soon as proposals were shown, `aiAssisted` only after
  the finished review kept something.
- ASSUMPTION: the first four summary rows are the preview on 5.6; the rest sit behind "Show all details".
- ASSUMPTION: with no photo consent signed, only "Only me" is offered; the signed date is not shown (the consent row says
  signed or not).

## Deviations from the design

- 5.6 does not show the "Suggested for Ana's profile" card (add a sensitivity from what she said): it needs a rule that
  reads the record's text, which belongs with the AI work (S7 back end).
- 5.7 has no slider or timeline of earlier visits' photos (only this visit's photos, side by side and as a list).
- 5.9 has no "Remind automatically" switch or "Remind client" button (see assumptions).
- Photo consent date not shown on 5.7.

## DESIGN.md additions (the coordinator applies them)

Screens 5.1 to 5.9 and the flow's navigation (`fullScreenCover` with its own stack: Register, then Listening, Organizing,
Review or Form, Saved, then Photos, Camera, NextSession; History from Saved); states: Register (loading, failed,
client missing, voice offer, manual only with three reasons, "heard nothing"), Listening (waiting, transcript, wrap-up),
Organizing (working, failed), Review (pending, decided, nothing kept), Form (validation), Saved, Photos (no consent,
consent, processing, failure), Camera (live, denied, no camera, review), NextSession. Components: `FlowBottomBar`,
`TreatmentVisitCard`, `TreatmentResultPicker`, `TreatmentChipGroup`, `TreatmentProductsInput`, `ReviewCard`,
`FlowPhotoImage`, `CameraPreview`. New tokens: none.

## What is not done

- Audit in `pt-BR`, `de`, `hi` (the default list); only `en,ar` were run.
- The deviation items above (sensitivity suggestion, reminders, slider/timeline).
- No unit test for the AV camera or the real voice (they sit behind protocols; D53).

## State at the checkpoint

Everything is committed on `s7-flow`. Passed: `scripts/test.sh fast` (1426 tests), `scripts/test.sh smoke` (all UISmoke tests, including the 2 new ones), `scripts/check-warnings.sh` (zero warnings: simulator, device, Release, test targets), `scripts/check-strings.sh`, the audit in `en,ar` at default size and AX5.

## Next commands

```
cd .claude/worktrees/agent-a1d5e53e13c286df5
TEST_RUNNER_AUDIT_LOCALES=pt-BR,de,hi ONLY_TESTING=BelloHubUITests/TreatmentFlowAuditUITests scripts/test.sh full
```
