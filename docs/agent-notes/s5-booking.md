# s5-booking: Availability, booking page, share link, policies, quick replies (S5 slice "booking setup")

Branch worktree based on `build/v1` at 78a7317 ("Add the S5 contract"). Screens 6.5 Availability, 6.7 BookingSettings (with
the pause flow and a return date), 6.8 ShareLink, 6.9 QuickReplies, 6.15 NoShowPolicy, 6.16 CancelPolicy. Everything written
in English; strings in 14 localizations (`Config/Locale/strings/s5-booking.json`, 262 keys).

## What was built (paths under `BelloHub/` unless noted)

### Models (pure)
- `Models/Booking/`: `BookingSetup` (page switches + both policies + chosen slug, singleton), `BookingSlug` + `SlugIssue`
  (the server's `SlugSchema` rules, generation from a name with diacritics and non-Latin scripts, suggestions, typing
  clean-up), `BookingLink` (base URL + slug), `BookingPause` + `BookingPageState` (pause with a return date, expiry,
  normalisation), `SlugAvailability`.
- `Models/Policy/PolicyRuleText`: **the one owner of the client-facing rule text** (cancel, reschedule, grace, no-show, paused
  notice) in any of the 14 localizations. The professional's name is a `{professional}` placeholder in the catalog (not an
  argument), so plural forms depend only on the number and the web can publish the very same strings.
- `Models/Messages/`: `QuickReply`, `BuiltInQuickReply` (six defaults with fixed ids, titles and texts in the catalog),
  `QuickReplyVariable` (`{name} {service} {date} {time} {link}`), `QuickReplyValues`, `QuickReplyRenderer` (locale-aware
  through `Formatters`, bidi isolates in Arabic, unknown words and missing values left as written).
- `Models/Business/`: `AvailabilityDocument` (singleton wrapper so availability can live in the vault),
  `AvailabilitySettings+Starter` (Mon to Fri 09:00 to 18:00, a suggestion), `DayOffKind+Name`.
- `Models/Locale/Formatters+Availability`: times of day from minutes, time ranges, weekday names, day ranges, "24 h".

### Persistence
- `Managers/Persistence/BookingSetupRepository` (filled), `SwiftDataClientRecordRepository+BookingSetup`,
  `InMemoryClientRecordRepository+BookingSetup` (state in one `BookingSetupMemory` struct so the actor's main file only got one
  stored property; `clock` there lost its `private`), `Mapping/VaultStorable+BookingSetup` (none of it is sensitive).
- `Managers/Booking/`: `BookingSetupService` (the shared state: availability, setup, quick replies; published values change
  only after the vault confirms; writes are queued; `clear()` on lock and sign-out), `BookingRepository` (protocol, only the
  address check for now), `OfflineBookingRepository` (throws `notPublishedYet`, no networking), `QRCodeRenderer` (CoreImage),
  `Managers/Clipboard/` (`ClipboardWriting`, `SystemClipboard`).
- Wiring: `AppDependencies` + `RootView` create and inject `BookingSetupService` (3 lines each) and clear it when the stage leaves
  `.app`.

### Screens (each replaces its placeholder of the same name; the three placeholders are deleted)
- `Screens/Availability/`: `AvailabilityView` (reads the environment) -> `AvailabilityContentView` (native `List`), VM,
  `Sheets/{DayHoursSheet,BreakSheet,DayOffSheet}`, `Rows/{WeekdayRow,TimeOfDayRow}`, `Support/{AvailabilityEditor (all rules),
  AvailabilityText, AvailabilitySummary, StretchDraft, AvailabilityIssue, AvailabilityEditorMode}`.
- `Screens/BookingSettings/`: `BookingSettingsView` -> `BookingSettingsContentView`, VM, `Cards/{BookingLinkCard,
  BookingRulesSection, ChipChoice, MenuPickerRow, CopyTextCard, SettingsSection}`, `Sheets/PauseSheet`,
  `Support/{BookingSetupEditor, BookingSetupSummary}`; sub-screens `ShareLink/`, `CancelPolicy/`, `NoShowPolicy/`.
- `Screens/QuickReplies/`: `QuickRepliesView` -> `QuickRepliesContentView`, VM, `Sheets/QuickReplyEditorSheet`,
  `Rows/QuickReplyRow`, `Support/{QuickReplyRules, QuickReplyIssue, QuickReplyEditorMode}`.
