# S6 slice: home (branch s6-home)

## Built
- 2.1 Home (`Screens/Home/`): `HomeView` reads the Services and hands them to `HomeContentView`, which owns
  `HomeViewModel`. Greeting (`DayGreeting`, business time zone), next visit (`HomeNextVisitCard`: "in 1 h 20 min",
  Before you start, Running late, Open), the rest of today (`HomeVisitRow` pushes `AgendaRoute.appointment`),
  "Reminders ready" (`RemindersReadyCard`, shared with Alerts), three insight tiles (left today, open slots → week
  glance, haven't returned → win back), follow-ups card (`HomeFollowUpsCard` → `AgendaRoute.followUps`), win-back
  strip (`HomeWinBackLink` → `AgendaRoute.winBack`), quick actions (new appointment opens
  `AgendaSheet.newAppointment`). The digest is rebuilt every minute by a `TimelineView`. Empty day = `EmptyState`.
- 2.7 Follow-ups (`Screens/FollowUps/`) and 2.8 Win back (`Screens/WinBack/`): the placeholders under
  `Screens/Shared/Agenda/Placeholders/` are deleted. Rows have Message (opens the shared client message sheet) and
  Book (`AgendaSheet.newAppointment(clientID:)`); birthdays of the week with "Send your wishes". Pure lists in
  `Support/` (`FollowUpsList`, `WinBackList`), rules stay `FollowUpPlanner`'s.
- Shared client message sheet (`Screens/Shared/ClientMessage/`): `ClientMessageRequest` (follow-up, win back,
  birthday), `ClientMessageComposer` (pure; uses her own "Come back soon" quick reply, falls back to the built-in
  wording; only first name, service name and booking link can be interpolated), `ClientMessageViewModel`,
  `AgendaSheet.clientMessage(_:)`. Nothing is sent by the app (D14).
- 2.4 Alerts, local part (`Screens/Alerts/`): `AlertsViewModel`, `AlertsContentView`, `AlertCard`,
  `NotificationPermissionNotice` (ask / denied → Settings), `AlertsList` (pure): "Reminders ready" section (D31),
  upcoming visit, birthdays this week, follow-ups due, haven't returned. `AlertKind` gained `nextVisit` and
  `remindersReady`.
- 7.11 shared states (`Screens/Shared/States/`): `ScreenPhase` (loading / empty / failed / content with the
  precedence rule), `ScreenStateView` (skeletons, error with retry, caller-defined empty state), `ListLoadingView`.
  Offline is the existing `OfflineBanner` (S1).
- Digest: `Managers/Agenda/AgendaDigestService` (one vault observation shared by Home, Alerts, Follow-ups and Win
  back; forgets everything on lock/sign-out) and the pure `AgendaDigest` + `AgendaDigestSource`
  (`Screens/Shared/Agenda/Digest/`).
- "Reminders ready" queue: `Models/Agenda/RemindersReady` (pure builder: who and when; the evening-before moment at
  `prefs.reminderTimeMinutes` in the business time zone, DST-safe). `AppointmentService.markReminderSent` records
  that she opened the chat (`Appointment.reminderSentAt`), the row then says "Opened".
- Local notifications (`Managers/Notifications/`): `NotificationScheduling` protocol, `UserNotificationScheduler`
  (UserNotifications), DEBUG `UITestNotificationScheduler`, `NotificationPrefsStoring` +
  `DefaultsNotificationPrefsStore` (reads only; S10 writes), `NotificationService` (watches visits and clients,
  rebuilds the plan after every change, replaces what the phone holds; `permissionMayHaveChanged` on foreground;
  `removeAll` on sign-out). Pure `Models/Notifications/NotificationPlanner` (next visit 15 min before, birthdays
  09:00 the day before, daily summary 08:00, reminders ready the evening before; horizon 14 days, at most 60; quiet
  hours via `QuietHours` with urgent exceptions) and `NotificationTexts` (generic: counts are the only values; a test
  proves no client or service name in any of the 14 localizations).
- Wiring: `AppDependencies` builds `AgendaDigestService`, `NotificationService`, `PermissionService`; `RootView`
  owns them as `@State`, stops both when leaving `.app`, removes all notifications when signed out
  (`RootStage.isSignedOut`); `MainView` starts the notification observation and adds `.agendaDestinations()` to the
  Alerts stack.
- UI-test seed: `Managers/Agenda/HomeUITestSeeding` (`-uiHome`, with `-uiSeed onboarded`): Julia earlier today
  (completed), Camila in 30 min, Ana in 3 h (reminder ready), Beatriz 90 days away (follow-up + win back), Larissa's
  birthday tomorrow. One line added in `UITestSeeding.seedIfRequested`.
- Strings: `Config/Locale/strings/s6-home.json` (14 localizations, merged; `scripts/check-strings.sh` passes).

## Tests
- Unit: `NotificationPlannerTests` (table-driven; quiet hours; no-names test over 14 localizations; clock change in
  Europe/Lisbon, Europe/Madrid, America/Mexico_City, America/Sao_Paulo, America/New_York),
  `NotificationServiceTests`, `RemindersReadyTests`, `AgendaDigestTests`, `AgendaDigestServiceTests`,
  `ListsTests` (FollowUpsList, WinBackList, AlertsList), `HomeViewModelTests`, `ListViewModelsTests`,
  `ClientMessageComposerTests`, `ClientMessageViewModelTests`, `HomeContrastTests`. Fakes:
  `FakeNotificationScheduler`, `FakePermissionStatusProvider`, `FixedNotificationPrefsStore`.
- UI: `HomeUITests` (UISmoke: seeded visits on Home, open one, "Send" on a reminder opens the message sheet),
  `HomeAuditUITests` (skipped by UISmoke via `Config/TestPlans/UISmoke.xctestplan`; Home, Follow-ups, client
  message, Win back, Alerts in `en, pt-BR, de, ar, hi` at default and AX5; `TEST_RUNNER_AUDIT_LOCALES` narrows),
  `Support/XCUIApplication+Home`.

## Assumptions (ASSUMPTION candidates)
- The next-visit lead is 15 minutes, birthdays at 09:00 the day before, the daily summary at 08:00; the planner looks
  14 days ahead and keeps 60 of the 64 system slots. The urgent exceptions to quiet hours (running late, a
  cancellation today) are server events (S8) and use the same `deliveryDate` rule.
- A vault that is not open keeps the old plan on the phone (the old plan still helps her); only a withdrawn
  permission or sign-out clears it.
- `MessageService.recentlyOpened` is in memory only; the persisted trace of a follow-up/win-back/birthday message is
  the `MessageLog` entry with the kind, never the text.
- Follow-ups and win back use her own "Come back soon" quick reply when she rewrote it.
- `HomeView` builds the ViewModel in `body` from the environment because `MainView` constructs it with a plain
  `init()`; `HomeContentView` owns it as `@State` (built once).

## Deviations from the prototype
- Home's quick actions are "New appointment" and "Week at a glance"; "New client" and "Register treatment" are
  reachable from their tabs (Clients, S7 flow) and would need cross-tab navigation the root does not expose yet.
- The Alerts tab shows the local alerts only; booking requests, reschedules, check-ins and forms arrive with S8.

## DESIGN.md additions (for the integrator)
Home (greeting, next-visit card, rest-of-today list, reminders list, insight tiles, follow-ups card, win-back
strip, quick actions), Follow-ups, Win back, Alerts cards and permission notice, the client message sheet, the
shared `ScreenStateView` / `ScreenPhase` / `ListLoadingView`. Screenshots not taken.

## Results
| Check | Result |
|---|---|
| `scripts/test.sh fast` | 1710 tests in 222 suites pass (base had 1416 in 178 before this slice), zero SwiftLint warnings |
| `scripts/test.sh smoke` | 48 UI tests pass, including `HomeUITests` (visits on Home, open one, "Send" opens the message sheet) |
| `HomeAuditUITests` in `en,ar`, default size and AX5 | passes, no clipped text and no missing description (default 162 s, AX5 227 s) |
| `scripts/check-warnings.sh` | zero warnings on simulator, device, Release and the test targets |
| `scripts/check-strings.sh` | passes (1573 keys, 14 localizations) |

Fixes made while finishing: `TreatmentFlowUITests` (S7) tapped "Keep all" while it peeked out under the save bar on the
iPhone 17 Pro Max (this slice's simulator), so the tap landed on the bar; the test now scrolls the button above the
bar. The next-visit dot used the decorative `HeroPalette.glowRose` (2.6:1); it is `Palette.roseDeepText` now.
`NotificationService` keeps the old plan when the vault is not open instead of clearing it.

## Not done
- `DESIGN.md` and `docs/PROGRESS.md` (integrator's).
- The audit in `pt-BR`, `de`, `hi` (default locale list of `HomeAuditUITests`); only `en,ar` were run.
- Dark mode was not looked at on the simulator (tokens carry the dark pairs; contrast pairs are tested).

## State at the checkpoint
Everything is committed on `s6-home` (last commit: the roseDeepText dot). Fast, smoke, warnings, strings and the
`en,ar` audit are green. Ready to merge into `build/v1` (regenerate the catalog, delete nothing else: the two
placeholders are already gone).

## Next commands
```
cd .claude/worktrees/agent-a9c2564560a1e27e2
SIM_UDID=1D7CD4D7-E81E-4320-BCEB-1AD9C6FB6F3D scripts/test.sh fast
SIM_UDID=1D7CD4D7-E81E-4320-BCEB-1AD9C6FB6F3D scripts/test.sh smoke
SIM_UDID=1D7CD4D7-E81E-4320-BCEB-1AD9C6FB6F3D scripts/check-warnings.sh
TEST_RUNNER_AUDIT_LOCALES=en,ar ONLY_TESTING=BelloHubUITests/HomeAuditUITests \
  SIM_UDID=1D7CD4D7-E81E-4320-BCEB-1AD9C6FB6F3D scripts/test.sh full
```
