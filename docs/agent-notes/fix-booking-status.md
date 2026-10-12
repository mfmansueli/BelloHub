# Fix: booking status changes do not reach the app (or the web)

Reported by the owner on a real iPhone against the dev server (2026-10-12): "The states changed on bookings do not
reflect reality in the app and on the web." Two concrete reports followed:

1. **Client side.** On her manage page (`/m/{token}`) the client first moved a booking to another day and then cancelled
   it. Home and the Calendar kept showing the booking as confirmed, at its old time, also after closing and reopening
   the app.
2. **Professional side.** In the app she cancelled a link booking (Mateus, Consultation, today 1:00 PM), the sheet said
   "Appointment cancelled. WhatsApp is open", and when she came back from WhatsApp the visit screen said "Confirmed"
   again (Home and the Calendar too).

Branch `fix-booking-status`, from `build/v1` at `afc4835`.

## Root causes, in plain words

**A. The sync looked for the visit at the booking's new time.** Each sync reads her bookings from the server and, to
update the visits it mirrored earlier, loaded the visits of the vault **only between the earliest and the latest time of
the bookings it had just read** (plus a day on each side). A booking the client moved now sits at its new time, while
its visit is still at the old one, outside that window, so the sync did not find it:

- moved and then cancelled: the sync saw "a cancelled booking it never mirrored" and, by design, skipped it ("a
  cancellation the phone never saw is not worth a cancelled visit"). The old visit stayed confirmed for good. Reopening
  the app ran the same sync with the same result, which is why it never repaired itself.
- moved only: the sync saw "a confirmed booking it never mirrored" and added **a second visit** at the new time; the old
  one stayed confirmed.

Whether the old time falls outside the window depends on her other bookings of the last 14 days and the future; with a
few test bookings it almost always does when the moved booking was the earliest or the latest one.

**B. Her own changes to link visits never reached the server, and the next sync undid them.** The app had no call to
`cancelBookingByOwner`, `moveBookingByOwner` or `markNoShow` (mark) anywhere: cancel, move and no-show changed only the
iPhone. The server kept the booking `confirmed` (so the client's manage page, the free times and the waitlist still
said the time was taken), and the next sync (every 90 s, on a push, and when the app comes back from WhatsApp) copied
the server's `confirmed` back over her cancel, her new time or her no-show. Closing a visit was undone the same way:
the server never hears of a close and keeps a past booking `confirmed`, and the importer turned the closed visit back
into a confirmed one.

**Smaller defects found on the way (fixed too):**

- Bookings were read in one page of 500 ordered by start: a busy agenda (14 days back plus every future booking) could
  lose its latest bookings without any error.
- A sync asked for while another ran (a push during the poll) was dropped, so a change could wait for the next poll.
- The ephemeral `URLSession` still had an in-memory cache; reads are POSTs today, but the new single-booking read is a
  GET, so the cache is now off.

**Ruled out, with evidence:**

- Undecodable documents and new server fields: the REST reader skips one unreadable document and keeps the rest, unknown
  fields are ignored, an unknown status falls back to "waiting" (`RemoteInboxRepositoryTests.toleratesUnknownShapes`).
- Triggers: foreground (`RootView` scenePhase), push (`PushService`), pull to refresh and the 90 s poll all call the sync;
  `isSyncing` and `syncTask` always reset.
- Presentation: Home, the Calendar and the visit detail read the vault through `AppointmentService.stream`, which pushes
  every change; the detail ViewModel streams all visits. Once the vault is right the screens are right (the UI tests
  below show it), so nothing in the views was frozen.
- Motion work (46faece, 945d1ac, afc4835): not involved. Both causes live in `BookingSyncService`/`BookingImporter`, last
  changed on 2026-10-10 (9991b5e), and both reproduce in pure service tests with no view at all. No motion file was
  touched. One observation for the motion agent, not a defect found: with `-uiTesting`, `home.next.client` and
  `appointment.statusChip` match more than one element on those screens, so the new UI test uses `firstMatch`.
- Server: `cancelBooking`, `rescheduleBooking`, `confirmPresence`, `reportLate`, `cancelBookingByOwner`,
  `moveBookingByOwner` and `markNoShow` all set the status (where they change it) and bump `updatedAt`; the client ones
  set `lastClientAction`, which is what `handleBookingWritten` pushes on. A moved booking keeps its document id.
  `/api/**` is `no-store`, the manage page refetches on every step and after an action, and the web app has no service
  worker. Nothing on the server or the web needed a change (a new integration test pins the round trip).

## What changed

- `AgendaRepository.linkedAppointments()`: every visit mirrored from a booking, whatever its time. The SwiftData store
  searches each row's plain JSON for the `bookingID` key before decoding, so only link visits are decoded (2,000 visits:
  the contract test runs both stores, saves included, in about 1.7 to 3 s; the lookup itself is bounded at < 2 s).
