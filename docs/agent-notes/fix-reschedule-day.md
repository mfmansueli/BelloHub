# Fix: rescheduling is one day late

Reported by the owner on a real iPhone (2026-10-11): she moves an appointment to Tuesday and the calendar shows it on
Monday, always exactly one day earlier. Branch `fix-reschedule-day`, from `build/v1` at `52c6198`.

## Root cause, in plain words

The calendar screens decide "which day is this" in one place and "what is this day called" in another, and the two
could use different time zones.

1. **The calendar kept the phone's time zone.** Every calendar screen builds its ViewModel from `CalendarSettings`
   (the business zone from her profile) and keeps it in `@State`, which keeps the ViewModel of the *first* frame. In
   that first frame her profile has often not been read yet (it is read after the vault opens, while the tab view is
   already on screen; seen with a probe: `HomeView` is built twice with no profile before it arrives), so
   `CalendarSettings` falls back to the phone's zone. The ViewModel then cut every day at the phone's midnight for the
   rest of the session, while the labels (date strip, column headers, the spoken day of each visit) were rebuilt with
   the profile and written in the business zone. With the phone ahead of the business (an iPhone in Italy for a
   Brazilian business), the phone's midnight on Tuesday is still Monday evening in São Paulo, so the Tuesday column was
   labelled "Mon": every visit, including the one she had just moved to Tuesday, showed under the day before. Exactly
   one day, whatever the hour, which is what she saw. The UI test reproduced it word for word: "Camila Rocha, Glow
   Facial, Sunday, October 11, 10:00 – 11:00 AM is shown under Saturday, October 10".
2. **Her hours were read in another zone than the calendar's.** Free times, working hours, breaks, days off and the
   "close the whole day" of Block time come from `FreeSlotsCalculator`, which reads her hours in the zone stored with
   them (`AvailabilitySettings.timeZoneID`). That zone is only the zone they were saved in: before her profile is read
   `BookingSetupService` holds a starter in the phone's zone (also after every lock), and nothing ever re-aligned it
   with the profile. Whenever it differed from the calendar's zone, the day chip "Tue" took the start of the day in the
   stored zone, which is Monday when the stored zone is behind: the reschedule sheet offered Monday's times under
   "Tue" and the visit landed on Monday. The server never had this problem: it publishes and reads her hours in the
   profile's zone.

Hypotheses checked and ruled out: no `DatePicker`, `Formatters` or `Calendar` in the calendar derives its zone or
calendar from the interface locale (the language work only sets `\.locale`; `Formatters` always takes the zone
explicitly and is Gregorian); the week strip and the week grid label each day from its own date, so a different first
weekday reorders the week but never shifts a label (now tested for Sunday-first and Monday-first); booking `startsAt`,
web reschedule requests and `BookingImporter` carry ISO-8601 instants and copy them as they are. Note: Portugal is
Sunday-first in CLDR (as `WeekConfigTests` already says), not Monday-first; the tests use Italy for Monday-first.

## The fix

- `CalendarSettings` is `Hashable`, and every screen that builds a ViewModel from it is identified by it
  (`.id(settings)`): Calendar, Home, Week at a glance, New appointment, Reschedule, Block time, Waitlist, Follow-ups,
  Alerts. When her profile arrives (or her week start changes) the ViewModel is built again with the business zone.
  Booking request and Reschedule request were left alone: their ViewModels never kept the settings.
- `AvailabilitySettings.inTimeZone(_:)` (Models/Business, pure): the same wall-clock hours and day-off dates read in
  another zone. The scheduling ViewModels (`CalendarViewModel`, `RescheduleViewModel`, `NewAppointmentViewModel`,
  `BlockTimeViewModel`, `WeekGlanceViewModel`, `AgendaDigestSource`) read `bookingSetup.availability` through it with
  the zone of their own `CalendarDays`, and the pure rules that receive both (`CalendarDayLayout.make`,
  `WeekSummary.make`) do it themselves, so a future caller cannot reintroduce the split. Days off keep their calendar
  dates (they are stored as the start of the day in the zone they were saved in, and the server reads them that way).
- Her own week start: `CalendarSettings`, More, Booking settings and Availability ignored the week start she chose in
  Language and region and used the region's. One owner now, `WeekConfig.effective` (used by `LanguageRegionRules` and
  `ProfessionalProfile.weekConfig`).
- "Suggest another time": the starting point is a calendar day later in the business zone (it was 24 hours later, an
  hour off on a daylight-saving day), and the graphical picker gets a calendar in the business zone besides `\.timeZone`.
- UI-test hook: `-uiTab <tab>` (DEBUG, `LaunchOptions.initialTab`) opens the app on a tab, built in the first frame as
  after an unlock. The phone's zone is set per test with the `TZ` environment variable
  (`launchedForUITests(environment:)`), which moves the whole process, `DatePicker`s included; no app hook was needed.

## Screens that had the same defect

Calendar (day strip, day view, week grid, week list), Home (today, next visit, the week), Week at a glance, New
appointment (free times and hours warnings), Reschedule (day chips, times, warnings), Block time (whole day and hours),
Waitlist, Follow-ups and Alerts (built on the frozen zone), and the digest behind Home and Alerts. Appointment detail
(`AgendaBusinessContext`) re-reads the profile on load and was not affected. Booking request approval and web
reschedule requests carry instants and were not affected; the suggest sheet had the DST hour issue above.

## Tests

Failing before the fix (commit `90c0070`), passing after:

- `ZoneMismatch` fixture (CalendarTestFactories): five cases, stored zone behind and ahead of the business zone, and
  two daylight-saving days of the business zone (Lisbon 25 October, New York 1 November).
- `RescheduleViewModelTests.businessZone` (every offered chip holds its own day's times; the chosen day's times are
  09:00 to 17:00 of that day; no hours warning; the moved visit lands on the chosen day), and the same rule in
  `NewAppointmentViewModelTests`, `CalendarViewModelTests` (working window of the day), `BlockTimeViewModelTests`
  (the closed day is that day), `WeekSummaryTests` (suggestions and capacity).
- `CalendarSettingsTests` (business zone, region and own week start, the fallback is another value, labels follow the
  data for Sunday-first and Monday-first) and `AvailabilitySettingsZoneTests` (hours and day-off dates kept).
- `BookingRequestSuggestionTests.dayLaterInBusinessZone`.
- `CalendarUITests.testAMovedVisitShowsOnTheChosenDayWhenThePhoneIsAheadOfTheBusiness` (`TZ=Asia/Tokyo`, failed
  before the fix with the exact symptom) and `...WhenThePhoneIsBehindTheBusiness` (`TZ=Pacific/Honolulu`): the
  calendar opens first, every visit is under its own day, a visit moved to the third offered day is found under that
  day's label.

## Files most likely to conflict with build/v1

`BelloHub/Screens/Main/RootView.swift` (navigation init), `BelloHub/SupportFiles/LaunchOptions.swift`,
`BelloHub/Screens/Home/HomeView.swift`, `BelloHub/Screens/More/MoreView.swift`,
`BelloHub/Screens/BookingSettings/BookingSettingsViewModel.swift`, the Calendar screens and ViewModels listed above,
`BelloHubUITests/Support/XCUIApplication+Launch.swift`, `BelloHubTests/Screens/Calendar/CalendarTestFactories.swift`.

## Strings

None added.

## Open

- `BookingSetupService` still starts (and restarts after a lock) with a starter in the phone's zone, and the
  Availability screen keeps the zone she first saved her hours in. Harmless now that every reader re-reads them in the
  business zone, but the stored zone could be aligned with the profile on the next save if a later task wants it.
