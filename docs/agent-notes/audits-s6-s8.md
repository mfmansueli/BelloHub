# audits-s6-s8: closing the accessibility/localization audits of S6 to S8

Branch `audits-s6-s8`, worktree `.claude/worktrees/agent-ac201191ad6320d8b`, based on `build/v1` at f77bb91.
Simulator `1D7CD4D7-E81E-4320-BCEB-1AD9C6FB6F3D` (iPhone 17 Pro Max).

## Why the test plans could not start on build/v1

Two gates in `scripts/test.sh` failed on `build/v1` before any simulator test ran:

- `check-strings.sh`: the "saving progress" commit f77bb91 carried an Xcode auto-extraction (SWIFT_EMIT_LOC_STRINGS)
  of 23 `defaultValue:` literals ("Ana", "Aftercare", "%@ does not ask for a patch test.", ...) and `CFBundleName`
  into the catalogs, with no translations. `scripts/merge-strings.py` now drops every non-`manual` entry from
  `Localizable.xcstrings` and `InfoPlist.xcstrings` before merging the batches (every authored key is `manual`), so
  the catalog was regenerated with the documented command, never edited by hand.
- `check-server-contract.sh`: the backend dropped the consent texts from `publishProfile` (D55, 155bed0) but the copy
  in `BelloHubTests/Resources/ServerContract/schemas.json` still had them. Refreshed with
  `scripts/sync-server-contract.sh`.

## Audit results (slice x locale)

The slice agent stopped before filling this section; the runs were finished in S11 (2026-10-10, `build/v1`,
see `docs/agent-notes/s11-localization.md` section 2). Every audit suite (Account, Appointment, BookingSetup,
Calendar, Clients, Health, Home, Import, Inbox, More, Onboarding, Record, Services, TreatmentFlow) ran in its default
localizations `en`, `pt-BR`, `de`, `ar`, `hi`, at the default size and at AX5, in one Full-plan run
(`ONLY_TESTING` takes a comma-separated list now). 26 of 38 tests passed at once; the 12 that failed were fixed
(below) and passed on the rerun.

## Fixes

Product: recovery-key words in two columns (three cut "mountain"); readable accessibility label for the booking
link (title + address); the treatment flow's bottom bar keeps its height (the German camera button was cut at AX5).
German save button without the genitive placeholder ("Im Verlauf von %@ speichern"). Tests: a row taller than the
screen (German at AX5) is flipped through its inner switch; a switch is scrolled above a pinned confirm button; the
credentials preview button is brought clear of the floating tab bar; retries for the permissions Continue tap and the
add-break search after a sheet; unlabeled zero-size elements are off screen in the booking-setup and health audits.

## New tests

`BelloHubTests/Screens/Appointments/`: `AppointmentTestStore` (the in-memory vault and the real services with
`FakeMessageSender` and `FakeHealthFormCatalogProvider` at the boundary, one saved client, `save(hoursFromNow:)` for
visits) and 38 tests in seven suites: `AppointmentViewModelTests` (5), `BeforeYouStartViewModelTests` (4),
`CancelAppointmentViewModelTests` (5), `MessageClientViewModelTests` (6), `RunningLateViewModelTests` (5),
`SessionPlanViewModelTests` (7), `NoShowHistoryViewModelTests` (6). Fast plan: 1926 tests in 255 suites (was 1888).

## Not done

Nothing from the audit scope.

## Exit checks

See the S11 stage log in `docs/PROGRESS.md`.
