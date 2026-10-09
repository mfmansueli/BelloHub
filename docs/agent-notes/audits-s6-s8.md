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

RESULTS_TABLE

## Fixes

FIXES

## New tests

`BelloHubTests/Screens/Appointments/`: `AppointmentTestStore` (the in-memory vault and the real services with
`FakeMessageSender` and `FakeHealthFormCatalogProvider` at the boundary, one saved client, `save(hoursFromNow:)` for
visits) and 38 tests in seven suites: `AppointmentViewModelTests` (5), `BeforeYouStartViewModelTests` (4),
`CancelAppointmentViewModelTests` (5), `MessageClientViewModelTests` (6), `RunningLateViewModelTests` (5),
`SessionPlanViewModelTests` (7), `NoShowHistoryViewModelTests` (6). Fast plan: 1926 tests in 255 suites (was 1888).

## Not done

NOT_DONE

## Exit checks

EXIT_CHECKS
