# S6 slice: appointment (branch s6-appointment)

## Built
3.2 Appointment (pushed, `AgendaRoute.appointment`), 3.3 BeforeYouStart, 3.5 CancelAppointment, 3.6 MessageClient,
3.7 NoShowMark, 2.12 RunningLate (sheets), 4.8 SessionPlan, 4.11 NoShowHistory (pushed), all under
`BelloHub/Screens/Appointments/`. Messaging: `Managers/Messaging/` (`MessageSending` protocol, `SystemMessageSender`,
DEBUG `UITestMessageSender`, `MessageService`), pure URL building and dispatch plan in `Models/Messages/`.
Strings: `Config/Locale/strings/s6-appointment.json` (164 keys, merged; `scripts/check-strings.sh` passes).

## Fixes made when resuming
- `.accessibilityIdentifier("<screen>.form")` sat after `.safeAreaInset`, so it overrode the buttons' identifiers;
  moved before it in the five sheets.
- `AppDependencies.makeLive` used `UITestMessageSender` (DEBUG only; Release did not build and the live app would never
  have opened WhatsApp); live now uses the default `SystemMessageSender`, the UI-test dependencies use the fake.
- Test warnings (large tuple, import order, unnecessary try).

## Tests
Fast: 1416 tests in 178 suites pass (new: MessageService, MessageLinks, dispatch plan, action rules, cancel notice,
no-show projection/history/count message, NoShowMarkViewModel, AppointmentContrastTests).
Smoke: 23 UI tests pass, including `AppointmentUITests` (open and cancel; mark a missed visit as no-show) via
`-uiSeed appointments -uiRoute appointments`. `AppointmentAuditUITests` is skipped by UISmoke; run in `en,ar`
(default size and AX5): passes. `scripts/check-warnings.sh`: zero warnings (sim, device, Release, tests).

## ASSUMPTION candidates
- The seeded UI route is a DEBUG list (`AppointmentDebugRoute`) because the Calendar tab (another slice) does not open visits yet.
- Cancel and no-show notes are logged as `MessageLog` without the message text.

## Not done
- ViewModel tests exist only for NoShowMark; Cancel, Message, RunningLate, SessionPlan, NoShowHistory VMs lack fake-based tests.
- Audit does not walk the no-show mark, session plan and no-show history screens, nor `pt-BR`, `de`, `hi`.
- `DESIGN.md` and `docs/PROGRESS.md` not updated (owner of those is the integrator); DESIGN.md additions needed:
  visit detail, five sheets, session plan, no-show history, `NoShowCountCard`, `VisitStateView`.

## State at the checkpoint
All committed on `s6-appointment`; Fast, Smoke, warnings, strings and the en/ar audit green.

## Next commands
`SIM_UDID=1D7CD4D7-E81E-4320-BCEB-1AD9C6FB6F3D scripts/test.sh full` (audit in all five locales).