- `BookingSyncService` finds visits by booking id (`linkedAppointments` plus the window, which stays for the conflicts
  with visits booked by hand). A visit that still holds time but whose booking was not in the list (moved before the
  window, a page cut short) is read by id (`InboxRepository.booking(uid:id:)`, Firestore GET `bookings/{id}`, at most 25
  per pass); a booking the server no longer has is remembered and not read again in the session.
- `BookingImporter`: duplicates mirrored from one booking (an older build made one per move) become one: the visit with
  something of hers on it (note, session plan, a status she set) or else the oldest stays, an untouched copy is deleted.
  A server `confirmed` never reopens a visit she closed, cancelled or marked as a no-show. A server `cancelledByPro` over
  her own cancel keeps what she recorded (who asked, when). Bookings in `heldLocally` are left alone.
- Her changes reach the server: `AppointmentService` reports every change of a link visit (`LinkVisitChange`, through
  `LinkVisitChangeReporting`) after the vault took it; `BookingSyncService` queues `cancelBookingByOwner`,
  `moveBookingByOwner`, `markNoShow` (mark with the booking id; forgive) on the `OutboundQueue`, which persists them, sends
  them in order per booking and retries when offline. Until the server answered, and for any read that started before
  the answer, the booking is held (`LinkChangeLedger` + the queue's pending actions), so a stale read cannot undo her
  change; a relaunch keeps the protection because the queue is on disk. When the server refuses for good (the client
  had already cancelled: `BOOKING_NOT_ACTIVE`), the next sync shows the server's truth.
- `RemoteInboxRepository.bookings` pages through every booking (500 per page, the next page starting at the last start,
  duplicates dropped by id, at most 10 pages).
- `syncNow`/`syncAsync` run one more pass when asked during a pass.
- `URLSessionTransport`: no URL cache.
- UI tests: `-uiInbox linkVisit` (only Bianca's confirmed booking, half an hour from now) and `-uiInbox clientOnTheWeb`
  (the same, and each time the app leaves the foreground the server moves the booking 20 days and cancels it, as the
  client did). DEBUG only.

Behaviour the owner should know: cancelling or moving a link visit in the app now also e-mails the client (when she gave
an e-mail), as `cancelBookingByOwner`/`moveBookingByOwner` always did; the WhatsApp message is unchanged. A cancel she
records as "the client asked" is `cancelledByPro` on the server (the owner call has one meaning: it never counts against
the client), while the app keeps her own record.

## How it was reproduced (failing first)

Commit 1 (`Booking status round trip: failing tests …`) added the tests on the unchanged code: 27 issues in 9 tests of
`BookingSyncServiceTests` — moved then cancelled (both directions) left the visit confirmed; moved (both directions) added
a second visit; the stale-plus-duplicate repair failed; app cancel, move and no-show never reached the server and the
next sync reverted them; a closed visit came back confirmed. Only "presence confirmed and lateness reported on the web"
passed, as expected (that path worked). After the fix all pass.

## Tests

- `BookingSyncServiceTests` (15 cases, new): both reports end to end over the fake server and the in-memory vault, plus the
  queue surviving a relaunch, the look-up by id, a gone booking read once.
- `BookingImporterTests` (+7): her decisions win, cancel details, held bookings, moved booking found wherever it is,
  duplicates with and without her note.
- `RemoteInboxRepositoryTests` (5, new): paging past 500 with a page boundary inside equal starts, unreadable/unknown
  documents, read by id, the four owner calls checked against the server's own schemas (`ServerContract`), a refusal.
- `LinkVisitChangeTests` (1, new), `RepositoryAgendaContractTests` (+1: link visits among 2,000, both stores).
- `BookingStatusUITests` (2, new, in UISmoke): the client moves then cancels on the web while the app is away, Bianca
  leaves Home after the app comes back; she cancels in the app and the chip still says "Cancelled" after coming back.
  Written after the fix (the scenario needs the new server calls), not run on the old build.
- Functions: `manageBooking.test.ts` +1 (moved then cancelled keeps one document under its id at the new time, with
  `updatedAt` and `lastClientAction` bumped, the owner query returns it, the page says cancelled, a late owner cancel is
  `BOOKING_NOT_ACTIVE`).

## Gates

Measured on the branch head after merging `origin/build/v1` (c4669cd), simulator iPhone 17 Pro Max:

- `scripts/test.sh fast`: 2450 tests in 358 suites, green.
- `scripts/check-warnings.sh`: zero warnings on simulator, device, Release and the test targets (before the merge the
  only warnings were three motion line lengths, fixed upstream by 93a3bfb).
- `scripts/test-firebase.sh all`: lint, typecheck, build, audit, unit 1005, rules 67, use cases 332, transport 19, green.
- UI: `BookingStatusUITests`, `InboxUITests`, `AppointmentUITests`, `HomeUITests`, `CalendarUITests`,
  `SuggestTimeUITests`, `MailboxAlertsUITests`: 15 tests, green.
- Not run: the whole Full plan and `scripts/test-web.sh` (no web change).

Seen once during the work and not related: the Fast plan crashed in `VaultMigrationTests` ("A store written by an older
schema …", `NSUnknownKeyException` for the key `thumbnail` on an older `VaultItem`); the next full Fast run was green.

## Deploy and devices

- **No server or web change**: nothing to deploy. Only a functions test was added.
- **The app must be reinstalled** on both iPhones. On the first sync the new build repairs what the old one left: a visit
  at the old time of a moved or cancelled booking is updated, an untouched duplicate is removed.
- **Real iPhone checks** (H3): the round trip on the dev server with a real manage link (move then cancel; cancel in the
  app then WhatsApp then back); a cancel made in airplane mode, then the app killed and reopened online; two iPhones on
  one account (each syncs on its own; CloudKit copies of one booking are merged by the importer).

## Files likely to conflict with `build/v1`

`BookingSyncService.swift` (reorganised into the class plus same-file extensions), `RemoteInboxRepository.swift`,
`OutboundQueue.swift`, `OutboundAction.swift`, `InboxRepository.swift` (new requirements: any other conformer needs
them), `AppointmentService.swift`, `AgendaRepository.swift`, `UITestInboxRepository.swift`, `UITestInboxFixtures.swift`,
`AppDependencies.swift` (`makeUITestInbox`), the test fakes `FakeInboxRepository.swift` and `InboxRig.swift`.

## For PROGRESS.md (paragraph for the coordinator)

**2026-10-12: fix-booking-status** (notes `docs/agent-notes/fix-booking-status.md`). Two causes of "booking states do
not match": (A) the sync found mirrored visits only near the bookings' new times, so a booking the client moved and then
cancelled stayed confirmed at its old time (a move alone added a duplicate); (B) cancel, move and no-show of a link
visit in the app never reached the server (`cancelBookingByOwner`/`moveBookingByOwner`/`markNoShow` were never called)
and the next sync put the server's "confirmed" back, also over a closed visit. Visits are now found by booking id, a
visit whose booking left the list is read by id, duplicates are merged, booking reads page past 500, her changes go
through the outbound queue and a stale read can no longer undo them. No server or web change; the app must be
reinstalled (it repairs stale visits on its first sync).
