# Routine simplification, agent B (items 9, 10, 11 and the marketing phrases)

Task: `docs/tasks/routine-simplification.md` (owner's text). Branch `routine-b` from `origin/build/v1` at `4f18c47`,
own worktree. Agent A owns items 1 to 8 and 12 on `build/v1`; nothing here touches Home, Alerts, Onboarding, the lock
screen, the treatment record steps other than the camera, or the localization plumbing.

## Map and proposal (written before the first code change)

### Item 9: import and the free limit (what exists)

- Flow: `Screens/Clients/Import/` (sources → mapping for a spreadsheet → choose → result), one
  `ImportClientsViewModel` for the whole flow. Rows are read into `ImportEntry` (ready, or skipped with a reason).
- The gate: `ClientRegistering` (`Managers/Clients/`), implemented by `ClientRegistrationService`, is the only way to
  create a client. `importClients(_:)` partitions the batch with `ClientDuplicateRules.partition` (same id or same
  phone, against existing clients and earlier rows), asks `RegistrationQuota.decision` for the fresh ones, reserves
  them on the server (`reserveRegistrations`, queued offline), saves the prefix it may and returns
  `ClientImportResult` (`registered`, `duplicates`, `malformed`, `blocked`). Blocked rows are **not saved**; the result
  screen offers the paywall.
- Before confirming, the choose screen shows only `ImportBatchFit` (selected count against `usage.remainingFree`): it
  ignores duplicates, so it overstates what is new and can claim a plan is needed when it is not. There is no way to
  pick a small group except unticking rows one by one.
- `RegistrationQuota` (Models/Plan) is the only owner of the number 10; `RegistrationUsage` is the screen snapshot.

**Proposal.**
1. A pure `ImportPlan` in `Screens/Clients/Import/Support/` replaces `ImportBatchFit` (one owner for the rule): from
   the chosen clients in list order, the existing clients and the usage it computes *new* (after deduplication with
   `ClientDuplicateRules.partition`, the same rule as the gate), *already in your list*, *free left now*,
   *registered now*, *waiting for a plan* and *free left after*, and a `kind` (`allFree`, `partlyFree`, `needsPlan`,
   `unlimited`, `nothingNew`). It also picks a trial group: "the first N new clients" (rows already in the list are
   passed over, so a trial of 5 registers 5). Tests with a fixed injected `now` for the rows.
2. The gate protocol gains a read: `knownClients()` (the existing clients, for the preview only; no write).
   If it fails, the plan falls back to the counter only and the screen says it could not check duplicates.
3. Choose screen: a summary card above the confirm button (always, not only when over the limit): "8 new · 2 already
   in your list", "3 of 10 free registrations left", and one sentence for the outcome: all free / "3 now, the other 5
   wait for Bello Hub Pro: they are not saved, nothing is charged" / plan active. A native `Menu` "Try a small group"
   (first 3, 5 or 10 new clients, and "as many as are free") next to Select all.
4. Result screen: the blocked count keeps the paywall offer and says the rows were not saved; when the paywall closes
   with a plan active, "Import the other N" re-runs the same selection through the gate (duplicates are skipped, so
   nothing is registered twice and nothing is silently paid).
5. Prices, the cumulative count, server reservation, offline queue and access to existing data are untouched (the
   gate's code does not change except the new read).

### Item 10: agenda setup (what exists)

- More > Booking page (`Screens/BookingSettings/`): `BookingRulesSection` lists eight rows flat: hours (door to
  `Screens/Availability/`), buffer, slot interval (D56), "Keep my day compact" (D56), minimum notice, booking window,
  cancellation rules, no-show protection. Each change saves at once through `BookingSettingsViewModel` →
  `BookingSetupService.saveAvailability`.
- Per-service extra time: `Services/Sheets/ServiceTimingSection` (prep, clean-up, processing switch with length and
  start), always expanded in the service editor.
- Slot engine: `Models/Agenda/FreeSlotsCalculator` (`plan(for: FreeSlotsRequest)` → `FreeSlotsPlan.all/recommended`),
  inputs: day, visible minutes, now, `AvailabilitySettings` (weekly, breaks, days off, buffer, notice, window, step,
  compact), appointments as `TimedInterval` with their `VisitTiming`, blocks, the new visit's timing and her shortest
  offer (`AvailabilitySettings.shortestOfferMinutes`). The server mirrors it; nothing here changes it.
- Profession catalogs (`Resources/Professions/professions-<loc>.json`) hold suggested services with minutes, no
  timing; the profile keeps `professions`.

**Proposal.**
1. Progressive rules: basic rows first (hours, time between clients, notice, window, cancellations, no-show), then a
   native `DisclosureGroup` "More options" with the slot interval and "Keep my day compact". In the service editor the
   extra-time section becomes a disclosure "Extra time (optional)", open when the service already has some.
2. Every rule gets a one-line example from the routine (footnote under the row), e.g. processing: "A 75-minute colour
   with 30 minutes of processing lets you fit a 20-minute fringe cut inside it."
3. Defaults by profession: a pure `ProfessionAgendaDefaults` (buffer, interval, compact per `ProfessionID`), offered
   as a "Suggested for <profession>" card with "Use these" when her values differ; it never changes anything by itself.
4. A visual preview "What clients see": a pure `SlotPreviewBuilder` (Support) builds a sample day (her next working
   day, her hours, breaks, buffer, interval, compact day, one sample visit of her shortest service booked in the
   morning) and runs `FreeSlotsCalculator.plan` locally, no server call. The card shows the times shown first as chips
   and the "also bookable" ones in a line, with a native menu to pick which service to preview (her active services;
   a 60-minute sample when she has none). Minimum notice and the window are left out of the sample on purpose (they
   say *when*, not *which* times) and the caption says so. Tests for the builder with a fixed `now`.
5. The D56 logic, the server and the published payload are not touched.

### Item 11: photo framing reference (what exists)

- `Screens/Treatment/Steps/CameraStepView` is the app's own camera (`CameraCapturing` / `AVCameraCapture`, preview in
  a 3:4 `CameraPreview`). It already lays a **ghost** over the preview at a fixed 35 % opacity: the latest photo of the
  *other* kind taken in *this* visit (`TreatmentFlowViewModel.ghostThumbnail`), with an on/off button. Nothing uses
  the photos of earlier visits.
- Photos: `TreatmentRepository.photos(for:)` + `photoData(id:)` (decrypted in memory, `PhotoData.image` ≤ 2048 px and
  a 320 px thumbnail); never the camera roll.

**Proposal.** The change fits in the existing screen: a pure `FramingReferenceRules` picks the reference (this visit's
other kind first, as today; otherwise her latest earlier photo of the same kind, then of any kind), loaded once in
memory by a ViewModel extension; the camera gets a "Show previous photo" switch, an opacity slider (15 to 60 %) and a
two-line guide (line up the outline, keep the same distance and light). Nothing is stored, composited or sent.
Evaluation and risks in `docs/agent-notes/photo-framing.md`. Overlap with agent A: only `CameraStepView` and a new
extension file in Treatment; agent A works on the record steps around it.

### Marketing phrases

No marketing document exists (`docs/store/` is App Store copy, `docs/16-MARKETS.md` is markets). Create
`docs/MARKETING.md` (the two phrases, where to use them, where not, adaptations in pt-PT, en, es, it, fr, de, tr, id,
hi, ar flagged `needs_review`), link it from `docs/README.md`, and add the phrase as the opening line of each store
description where it fits the 4000-character limit (the 170-character promotional texts are too full).

### Strings

New batch files `Config/Locale/strings/routine-b-*.json`, merged with `scripts/merge-strings.py`; keys that stop being
used are removed from their old batch and pruned.

## What changed (implementation)

### Item 9: import and the free limit
- `ImportPlan` (pure, `Screens/Clients/Import/Support/`) replaces `ImportBatchFit`: new clients after deduplication
  (`ClientDuplicateRules.partition`, the gate's own rule), already in the list, free left now, registered now, waiting
  for a plan, free left after, and a kind. Trial group: `trialSelection(size:from:existing:)` takes the first N *new*
  rows; `trialChoices` offers 3, 5, 10 (smaller than the list) plus the free count when useful.
- `ClientRegistering.knownClients()` (read only, for the preview). If it throws, the plan counts every row as new and
  says duplicates were not checked (`import.plan.unchecked`).
- Choose step: "Before you import" summary first in the list, rows already in her list marked and unticked, "Try a
  small group" menu. Result: "They were not saved and nothing was charged…"; after the paywall closes with a plan,
  "Import the rest (n)" re-runs the same selection through the gate (the clients registered the first time are
  duplicates then, so nobody is counted twice).
- **What happens to the rest when the import exceeds the free registrations (decision):** the gate registers the first
  new rows in list order up to the free count; the rest are **not saved and not charged**, counted as "Waiting for a
  plan" before confirming and as "n more need a plan" after; nothing is ever dropped silently or paid silently (a
  subscription only happens through the App Store paywall she opens herself).
- Unchanged: `RegistrationQuota` (the 10), the server reservation and offline queue, prices, existing data access.

### Item 10: agenda setup
- Booking page "Booking rules": profession suggestion card (`ProfessionAgendaDefaults`, "Use these", only while her
  values differ), basics card with an example under each menu, "More options" disclosure (start times, compact day;
  opens by itself when either is not at its default).
- "What clients see": `SlotPreviewBuilder` + `SlotPreview` (pure) run `FreeSlotsCalculator.plan` locally on her next
  working day with her settings and services, one sample booking of her shortest service an hour after opening,
  notice/window/days off left out (said on screen). Service menu when she has two or more services.
- Service editor: "Extra time (optional)" disclosure (closed unless the service has extra time) with the owner's
  example. D56 logic, server, payloads: untouched.
- Profession defaults are judgement (documented in the type), not catalog data: esthetician 15/15, hair 10/15,
  lash 15/30, nail 10/15, makeup 15/30, tattoo 30/30, barber 5/15, massage 15/30, other 15/15 (buffer/start-time
  grid), compact day on for all.

### Item 11: photo framing
- Implemented as a small change (evaluation `docs/agent-notes/photo-framing.md`): `FramingReferenceRules`,
  `TreatmentFlowViewModel+FramingReference`, `FramingGuides`, camera controls. The old "Ghost" toggle and its key are
  gone. Later-stage items (automatic position hints with Vision, edge overlay, same zoom/lens) are listed there and
  should go to the PROGRESS post-v1 list.

### Marketing
- `docs/MARKETING.md` (phrases, use / don't use, 13 adaptations `needs_review`), linked from `docs/README.md` and
  `docs/store/README.md`; the main phrase opens every store description draft (lengths recounted, all < 2,710 / 4000).

### Strings
- New batches `routine-b-import.json` (18 keys), `routine-b-agenda.json` (23), `routine-b-camera.json` (3); one en-GB
  override (`services.timing.example`, colour/fringe). Removed: `import.choose.partial{,.detail}` (s4-import),
  `treatmentFlow.camera.ghost` (s7-flow), `services.timing.title` (d56-smart-slots). `check-strings.sh --final` passes.

## Checks run (simulator iPhone 17 Pro Max, 1D7CD4D7)
- `scripts/test.sh fast`: **2248 tests in 320 suites passed** (strings `--final`, privacy, legal, professions gates
  included). Earlier runs under heavy machine load had `Wait` timeouts in `PublishingServiceTests` and
  `RescheduleRequestViewModelTests` (untouched suites); both pass alone and in the last full Fast run.
- UI: `ImportClientsUITests` (3, incl. the new small-group test), `ServicesUITests.testExtraAndProcessingTime`,
  `BookingSetupUITests.testSlotIntervalAndCompactDay`, `PhotoFramingUITests` (new): all pass.
- Audits: `ImportAuditUITests` (default + AX5, en/pt-BR/de/ar/hi) pass after making the summary rows one
  label+value element and moving the title and controls above the summary; `ServicesAuditUITests` and
  `TreatmentFlowAuditUITests` (camera included) pass at both sizes; `BookingSetupAuditUITests` booking page,
  policies and publish tests pass at both sizes. `testAvailabilityAtDefaultSize` fails twice on
  "availability.addBreakButton" hittability in the Availability screen, which this branch does not change (the test
  already carries workarounds for that row); left open.
- `scripts/check-warnings.sh`: zero warnings on simulator, device, Release and the test targets.

## Needs a real iPhone
- Camera framing reference: the overlay alignment with the real capture (preview layer vs processed photo), the
  slider on the live preview, memory with a 2048 px reference (H19 camera check).
- Import from real Contacts with duplicates against an iCloud-synced list; the server count (`reserveRegistrations`)
  versus the local plan when another device registered clients while this one was offline.
- "Import the rest" after a real (sandbox) subscription bought from the paywall inside the import sheet (H14).

## Mocks versus production
- All unit tests use fakes (`FakeClientRegistrar`, `FakeBookingSetupRepository`, `FakeAgendaRepository`, in-memory
  vault); UI tests use the DEBUG fixtures (`-uiContacts`, `-uiRegisteredClients`, scripted camera). Nothing here
  talks to Firebase; nothing was deployed.
- The slot preview is the same Swift calculator the shared fixture checks against the server (`freeSlots.ts`), so
  it matches production rules, but it is a sample day, not a server answer.

## Open items
- `onboarding.ready.importButton` is the entry the import UI tests use; agent A's onboarding change may move it (then
  `ImportClientsUITests.openImport` needs the new entry).
- `BookingSetupAuditUITests.testAvailabilityAtDefaultSize` hittability failure on the Availability screen (not
  touched here); worth a look on `build/v1`.
- The two Fast-plan failures seen under full load (`PublishingServiceTests` "picking the missing address publishes by
  itself", `RescheduleRequestViewModelTests` "asked time is taken first") are `Wait` timeouts in suites this branch
  does not touch; both pass when run alone.

## Paragraph for PROGRESS (agent A pastes it)

**2026-10-11: routine items 9, 10, 11 and the marketing phrases (branch `routine-b`, notes
`docs/agent-notes/routine-b.md`).** Import: before confirming, "Before you import" shows new registrations after
deduplication, free registrations left, registered now and waiting for a plan (`ImportPlan`, the gate's own rules);
"Try a small group" selects the first 3/5/10 new rows; rows past the free registrations are never saved or charged and
"Import the rest" re-runs them once a plan is active. Booking page: basics first, "More options" (start times, compact
day), a profession suggestion with "Use these", an example under each rule and a live "What clients see" preview
(`SlotPreviewBuilder` on `FreeSlotsCalculator`, no server call); the service editor's extra time is a disclosure with
the owner's colour example. Camera: optional "Show previous photo" framing reference with opacity slider and
thirds guides, decrypted in memory only (`docs/agent-notes/photo-framing.md`; automatic Vision hints, edge overlay and
same zoom are post-v1). Marketing phrases in `docs/MARKETING.md` and the store descriptions. Strings in 14
localizations; nothing deployed. Post-v1 list: photo framing later stage (Vision position/distance hints, edge-only
overlay, same lens and zoom, exposure hints).
