# Smart slots (D56): notes

Task: `docs/tasks/smart-slots.md` (owner, 2026-10-10). Decision: D56 in `docs/02-DECISIONS.md`. Branch `build/v1`.

## The rule as built (one owner per side)

`BelloHub/Models/Agenda/FreeSlotsCalculator{,+Day,+Segments}.swift` and `firebase/functions/src/lib/freeSlots.ts`
(`planSlots`) are line-by-line mirrors. Both return two lists: `all` (every free start, all bookable) and
`recommended` (shown first).

1. **Shape of a visit** (`VisitTiming`): `prepMinutes` and `cleanupMinutes` (0 to 60) are blocked before and after
   the visible stretch; `processingMinutes` from `processingStartMinutes` after the start leaves her free. A visit is
   held as *segments*: `[start − prep, end + cleanup]`, split around the processing stretch. Each segment edge says
   whether the buffer is owed there: yes at the outer edges of a visit, no at a processing edge, a break or a block.
   Two segments clash when the gap between them is smaller than the buffer owed where they meet. A processing stretch
   outside the visit is ignored (treated as no processing); the server rejects it on publish anyway.
2. **Candidates**: the grid from the start of each working stretch (`slotStepMinutes`, default 15; 0 = "match the
   service", which steps by prep + visit + clean-up + buffer starting once the first prep is done), plus anchors:
   right after every segment (+ buffer when owed + the new visit's prep) and right before it (− buffer − clean-up −
   visit), the stretch start + prep and the stretch end − clean-up − visit. Anchors are rounded inwards to the
   5-minute clock (after-anchors up, before-anchors down) so a client never sees 10:17.
3. **Free**: start ≥ now + minimum notice; the whole blocked stretch inside the working stretch; the whole blocked
   stretch clear of breaks and blocks (they are never shared); every segment of the new visit clear of every segment
   of every visit or hold (so a visit can sit inside another's processing time, and a visit with processing can wrap a
   short one).
4. **Compact day** (`compactDay`, default on): for each free start, the free time before it (back to the nearest
   segment end, with its buffer, or the stretch start) and after it (to the nearest segment start or the stretch end)
   is a *dead fragment* when `0 < slack < shortest offer + buffer`, where the shortest offer is her shortest active
   service with its prep and clean-up. The minimum notice is NOT an edge: time that has passed is lost whichever start
   she gets, and treating it as an edge hid 10:00 at 09:50 for no gain. Starts are grouped by the gap they sit in
   (previous edge, next edge). Per gap: the starts with no dead time; if none, those with the least dead minutes, then
   the fewest dead fragments. So a day's only possible times are never hidden.

Where it is used: `getSlots` (`slots` = recommended, `more` = the rest, absent when empty), `holdSlot`,
`createBooking`, `rescheduleBooking`, `requestReschedule`, `respondRescheduleRequest`, `offerWaitlistSlot` (all
accept any start of `all`; alternatives after `slotTaken` come from `recommended`), the waitlist match after a
cancellation (a service matches only when it now has a free start whose blocked stretch overlaps the freed one), and
the app's `OpenTimes` (New appointment and Reschedule suggestions; "Show all times" there too). The
`SchedulingWarningEngine` still only warns: overlap and buffer warnings now use the segments, so a visit inside a
processing stretch is not an overlap and prep or clean-up can bring a neighbour inside the buffer.

## Data (all optional, additive)

- `Service.timing: VisitTiming?` in the vault (nil = plain, also for every service saved before D56).
- `AvailabilitySettings.slotStepMinutes: Int?` (nil = 15) and `compactDay: Bool?` (nil = on), published with
  `publishAvailability`; `busy[]` appointments carry their service's timing.
- `PublicProfileDoc.services[]`: `prepMinutes`, `cleanupMinutes`, `processingStartMinutes`, `processingMinutes`
  (sent only when not 0). Bookings and holds snapshot the same four fields, so a later edit of the service never moves
  a booked visit (rescheduling keeps the booking's own shape).

## Worked examples (morning 09:00 to 13:00, buffer 10, shortest offer 30)

Legend: `█` a visit, `░` processing (free), `·` free, `x` dead gap. Times are local.

**A. Empty morning, 75-minute service, 15-minute grid.**
Before: 09:00, 09:15, 09:30, … 11:45 (12 times, all equal).
After: the same 12 are bookable; shown first 09:00, 09:45, 10:00, 10:15, 10:30, 10:45, 11:00, 11:45. Behind "Show all
times": 09:15, 09:30 (leave 15 or 30 minutes before, too short for 30 + 10) and 11:15, 11:30.

**B. A 30-minute visit 09:35 to 10:05, 75-minute service, 30-minute grid.**
```
09:00 ·········· 09:35 ███ 10:05 +10 | 10:15 ████████████ 11:30 ········ 13:00
```
Before: 10:30, 11:00, 11:30 (10:15 is not on the grid; 11:45 neither).
After: 10:15 (anchored right after the visit and its buffer), 10:30, 11:00, 11:30, 11:45 (anchored to end at
closing). Shown first: 10:15, 11:00, 11:45. 10:30 would leave 10 minutes nobody can use; 11:30 leaves 15 at the end.

**C. Visits 09:30 to 10:00 and 11:00 to 12:15, 30-minute service.**
```
09:00 xx 09:30 ███ 10:00 +10 | 10:10 ██ 10:40 x 10:50 | +10 11:00 ██████ 12:15 +10 | 12:25 ██ 12:55 x 13:00
```
Before: 10:15 and 12:30 only.
After: 10:10, 10:15, 10:20, 12:25, 12:30 are all free. In the 10:10 to 10:50 gap every time leaves 10 dead minutes:
10:10 and 10:20 leave one sliver, 10:15 leaves two of 5, so 10:10 and 10:20 are shown first. In the 12:25 to 13:00 gap
both times leave 5 minutes and both are shown: nothing better exists there (the honest fallback).

**D. Processing: colour 09:00 to 10:30, free 09:30 to 10:15 while it develops; a 30-minute service.**
```
09:00 ███ 09:30 ░░░░░░░░░ 10:15 ██ 10:30 +10 | 10:40 …
```
Before: the colour is solid; the first time is 10:45.
After: 09:30 and 09:45 (inside the processing time, no buffer owed there), then 10:40 (anchored), 10:45, … With 5
minutes of prep on the short service: 09:35 and 09:45.

**E. "Match the service", 75 minutes + 10 buffer.** 09:00, 10:25, 11:45 (the last anchored to end at 13:00). With 5
minutes of prep and of clean-up: 09:05, 10:40, 11:40.

**F. On the dev seed (emulator e2e story).** Maria (09:00 to 19:00, lunch 12:30, buffer 15) has her own 30-minute
visit 09:35 to 10:05; Deep Cleansing (75) is offered at 10:20, not 10:15 or 10:30. 10:20 and 11:15 are shown first
(each leaves one 55-minute gap before lunch, the least possible); 10:30, 10:45 and 11:00 are behind "Show all times".

## What competitors call these (checked from memory of their public help pages, not re-verified online in this
session: no web access was used)

Fresha: "time slot interval", "extra time" (blocked / processing). Square Appointments: "processing time" (initial,
processing, final duration) and "time between appointments". Acuity: "start time increments" and "padding". Vagaro:
"processing time" and "gap avoidance"-style booking options. Booksy and SimplyBook.me: options that offer times next
to existing appointments first. BelloHub's difference: anchors are exact (not only a coarser grid), the gap rule never
hides a day's only times, and the same rule runs on the server, the web page and her own calendar.

## Tests

- Shared fixture (`firebase/scripts/rules-fixtures/generate.sh` compiles the real Swift files, the TypeScript reads the
  JSON): 239 free-slot cases (100 old ones, their 100 compact variants, 39 D56 cases incl. DST days), each checking
  `all` and `recommended`. The DST D56 cases include a visit with processing across the Lisbon and New York changes.
- Hand-worked: `test/unit/smartSlots.test.ts` (11) and `FreeSlotsSmartSlotsTests` (9, same expectations).
- Emulator use cases: `test/integration/smartSlots.test.ts` (9): anchored + `more` + hold of a `more` time, compact
  off, match the service, stored fields, processing from a published busy visit, extra-time snapshot, booking inside
  processing and refusal outside it, reschedule keeps the snapshot, waitlist match.
- App: `ServiceTimingRulesTests`, `AvailabilitySlotSettingsTests`, `SmartSuggestionsTests`, `PublishTimingPayloadTests`
  (incl. the server's JSON schemas), BookingSettingsViewModel, WaitlistMatcher. UI: `ServicesUITests
  .testExtraAndProcessingTime`, `BookingSetupUITests.testSlotIntervalAndCompactDay`.
- Web: parse test for `more`; e2e-local story `test/e2e-local/smartSlots.spec.ts` (real functions).

## Left / notes for later

- The app's own calendar takes each visit's shape from its service's current values (the vault has no per-visit
  snapshot); link bookings keep the server's snapshot. Moving or editing a service therefore changes how her past
  manual visits are drawn into suggestions, not what the server holds for link bookings.
- Guests (D19) share the first person's processing position only; a guest's own processing is not modelled.
- "Outside hours" warnings still look at the visible stretch, not the prep before opening.
- The mock server of the web e2e (`web/test/mock-server`) does not compute anchors; the D56 story runs against the
  real functions in `scripts/e2e-local.sh`.
- Found and removed during the run: a mock server left listening on port 4010 since 2026-10-09 17:08 (an earlier
  session) made two waiting-list e2e tests fail with 404; `InboxRig` waited only 3 s for the first sync and flaked
  under the Fast plan's load (now 20 s).