- `Screens/More/MoreView`: the booking page and availability rows got subtitles ("Taking bookings" / "Paused until Oct 20",
  "Mon to Sat · 9:00 AM – 7:00 PM"); `MoreView` loads the service in `.task`. Previews of `MoreTab` and `MainView` got the
  new environment object.
- Design system, additive: `AddRowLabel`, `LocalizedStringResource.resolved(in:)`.

## Tests
- `scripts/test.sh fast`: **TEST_FAST_RESULT**
- `scripts/test.sh smoke`: **TEST_SMOKE_RESULT**
- 233 new test functions (parameterized ones run once per case). Pure: `BookingSlug`, `BookingPause`, `BookingLink`,
  `PolicyRuleText` (exact English plus all 14 localizations: whole sentences, the number and the name present, no placeholder or
  key left, every language differs from English, derived locales follow their parents, plural forms), `QuickReplyRenderer`,
  `BuiltInQuickReply` (every default in every localization with the same braces as English), `QuickReplyRules`,
  `AvailabilityEditor`, `AvailabilityText`, `Formatters+Availability`, `ShareTexts` (14 localizations), `QRCodeRenderer` (reads
  the code back with `CIDetector`), contrast (`BookingSetupContrastTests`, 4 appearances). Free slots from the editor's output:
  `AvailabilityFreeSlotsTests` (breaks, buffer, vacations over a year boundary, split days on the change days of Lisbon,
  Madrid and New York, lunch on a change day); `FreeSlotsCalculatorTests` already covered the calculator itself.
  Services and ViewModels with fakes: `BookingSetupService` (queueing, failures), `BookingSetupEditor`, the cancel and no-show
  VMs, `BookingSettingsViewModel` (pause flow), `ShareLinkViewModel`, `QuickRepliesViewModel`, `AvailabilityViewModel`.
  Contract on both vaults: `RepositoryBookingSetupContractTests`.
- UI: `BookingSetupUITests` (two flows in UISmoke: hours with a break -> pause with a return date -> share link with its QR
  code; policies and a quick reply), `BookingSetupAuditUITests` (skipped by UISmoke, in the Full plan).
- Audit: **AUDIT_RESULT**

## Assumptions (ASSUMPTION candidates)
1. **A professional who never opened Availability still has hours.** Until something is saved the screen shows a starting week
   (Monday to Friday, 09:00 to 18:00) with a notice that says so, and nothing is stored; the first change stores the whole week
   (also a change of the buffer, notice or window made from the booking page). The alternative, an empty week, would mean nobody
   can book her by default.
2. **The slug is a local preference until S8.** `BookingSetup.slug` is her chosen address; the server decides ownership when she
   goes online, so a saved address can still be refused then. The offline repository says "once you go online", never an error.
3. **A saved policy applies to bookings made afterwards.** The prototype footer says edits apply to existing bookings too;
   `CancellationEvaluator` documents the opposite (a snapshot stored with each booking) and CLAUDE.md says the document wins, so
   the footer reads "Bookings already made keep the rules they were made under". Needs the owner's confirmation.
