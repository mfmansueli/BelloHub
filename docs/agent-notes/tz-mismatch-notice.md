# Time-zone notice (tz-mismatch-notice)

Approved by the owner on 2026-10-11. Branch `tz-mismatch-notice`, from `build/v1` at `9f40dc8`.

## Why

The owners are Brazilians living in Italy. Setup picked the business region from the iPhone's Region setting
(Brazil), so the business zone became America/Sao_Paulo while the phone was in Europe/Rome. The calendar follows the
business zone (correct since `fix-reschedule-day`), but she never knew the two differed. Now the app tells her and
offers a one-tap fix. Nothing changes without her tap.

## Decisions

- **Rule (`Models/Business/TimeZoneMismatch`, pure).** Notify when the two zones show another hour *at `now`*
  (difference of `secondsFromGMT(for: now)`), not when the identifiers differ. Two ids with the same offset (Rome and
  Paris, São Paulo and Buenos Aires, the alias Asia/Calcutta and Asia/Kolkata) show every visit at the same hour, so a
  notice would be noise. Zones whose daylight-saving rules differ (Lagos and Rome) are reported only while they
  differ, which is exactly when a visit would read differently. Unknown ids say nothing. The difference keeps minutes
  (Kolkata, Kathmandu, Adelaide, St John's).
- **Keep it** stores the pair (business id, phone id) per user (`DefaultsKey.timeZoneNoticeKept.<userID>`, JSON; in
  `prefixesClearedOnAccountDeletion`). She is asked again only when one of the two ids changes. A DST change alone
  does not ask again.
- **Use my iPhone's time zone** saves the profile with the phone's zone (`ProfileService.saveProfile`), then re-saves
  her stored hours with `AvailabilitySettings.inTimeZone(newZone)`: the same wall-clock hours ("09:00 to 19:00") and
  the same day-off dates, now read in Rome. That is what she means when she works where she is. The hour re-save is
  best effort: every reader already reads the hours in the business zone and the page publishes days off from the zone
  they were stored in, so a failure there changes nothing she sees. Nothing is stored when she never saved hours.
- **Republishing.** No new code path: the profile write is a vault write, which is `PublishingService`'s change signal;
  both payloads carry `profile.timeZoneID`, so both differ and both are published (only if her page is online; she
  decides). `TimeZoneNoticeViewModelTests.publishedPayloadsFollow` checks the payloads: zone Rome, same weekly hours,
  breaks and day-off dates.
- **Visits are instants** and keep their moment. A visit she typed as 10:00 while the business was (wrongly) in São
  Paulo was stored as 10:00 São Paulo, and after the change reads 15:00 Rome. That is correct for anything booked by a
  client from the page (the client chose that instant), and is why the button is never pressed for her.
- **Region note.** When the phone's zone belongs to another region preset (`RegionCatalog.preset(containingTimeZone:)`)
  than her business region, one quiet line says the region and the currency do not change automatically. A zone no
  preset lists (Tokyo) says nothing about the region.
- **Names.** `Formatters.zoneName`: CLDR exemplar city in the interface language ("Rome", "Roma", "Rom", "روما"); zones
  without a city (`Etc/GMT+3`) read as their GMT offset. The difference uses `Formatters.duration`.
- **Where.** Home: a `belloCard()` under the greeting (no `InlineNotice`: it has no actions and its tinted fills were
  never measured against the tertiary ink; on `surface` every pair is already measured). Calendar: a quiet line pinned
  with the header (it first sat at the top of the scroll content, but the day view scrolls to the current hour and hid
  it under the header), opening a native `Menu` with the choices. "Language and region" switches to More and pushes 7.2.
- **Service.** `TimeZoneNoticeService` (Managers/Business), created in `RootView` (`forApp`), started and stopped with
  the unlocked session like the follow-up queue. It reads `TimeZone.current` after `NSTimeZone.resetSystemTimeZone()`,
  at start, when the app becomes active and on `NSSystemTimeZoneDidChange`. Home and Calendar share it, so "Keep it"
  on one hides both.
- **Not during setup.** The notice lives in Home and Calendar only (after setup) and needs her profile.
- **UI tests.** The simulator follows the Mac's zone (Europe/Rome here) and the seeds are in São Paulo, so the notice
  would appear in every UI test. It shows in a UI-test launch only with `-uiTimeZoneNotice` (DEBUG `LaunchOptions`).

## Tests

- Unit (25): `TimeZoneMismatchTests` (same hour, aliases, unknown ids, ahead and behind, half and quarter hours, the
  European fall back 25 Oct 2026 01:00 UTC, the US fall back 1 Nov 2026 06:00 UTC, spring forward with Lagos/Rome,
  kept pair, region note), `FormattersTimeZoneTests`, `TimeZoneNoticeServiceTests` (per-user keep, relaunch, zone
  change notification via `Wait.untilMain`), `TimeZoneNoticeViewModelTests` (show/hide, keep, use phone zone, payloads,
  no stored hours, failed save, fire-and-forget).
- UI: `TimeZoneNoticeUITests` (4, `TZ` set per test): Home names both zones and uses the phone zone (Calendar then
  shows nothing); Keep it hides Home and Calendar; the Calendar row's menu opens Language and region; Buenos Aires
  says nothing. `TimeZoneNoticeAuditUITests` (Full only, skipped in UISmoke): AX5 in en and pt-BR, Home card and
  Calendar row. All pass. Fast plan: 2333 tests pass. `scripts/check-warnings.sh`: zero warnings.
- Seen while checking for regressions: `CalendarUITests.testAMovedVisitShowsOnTheChosenDayWhenThePhoneIsBehindTheBusiness`
  failed at 12:28 São Paulo time: the day scrolls to one hour before now, so the 10:00 seeded visit sits under the
  pinned header and the long press hits the week strip. The notice is off in that test and the header's height is
  unchanged, so this looks time-of-day dependent and pre-existing; it could not be re-run on `build/v1` from this
  session. The "ahead" twin and `HomeUITests` pass.

## Needs a real iPhone

- Travelling across zones with the app open and in the background: iOS changes the zone automatically on landing; check
  the notice appears on return to the foreground and on `NSSystemTimeZoneDidChange` while open.
- Changing the zone in Settings (General > Date & Time, automatic off) while the app is open, then coming back.
- "Use my iPhone's time zone" with the page online: the page shows the new zone and the same hours a few seconds later.
- VoiceOver on the card (one element naming both zones) and on the Calendar menu; Dynamic Type at AX5 in Arabic.

## Strings

`Config/Locale/strings/tz-mismatch-notice.json`: 11 keys (`timeZoneNotice.*`) in all fourteen localizations
(es-419 and en-GB derived), `needs_review` except English.

## Files most likely to conflict with build/v1

`BelloHub/Screens/Main/RootView.swift`, `BelloHub/Screens/Home/HomeContentView.swift`,
`BelloHub/Screens/Calendar/CalendarContentView.swift` (header in the safe-area inset), `BelloHub/SupportFiles/DefaultsKey.swift`,
`BelloHub/SupportFiles/LaunchOptions.swift`, `BelloHub/Models/Locale/RegionCatalog.swift`,
`BelloHub/SupportFiles/Localizable.xcstrings` (regenerate with `scripts/merge-strings.py`), `DESIGN.md`,
`Config/TestPlans/UISmoke.xctestplan`.
