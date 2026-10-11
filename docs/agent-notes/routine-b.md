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