4. **No-show counting period options are 3, 6 and 12 months** (the model's `NoShowPolicy.countingMonthOptions`); the prototype
   shows 6, 12 and "Always". `Always` would need a new case in the model.
5. **Rule text is in the business language and names the professional by her first name** ("Maria is told right away"), with a
   gender-neutral wording; the personal-link line follows D31 (confirmation page and email, not an automatic WhatsApp).
6. **Quick replies are written in the business language the first time the screen opens** (six defaults, fixed ids so two
   devices agree), then they are hers. Built-in replies cannot be deleted (only edited, and put back); her own can.
   Words in curly braces are added at the end of the text (no cursor insertion).
7. **A pause with a return date ends on the morning of that date in the business time zone**; a return date today or earlier is
   dropped; an expired pause is shown (and saved the next time) as open.
8. **Days off added from Availability do not touch booked visits** (the sheet says so). The calendar's "Block days" with the
   cancel-or-invite choice (6.6 BlockTime) is S6.
9. **The link base is `https://bellohub.app`** (`BookingLink.defaultBaseURL`) until `BELLO_WEB_BASE_URL` exists as configuration
   (no `AppConfig` yet); it is injectable.
10. **Prices stay per service**: the prototype's "Price visibility" row on the booking page is not here, because `priceDisplay`
    lives on each service (the services slice).

## Deviations from the prototype
- Omitted on purpose (their stages or owners do not exist yet): "Preview" (the web page, S9), the WhatsApp message preview card
  and the "Profile" section (business name, specialties; the profile has no editor before S10), the WhatsApp auto-reply switch
  (needs WhatsApp Business, D31: the screen offers the greeting text to copy instead), "See the message" and "See it as a client"
  on the cancellation screen (reminder templates are S6, the web preview is S9), the "Friendly note after the 2nd one" row
  and its switch on the no-show screen (not in the model; S6 NoShowMark), "Always" counting period (see assumption 4).
- Weekday rows are a switch plus a tap target for the hours (a sheet), because a day may have several stretches (the model allows
  it); the prototype has one range per day.
- Policy and booking screens are scroll views with cards and chips (as drawn); Availability and Quick replies are native lists.
- "Block days" became "Add days off" with its own sheet (kind, first and last day), see assumption 8.

## Design additions (for DESIGN.md)
| Screen | Addition | Why |
|---|---|---|
| 6.5 Availability | "Starting hours" notice while nothing is saved | assumption 1 |
| 6.5 Availability | Hours sheet (several stretches per day), break sheet, days-off sheet with kind | the model allows several stretches; no BlockTime before S6 |
| 6.5 Availability | Empty states for breaks and days off | every list defines its empty state |
| 6.7 BookingSettings | Pause sheet with an optional return date; paused rows: return date picker, "No return date", "Open bookings again" | D15 |
| 6.7 BookingSettings | Link card says "Ready once you go online"; "Choose your address" before a slug exists | no server before S8 |
| 6.8 ShareLink | Address field with live rules, suggestions and a status line; "Not online yet" notice; table card shared as an image | slug flow, honest offline state |
| 6.9 QuickReplies | "New reply", reset to the original, delete (own replies), "Not filled in" warning, preview with an example client | editing needs them |
| 6.16 CancelPolicy | Footer says existing bookings keep their rules | assumption 3 |
| 2.5 More | Subtitles under Booking page and Availability | S5 contract |

## Findings
- iOS 26 puts a narrow no-break space (U+202F) before AM/PM: tests that compare a 12-hour time normalise it.
- `Date.IntervalFormatStyle` gives locale-correct time ranges ("9:00 AM – 7:00 PM", "09:00–19:00") with no strings to translate.
- A `Regex` literal in a `static let` is not Sendable in Swift 6 (computed property instead).
- A `NavigationLink(value: MoreRoute.quickReplies)` inside the booking screens works because they are pushed on the More stack;
  the policy screens are pushed with a closure destination (they need the shared editor), so cancel and no-show can push each
  other repeatedly (like the prototype); no cycle detection.
- Arabic "one" and "two" plural forms the translators wrote have no `%lld` (as the existing `formTemplates.months`): the check
  script accepts it.

## Open questions
- Assumption 3 (existing bookings keep their rules or follow edits): owner.
- Should "Always" return as a counting period (needs a model case and the server's `countingMonths` enum)?
- Is the client-facing wording acceptable as published text per locale (needs_review like the rest)?
- Clients are called "clients" on these screens in every language; should they follow `clientTerm` (patient, student, guest)?

## Integration hints
1. Files shared with the other slice that this branch touched: `RootView`, `AppDependencies` (3 lines each), `MoreView`
   (`businessSection` rows of Booking page and Availability, `messagesSection` unchanged, a `.task`, two helpers), the previews
   of `MoreTab` and `MainView`, `InMemoryClientRecordRepository.swift` (one property, `clock` no longer private),
   `UISmoke.xctestplan` (one line), `LocalizedStringResource+Locale.swift` (one method).
   **Not touched**: `MoreTab.destination(for:)` (the three screens keep `init()`; each reads the environment through a thin host
   view), `CatalogRepository`, the other placeholders, `PROGRESS.md`, `DESIGN.md`.
2. After merging, regenerate the catalog: `python3 scripts/merge-strings.py`, then `scripts/check-strings.sh`.
3. `BookingSetupService` is environment-injected from `RootView`; the S6 calendar reads `availability`, `setup.cancellation` and
   `setup.noShow` from it and `FreeSlotsCalculator` takes `service.availability` as is. `BookingPause.state(of:now:timeZone:)`
   is what S8's publisher should use for the paused flag.
4. S8: implement `BookingRepository` for real behind the same protocol (publish profile and availability, claim the slug) and
   publish `PolicyRuleText.lines` and `pausedNotice` for every localization the professional offers.
5. S6 BlockTime should replace the "Add days off" sheet's role for blocking days with booked visits (cancel or invite).
