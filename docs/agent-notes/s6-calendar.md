# s6-calendar: Calendar, WeekGlance, NewAppointment, Reschedule, BlockTime (S6 slice)

Branch `s6-calendar` (based on `build/v1` at 143e649).

## Built
- Time blocks: vault record + `TimeBlockService` (commit 7d8907f).
- Pure rules in `Screens/Calendar/Support/` (warning engine, open times, block planner, day layout, week summary,
  appointment builder) with tests incl. DST (ba949a1).
- Screens: `CalendarView` tab (day timeline + list, week grid + agenda list), `WeekGlanceView`, `NewAppointmentView`,
  `RescheduleView`, `BlockTimeView` (a6a0646). The four placeholders were deleted.
- UI: `CalendarUITests` (book from a free slot, reschedule, see it; seed `-uiCalendar` in `CalendarUITestSeeding`, wired
  by one line in `UITestSeeding.seedIfRequested`), `CalendarAuditUITests` (skipped by UISmoke; `-uiCalendarVisits`
  seeds visits and a block).
- Strings: `Config/Locale/strings/s6-calendar.json` (163 keys, 14 localizations); `check-strings.sh` passes.

## Results
- `scripts/test.sh fast`: passed. `scripts/test.sh smoke`: 20 UI tests, CalendarUITests passes; one failure,
  `BookingSetupUITests.testPoliciesAndQuickReplies` ("noShowPolicy.masterSwitch did not respond"), a test owned by the
  S5 booking slice, not touched here.
- Audit `CalendarAuditUITests` en,ar at default size and AX5: passes (day is now `DayAgendaList` at accessibility
  sizes; text inside timeline blocks is exempt from the clipped-text heuristic, since blocks truncate by design).
- `scripts/check-warnings.sh`: zero warnings (simulator, device, Release, test targets).

## Not done
- `pt-BR`, `de`, `hi` audit locales not run. DESIGN.md additions left to the coordinator.
- Smoke has one failure outside this slice: `BookingSetupUITests.testPoliciesAndQuickReplies`.

## Next commands
    export SIM_UDID=9094A22B-D96D-4AB6-8132-AAC9C1D88AFE
    scripts/check-warnings.sh
    TEST_RUNNER_AUDIT_LOCALES=en,ar ONLY_TESTING=BelloHubUITests/CalendarAuditUITests scripts/test.sh full
