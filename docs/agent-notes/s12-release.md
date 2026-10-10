# S12 · Hardening and release readiness (agent notes)

Single agent on `build/v1`, from `cf9d249` (the merge of `s8-leftovers` after S11), 2026-10-10. Simulator "iPhone 17"
(iOS 26.5, picked by `scripts/`). No subagents, one `xcodebuild` at a time.

## 0. Merged head

`cf9d249` had never been built. On it: fast 2179 tests in 309 suites, `check-warnings.sh` zero warnings,
`test-firebase.sh` green (unit 943, rules 66, use cases 289, transport 19), `test-web.sh full` green. The server
contract changed on the helper's side only, so nothing was regenerated. Deployed to dev: all functions (new
`suggestBookingTime` created) and Hosting; smoke: page 200, `/api/getSlots` answers, `/api/getPublicPage` NOT_FOUND
for an unknown slug. The helper's PROGRESS paragraph is in the stage log ("S8 leftovers + S12 prep").

## 1. Bugs carried from S11

| Bug | Finding | Change |
|---|---|---|
| Calendar: a past hour "jumped to Monday" and did not open New appointment | A probe UI test at 12:xx São Paulo time: a **fully visible** past hour (11:00) opens New appointment. The S11 smoke had tapped the 09:00 row, which the day view's scroll ("an hour before now" at the top) leaves **under the pinned header**; XCUITest still reported it hittable and the tap landed on the week strip, selecting another day. The app was right | `firstTappableSlot` keeps only rows wholly between the header (week strip / Day-Week control) and 75 % of the screen, and prefers a past hour again (booking it only warns). Unit test on the pure rule: `CalendarDayLayoutTests.tapInEveryHourRow` (a tap anywhere in a row gives that hour, past or not) |
| Help and Privacy describe "Export her data" under Edit | Edit had only "Delete data" | 4.3 gets **"Export data"** (peach row, opens 4.10 as a sheet) right above "Delete data"; the Help answer rewritten in 14 localizations to name both rows and what deletion removes; `ClientDataDeletionUITests` walks export then delete |
| "Created by " with no name on the record-history route | `AgendaBusinessContext` was a snapshot taken at load, before the profile arrived on that launch | `RecordHistoryViewModel.professionalName` reads the profile each time (`nameFollowsTheProfile` test) |

## 2. Found in S12 and fixed

- **Apple Calendar promised but never written.** The Integrations switch said "New appointments appear in your
  calendar"; S6 and S10 each left the write-through to the other, and the app had **no
  `NSCalendarsFullAccessUsageDescription`** (iOS ends an app that asks EventKit without it). Built: pure
  `CalendarEventPlanner` (which visits, titles, reconciliation by the visit id stored in the event's URL), the
  `CalendarEventWriting` protocol with `EventKitCalendarWriter` (actor, one commit per pass), `UITestCalendarWriter`
  (DEBUG) and `FakeCalendarEventWriter`; `CalendarIntegrationService` watches the visits (`startListening` /
  `stopListening`, MainView/RootView like notifications), syncs on connect and on return to the app, removes the
  "Bello Hub" calendar on switch-off and sign-out. Titles carry names only while Privacy lets names reach the lock
  screen. Tests: `CalendarEventPlannerTests` (8), `CalendarWriteThroughTests` (6 + arguments). Device check: H19.
- **Usage descriptions**: `InfoPlistUsageTests` checks every permission the code asks for (Face ID, microphone,
  camera, contacts, calendar) in the built plist and in all 14 localizations.
- **"Continue with phone" was a dead end in Release** (`FirebaseAuthProvider` answers `unavailable`). New
  `AuthProvider.supportsPhoneSignIn`; Welcome shows the phone path only where the provider can send a code. Unused
  `UnconfiguredAuthProvider` deleted; docs/06 section 5 updated. Owner decision H20.
- **Launch screen** was the generated system white/black; now `UILaunchScreen.UIColorName = LaunchBackground`, a colour
  set equal to `Palette.bg` (`LaunchScreenTests`).
- **`BookingImporter` had no suite**: `BookingImporterTests` (conflict with a manual visit, requests skipped, clients
  by phone, update in place).
- **Test hygiene**: `bringIntoView` stops once the page cannot scroll (it dragged 24 times, ~40 s per call, on short
  forms); the accessibility walk scrolls back to a client row in pt-BR at AX5.

## 3. S12 scope

- **Accessibility** (`docs/agent-notes/accessibility-audit.md` section 4): clean in en and pt-BR, default and AX5, with
  Increase Contrast and Reduce Motion; in every Full run in `en` since S12 (`Full.xctestplan` environment).
- **Performance** (simulator iPhone 17, iOS 26.5, Debug, in-memory UI-test vault; `PerformanceUITests`):

| Budget (docs/13 section 6) | Result |
|---|---|
| Cold start ≤ 1.5 s | **1.26 s** to Welcome (5 runs, RSD 3.6 %); 1.74 s to Home including the UI-test seeding of a workspace in the launch |
| 2,000 clients: search ≤ 150 ms | **12 ms** per search (signpost `clientSearch`) |
| 2,000 clients: no hitch > 8 ms | deceleration 2.43 s, dragging 0.14 s per fling; the simulator reports no hitch ratio: device run H19 |
| 200 photos ≤ 250 MB | **peak 96 MB**, absolute 90 MB |
| Week 80 visits, photo save, vault 400 KB, mailbox import, voice | not measured on the simulator; device run H19 (voice ships unavailable, D53) |

- **Security**: `security-review.md` section 6, the 8 gaps re-checked on the merged tree: 6 closed, App Check open (H5),
  breach-plan duties open (H18).
- **Privacy manifest**: `scripts/check-privacy.sh` passes (rule 7 included).
- **Info.plist usage strings**: five permissions, all localized (above).
- **Launch screen**: fixed (above). App icon: `BelloHub.icon` (Icon Composer) is in the target.
- **App Store metadata**: 13 storefront files re-measured (name, subtitle ≤ 30; keywords ≤ 100, no spaces after
  commas; promotional ≤ 170; description, what's new and TestFlight notes ≤ 4000): all within limits.
  `docs/store/README.md` gained the TestFlight build notes.

## 4. Final regression

(see `docs/PROGRESS.md`, stage log "S12")
