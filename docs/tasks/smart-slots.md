# Task: smart slots for services of different durations

Queued by the owner on 2026-10-10 ("se a profissional tem serviços com tempos variados... como está sendo feita a
lógica... como apps concorrentes fazem? Tem que se aprofundar nisso e fazer melhor"). Runs after S9, before S11.
One agent, `model: opus`, `effort: high`. Commit first, test after. Server, web and app change together: the
rule has ONE owner on each side and the shared table tests keep them identical (`FreeSlotsCalculator` ↔
`functions/src/lib/freeSlots.ts`).

## What exists today

- Start times are generated on a fixed 15-minute grid (`SLOT_STEP_MINUTES = 15` on the server,
  `FreeSlotsRequest.stepMinutes = 15` in the app) inside each weekly window.
- A candidate `[start, start + totalDuration]` (service + add-ons + guests, D19) is offered when it does not
  overlap a break or a block, and keeps `bufferMinutes` (one global value) away from every existing visit or hold.
- Reschedule reuses the booking's own duration. Holds last 5 minutes (D32).
- There is no per-service extra time, no processing time, no gap awareness: a 30-minute booking placed in the
  middle of a free morning can leave fragments nobody can book.

## What competitors do (for reference, verify the current product names in the agent notes)

- **Slot interval setting** (Fresha, Square Appointments, Acuity "start time increments", Calendly): 5 to 60
  minutes, or "same as the service duration".
- **Per-service extra time** (Fresha "extra time", Acuity padding, GlossGenius): blocked prep before and clean-up
  after that the client does not see in the price.
- **Processing time** (Fresha, Square, GlossGenius, Vagaro): a middle stretch where the professional is free
  (hair colour developing, mask setting) and another client can be served.
- **Gap avoidance** (Vagaro, Booksy, SimplyBook-style "prevent gaps"): offer first the start times that sit right
  against an existing visit so the day stays compact; optionally hide times that would leave an unbookable gap.
- **Honest last slot**: a visit may end exactly at closing time.

## What to build (better than the sum of the above)

1. **Anchored candidates, not only the grid.** Candidate starts = the grid ∪ {end of each visit + buffer} ∪
   {start of each visit − buffer − totalDuration} ∪ {window start} ∪ {window end − totalDuration}. A 75-minute
   service after a visit ending 10:05 with a 10-minute buffer is offered at 10:15 even when the grid says 10:30.
2. **Gap-aware ranking with an honest fallback.** For each candidate compute the fragments it leaves before and
   after inside the window. A fragment is *dead* when it is shorter than the shortest bookable offer of that
   professional (shortest active service + its extra time + buffer). Default mode "Keep my day compact": show the
   times that leave no dead fragment; a "Show all times" link reveals the rest. The professional can switch the
   mode off in Booking settings. Never hide a day's only possible times.
3. **Per-service extra time** (`prepMinutes`, `cleanupMinutes`, both default 0, 0 to 60) added to the blocked
   stretch but not to the visible duration or price; **processing time** (`processingMinutes`, inside the visit,
   default 0) during which the professional is free: another booking may start inside it if it fits entirely in
   the processing window (and its own extra time does). Keep the data model additive and optional
   (`Service`, `PublicProfileDoc.services[]`, `AvailabilityDoc` unchanged).
4. **Slot interval setting** on Booking settings: 10, 15 (default), 20, 30, 60 minutes, or "match the service".
   Lives in `availability/{uid}` as `slotStepMinutes`; published with the availability.
5. **The app's own calendar** (manual booking by the professional) uses the same engine for suggestions and the
   `SchedulingWarningEngine` keeps warning instead of forbidding (she may override).
6. **Reschedule and waitlist** use the same candidates (a freed slot is offered to the waitlist only when it fits
   the person's offer with these rules).

## Tests (the valuable ones are pure)

- Table tests shared by Swift and TypeScript (`web/test/vectors/` style or the existing shared table): morning
  09:00 to 13:00, services of 30 and 75 minutes, buffer 10, with 0, 1 and 2 existing visits; DST day; processing
  time with an inner booking; "match the service" step; dead-fragment detection with the shortest offer; the
  fallback when every candidate leaves a dead fragment.
- Web: Playwright story that books a 75-minute service around an existing 30-minute one and sees the anchored
  time. App: unit tests for the settings screen and the calendar suggestions.
- Emulator use-case tests for `getSlots`, `holdSlot`, `createBooking` with the new fields; API.md and schemas.

## Deliver

Decision entry (D56) in `docs/02-DECISIONS.md` with the rules above in one paragraph; `docs/05` and `docs/10`
updated; strings in 14 localizations for the new settings and the "Show all times" link; deploy functions and
web to dev; `docs/agent-notes/smart-slots.md` with worked examples (before/after timelines).
