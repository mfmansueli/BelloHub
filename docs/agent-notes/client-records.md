# Client records and agenda (2026-10-12)

Owner request (Portuguese, 12 items): make the client record the center of a client and connect it to the agenda,
keeping data, identity, features and security. Built on `claude/practical-dijkstra-hy0d79` from `0978ea2` in a Linux
cloud container **with no Swift toolchain**: nothing here was compiled or run. Two independent read-through reviews
looked for compile errors; their findings were applied. Before merging, run on a Mac: `scripts/build.sh`,
`scripts/test.sh fast`, `scripts/test.sh smoke` (UI tests changed: Clients, ClientRecord, Records, TreatmentFlow,
PhotoFraming, Motion, Home) and `scripts/check-warnings.sh`.

## Commits
1. `867db07` Data model: visit day (`performedAt`), draft/finalized status, lock starts at finalize, links.
2. `1f4a3aa` Client record, timeline, visit details, the one-screen visit form with drafts.
3. `700dd24` Agenda opens the record; saved options and Personalization.
4. `ac80c38` Before you start shows the last visit; fixes from the first review.
5. `900f926` Home and Alerts list the records still owed; evening notification.
6. `25e8aeb` Documents per visit, record fields per service and needed to finalize, honest onboarding.

## Decisions (routine UX decided without asking, as the request allowed)
- **24-hour lock vs drafts.** A draft never locks (`lockedAt = .distantFuture`); the 24 h start when she finalizes,
  using the repository's clock. Records from before drafts keep `createdAt + 24 h`. A finalized record never goes
  back to draft (`TreatmentRecordSaveRule`). After the lock, changes are corrections with a reason, as before.
- **Visit day vs creation day.** New optional `performedAt`. No migration writes dates: old records show the linked
  booking's start, else "written on <day>" (`RecordVisitDate`). She can set the day later on the record (direct while
  open, a correction once locked); the correction is applied everywhere through `RecordCurrentValues`.
- **One record per visit.** The form keeps one id for its whole life, adopts the record already linked to the
  appointment (`RecordForAppointment`: finalized first, then newest), never stores an empty draft (service aftercare
  text or an untouched base visit do not count), and stores the draft before a photo points at it.
- **Grouping only by links.** Photos and incidents belong to a visit by `recordID`, a record to a booking by
  `appointmentID`. Photos without a visit stay in "Organize photos", where she places them by hand.
- **Completing a booking ≠ finalizing a record.** "Mark completed" asks "Register now" or "Later"; a completed booking
  with nothing written shows as "Record pending" on the timeline, in Home "To follow up" (14 days) and Alerts.
- **Reuse a visit** copies only parts she picks (technique, products, aftercare, notes, reminder, her fields); never
  photos, result, reaction, visit day or documents.
- **Saved options** (`SavedOption`, sealed name) for techniques, preferences, sensitivities and recurring requests;
  products and her fields' choices reuse the existing Products catalog and template options. Dedupe ignores case,
  accents and spacing (`OptionNameRules`), never merges different words. Archiving hides from suggestions only.
  Fixed states (status, permissions, severities, standard fields) never get "+ Add".
- **Required fields** are checked only by "Finalize record"; drafts always save. Per-service fields: empty list means
  every service; a visit with no service yet asks every field.
- **Notifications** for records owed carry only a count (no names on the lock screen), once in the evening, rebuilt
  on every vault change; switch in Notification settings.
- **Documents**: a consent may name a visit (optional). The record never depends on the client portal or a general
  consent; a signed photo consent allows only photo sharing; portfolio is listed apart.
- **Voice and AI** stay stubs; texts that presented them as active were rewritten; the More row says "Optional".

## Scenarios (how each is covered; all by reading and tests written, none executed)
| Scenario | Where |
|---|---|
| Walk-in without portal or consent | Home "Register visit" → client picker → form with service picker; record never needs a document (`ClientProfileViewModelTests.walkInVisit`, `ClientRecordUITests`, `HomeUITests`) |
| Private records and photos while a document is pending | photos private by default without a signed photo consent (`PhotoConsentRules`), documents section says so |
| Draft recovered after relaunch | `TreatmentFlowViewModelTests.recoverDraftAfterRelaunch`; drafts listed on Home/Alerts/timeline |
| Photos tied to the right visit | `photoBeforeTheForm`, `ClientTimelineBuilderTests` (no date grouping) |
| Old visit with a different day | `visitDay`, `RecordVisitDateTests`, visit-day correction |
| All fields and corrections in details | `RecordCurrentValuesTests`, `VisitDetailViewModelTests` |
| Reuse without improper data | `VisitReuseTests`, `baseFromPastVisit` |
| New tags/options, archive, history kept | `OptionNameRulesTests`, `OptionCatalogServiceTests` |
| No duplicates | `oneRecordPerAppointment`, `RecordPendingTests.draftReplacesTheBooking`, contract `deleteDraft` |
| Migration | `TreatmentRecordDecodingTests`, old `NotificationPrefs` and `RecordFieldSetting` decode tests |
| Localization | every new key in 14 localizations, `check-strings --final` green; en-GB overrides for -ise |

## Known limitations
- **Not compiled, not run.** Expect a few compile fixes on the first Mac build; UI tests in particular need a run.
- "Due to return", habits and win-back still read bookings only; a walk-in record updates the client row's last
  visit but not those rules.
- `RecordMark` (Home, Alerts, notifications, client list) reads the clear part only, so it ignores corrections to the
  visit day; the record screens apply them.
- Translations are machine-written (`needs_review`, D41). Old keys no longer used (`treatmentFlow.save`,
  `treatmentFlow.lock.*`, `clientRecord.documents.sharing.counts`) are left in the catalog; prune with
  `merge-strings.py --prune` when convenient.
- Light/dark, Dynamic Type to AX5, VoiceOver and contrast of the new cards use existing tokens and patterns but were
  not measured on a device or simulator; no new color pairs were introduced.
- Older "Finish later" closings (routine-a) still appear in the follow-up queue until resumed; new visits use drafts.
- An open finalized record edited so that it breaks its rules (a needed field cleared, a bad number) is not
  autosaved; leaving the form then keeps the stored version, without asking.
- `Managers/Agenda/AppointmentRecordsReader` uses Screens support types (`AppointmentRecords`,
  `ClientTimelineBuilder`), like the existing `PreVisitReader`: an upward dependency to clean up together.
- A field narrowed to services that are all switched off or deleted is asked at every service again (and the
  template shows it that way); saving its services sheet then drops the missing ids.

## Second review (stages 4–5) applied
Lint: trailing newlines, a 6-parameter function, six type bodies over 250 lines (members moved to same-file
extensions), a committed `__pycache__` (now ignored). Logic: open finalized records keep their rules on autosave,
fields of switched-off services, the previous visit is the last one *before* the appointment, technique chips
select and unselect, "Before you start" shows a result only when one was written, `recordMarks()` reads only the
clear part (no decryption on every change), walk-in clients are not "New", saved-option chips use the list's own
duplicate rule, the consent visit picker lists finalized visits only and keeps an old link visible, the add-option
title wraps instead of being cut in the navigation bar.
