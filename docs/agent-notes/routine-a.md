# routine-a: simpler routine, agent A (items 1, 2, 3, 4, 5, 6, 7, 8, 12)

Single agent on `build/v1` (main checkout), from `4f18c47`. Task text: `docs/tasks/routine-simplification.md`. Agent B
works on `routine-b` (items 9, 10, 11, marketing phrases); this note never touches B's areas.

## Map and proposal (written before the first code change)

### Item 1. Language applied only in part

**What exists.**
- Two language ideas live in the app, and only one of them can be chosen inside it:
  - The **interface language** is whatever iOS picks for the bundle (`Bundle.main.preferredLocalizations`, from the
    iPhone language or the iOS per-app language). docs/07 2.2 planned an "Open language settings" row; it was never
    built, so there is no way to choose it in the app.
  - The **business localization** (`ProfessionalProfile.appLocaleID`, `AppLocalization`) is chosen in onboarding
    (from the phone) and in Language and region (7.2, `LanguageRegionContentView`, a menu labelled just
    "Language"). It is meant for client messages, the booking page and templates.
- Views resolve text three ways: `Text("key")` / `Text(LocalizedStringResource)` (resolved with `\.locale`);
  `LocalizedStringResource(...).localized(in: locale)` with `@Environment(\.locale)` (about 470 call sites); and
  `String(localized: "key", ...)` (about 150 call sites in views, ViewModels and Managers). `\.locale` is never set at the
  root, so it is `Locale.current`.
- Lock screen `Screens/Locked/LockedView.swift`, app-switcher cover `Screens/Main/PrivacyCover.swift`: plain `Text("key")`.

**Measured (probe test in the simulator, removed afterwards).**
- `Text("key")` and `Text(LocalizedStringResource)` follow `.environment(\.locale, …)` at run time (rendered widths
  matched the pt-PT and de texts).
- `LocalizedStringResource` with `locale` set picks the right localization (`pt_PT` → pt-PT, `pt_US` → pt-BR, `es_AR`
  → es-419 text, `fr_CA` → fr).
- `String(localized: "key")` ignores both `\.locale` and its own `locale:` argument (that argument only formats
  interpolations), and it does not go through `Bundle.localizedString(forKey:value:table:)` (an overridden bundle
  changed `NSLocalizedString` but not `String(localized:)`). It always answers in the launch language.

**Root causes of the partial language.**
1. *No in-app interface language.* The only "Language" picker in the app is the business one. Choosing Português
   there on an iPhone set to English changes what reads the profile (below) and leaves everything else in English.
2. *Interface text resolved with the business language.* `NotificationService` builds local notification texts in
   `appLocaleID`; `TreatmentFlowViewModel.buildFields` and `RecordTemplateView` name record fields from the
   business-language profession catalog; More and Account show the profession in it. These are read by her, so they
   must follow the interface language.
3. *Two sources for one language.* `\.locale` defaults to `Locale.current` (language + **region**), the bundle picks
   by **language**. Portuguese (Brasil) on an iPhone with the region Portugal gives `pt_PT`: every
   `.localized(in: locale)` string came out in pt-PT while `String(localized:)` and InfoPlist texts were pt-BR. An
   unsupported iPhone language (Japanese) gave English text with Japanese dates.
4. *Strings resolved outside the view tree before or regardless of the switch.* `String(localized:)` in ViewModels and
   Managers (error messages, the Face ID reason, notification texts, export labels), `String(localized: …, locale:)`
   in views (the `locale:` argument does not choose the language), and `resolve: { String(localized: $0) }`
   closures (Incident, Export). They can only ever be in the launch language.
5. *Device-wide language sent to the server.* `PushService` registers `Locale.preferredLanguages` (the iPhone's list,
   not the app's) as the language of server-sent pushes.
6. *System-drawn parts* (permission dialogs from `InfoPlist.xcstrings`, the Face ID sheet, share sheet, photo and
   contact pickers) follow the bundle language of the process; nothing tells iOS about an in-app choice.
- Not found: missing keys (the S11 gate keeps all 14 complete) or English literals in `Screens/` (the existing
  `HARD_CODED_TEXT` gate). Preview-only English literals exist and stay (DEBUG previews).

**Proposal (one structural fix for all 14 localizations).**
- `InterfaceLanguage` (Models/Locale, pure): `.system` or `.fixed(AppLocalization)`, how it resolves to one
  `AppLocalization` and one `Locale` (language from the localization; region from the localization when it carries
  the variant: pt-BR, pt-PT, es-MX, es-419, es → ES, en → US, en-GB; the iPhone's region for the others), and the
  reconciliation with an iOS per-app language set in Settings. Unit tests for every localization.
- `InterfaceLanguageService` (Managers/Locale, `@MainActor @Observable`), created in `RootView`, stored in
  `DefaultsKey.interfaceLanguage` (device setting, outside the vault, so it is known before unlock: lock screen,
  welcome, sign-in). On change it also writes the app's `AppleLanguages`, so the next launch, InfoPlist permission
  texts and system-drawn parts are in that language from the first frame; "Same as iPhone" removes it.
- `RootView` injects `.environment(\.locale, …)` and the layout direction **above** every stage, the privacy cover and
  the lock screen; sheets, alerts, confirmation dialogs, menus and full-screen covers inherit it.
- Code outside the view tree resolves through `String(interface:)` (`LocalizedStringResource` + the current interface
  locale, held thread-safely by `InterfaceLocale`). Every `String(localized: "key" …)` call becomes either that or
  `.resolved(in: locale)` in views.
- Notification texts, record field names, profession names and the push registration use the interface
  localization; client messages, the booking page and templates keep the business localization (unchanged).
- Language and region (7.2) gets a first section "App language" (Same as iPhone + the 14, each in its own name) and the
  old picker is renamed "Language of your messages and page". User-written content (names, services, notes, quick
  replies she edited) is never translated. Interface language is not the region, the time zone or the voice language.
- Gate: `LocalizationSourceScanTests` (unit) reads the Swift sources and fails on `String(localized:` with a literal
  key, `String(localized: …, locale:)`, `Locale.current`/`Locale.preferredLanguages` used for text, and `Text("...")`
  with a sentence, with an explicit allow-list.
- UI test `InterfaceLanguageUITests`: switch the language while a screen is open (pt-BR, pt-PT, de), lock and unlock,
  relaunch; strings asserted against the catalog values.

### Item 2. Logo on the lock screen

**What exists.** `LockedView` (1.11) and `PrivacyCover` draw `BrandMark` (`DesignSystem/Components/BrandMark.swift`):
a rounded square in `Palette.brandMark` with the letter "b" typed in DM Sans bold and an orange dot (`Palette.rose`,
`#FF5A1F` since the graphite and orange palette). The official icon `SupportFiles/BelloHub.icon` is different: a
custom "b" silhouette (`B-Ivory.svg`, `#FAF5EB`) with two curved rose edges (`B-Rose.svg`, `#C98F9F`) on sage
`#6E8266` (dark `#344B3C`), viewBox 1254. `BrandLockup` reuses `BrandMark`. So every in-app logo is a provisional mark.

**Proposal.** Redraw `BrandMark` from the icon's own SVG paths as SwiftUI `Shape`s (same geometry, same viewBox, same
colors in `BrandPalette` tokens, the icon's dark tile in dark mode), corner radius of the system icon mask. No
redesign, no image asset. `LockedView`, `PrivacyCover`, Welcome and `BrandLockup` pick it up. Size on the lock screen
stays 64 pt (checked at AX5); contrast of the "b" on the tile measured in light, dark and Increase Contrast by a test.
Face ID logic and the system dialog untouched.

### Item 3. Onboarding

**What exists** (`Screens/Onboarding/`, `OnboardingStep`): About you (name, business, region) → Profession → Services
(catalog suggestions, custom service sheet) → Terminology → Tags → Record (fields and intake) → Permissions (1.9: four
system prompts in a row: microphone, notifications, camera, contacts) → Ready (import shortcut). One ViewModel, the
draft lives in memory: a relaunch restarts it. Camera is already asked at the moment of use (`CameraStepView`),
contacts use the system picker (no prompt), notifications are also offered in Alerts and Notification settings.

**Proposal.** Steps: About you (name, optional business, region) → Profession → First service (the profession's
default service pre-selected with its duration and a price placeholder in the region's currency; other suggestions one
tap away) → Ready. Terminology, tags and record fields take the profession's defaults (as the catalog already
preselects them) and are reachable in More (Tags, Record template, Language and region → words); Ready says where in
one quiet line. The permission step goes away (the usage descriptions stay); notifications are offered on Home once
she has a visit coming. The draft and the step are saved per user in `UserDefaults` (`DefaultsKey.onboardingDraft`)
and restored on relaunch; cleared at the end. Existing accounts are untouched (setup only runs for a user without
`setupCompletedUserID`).

### Item 4. Home

**What exists** (`HomeContentView`, data from `AgendaDigest` shared with Alerts, Follow-ups and Win back): greeting,
next visit hero card, rest of today, "Reminders ready" list, three tiles (left today, open slots, not returned), a
follow-ups preview card, a win-back link, quick actions (New appointment, Week at a glance) at the bottom. "New
appointment" is only reachable after every card, and "left today", "not returned" and the win-back link repeat each
other.

**Proposal.** Order: greeting and date; **"New appointment" in the navigation bar** (always visible); next visit;
"Today" pending items (reminders to send today, visits to finish closing, booking requests waiting, the notification
offer) each with its action; the rest of today's agenda; then one secondary card "To reach out" (count and the first
reasons) that opens the unified queue, and one "Week at a glance" row. Tiles and the bottom quick actions go away
(their destinations stay reachable from the card and the row). Empty day: the empty state with its own primary, then
pending and the queue card; full day: agenda first.

### Item 5. Follow-up queue

**What exists.** Four separate presentations: "Reminders ready" (`RemindersReady`, Home and Alerts), Follow-ups 2.7
(`FollowUpPlanner.dueFollowUps` by service interval, plus birthdays), Win back 2.8 (`FollowUpPlanner.winBack`, 60+
days) and their counts in Alerts. A client due for a return for 60+ days appears in both lists. "Opened" marks live in
memory only (`MessageService.recentlyOpened`); the persisted `MessageLog` is never read back. Booking requests,
reschedules and the waitlist are in Alerts ("Requests").

**Proposal.** One pure `FollowUpQueue` (Screens/FollowUps/Support) builds items of five kinds from the digest: visit
reminder, post-visit check-in (completed visit yesterday or today), return due, not back (win back), unfinished visit
closing (item 7) and birthday; each with reason (item 12), due date and next action; grouped into one row per client
(every reason kept, the most urgent action first). Filters: All, Reminders, Returns, Not back, Visits (the old
screens become filters of the one queue; the routes stay). Snooze (one week) and dismiss for suggestions (returns, not
back, check-ins, birthdays) in a local per-user `FollowUpQueueStore` keyed by occurrence (a new visit brings a new
occurrence back); reminders and unfinished closings cannot be dismissed. Booking requests stay in their own
"Requests" section in Alerts and appear in the queue and on Home only as a separate, labelled link ("Booking requests
need your decision"). Alerts shows one "To reach out" card instead of the reminders list and two count cards.

### Item 6. WhatsApp states

**What exists.** `MessageService.send` opens wa.me (then SMS, then share sheet) and writes a `MessageLog` ("she was
about to send"). Reminders set `Appointment.reminderSentAt` when the chat opens; `AppointmentReminder.waiting` then says
"Reminder sent … No reply yet." and the rows say "Opened". The copy claims a sending nobody saw.

**Proposal.** States: Ready to send → Conversation opened (with a line: "Opening WhatsApp does not confirm the message
was sent") → Marked as sent by you (only after her tap "I sent it"). `Appointment.reminderSentAt` keeps its meaning
(the chat was opened; no data migration); a new optional `Appointment.reminderMarkedSentAt` stores her confirmation.
Queue items other than reminders keep "opened" from the `MessageLog` (persisted now, not session-only) and "marked
as sent" in `FollowUpQueueStore`. Pure `MessageDeliveryState` with tests; the appointment detail, the queue and the
reminder rows use it. The manual wa.me flow is unchanged.

### Item 7. Visit closing

**What exists** (`Screens/Treatment/`): Register (voice or form) → Form → Saved (summary, lock notice, buttons "Next
session" and "Add photos") → Photos / Camera → NextSession (book or save the suggestion). The record id is fixed at the
start, so a retry updates instead of duplicating; the record locks 24 h after creation (`RecordLockPolicy`), after
that only `RecordCorrection`s. Aftercare is a record field prefilled from `Service.aftercareTemplate`; the aftercare
quick reply exists in the message sheet. Closing the flow after Saved loses the place.

**Proposal.** After Save the flow walks one path with a small "Step n of 4" affordance: Record (done) → Photos
(optional) → Aftercare (the record's aftercare text while the record is editable, read-only once locked with the way
to a correction; and the generic aftercare message to the client through the existing message sheet, never the
record's text: docs/06 section 8) → Return (optional, book or save the suggestion; the suggestion is not written once
the record is locked) → Done. Every optional step has Skip; "Finish later" closes and leaves an "Unfinished visit"
item in the queue. Progress is stored per record (`VisitClosingStore`, local, additive); resuming opens the flow on the
saved record (no second record) at the first open step.

### Item 8. Manual record and real AI availability

**What exists.** `TreatmentTools` wires `UnavailableVoiceCapture` and `UnavailableRecordStructuring` in every build
(D53); only DEBUG UI tests swap scripted ones. So they are current: there is no voice and no AI in v1. Still, the flow
opens on a "Register" screen that explains "Recording by voice is coming later" before the form, and AI settings
(`Screens/AISettings`) describes what the assistant does with switches for features that do not exist.

**Proposal.** When voice is not available the flow opens straight on the form (one quiet line says dictation is not
available on this iPhone; no "coming later" promise); the Register screen stays for when a real capture reports
`.available`. The form: the essential fields first (observations, technique, products, result) and the rest of her
template behind "More fields"; "Same as last visit" chips fill technique and products from her last record of this
client and service; product chips from her list (already there). AI settings shows the real status and no switches
or promises while the tools are unavailable. Integration points (`VoiceCapturing`, `RecordStructuring`,
`TreatmentTools`) unchanged.

### Item 12. Why a suggestion appears

**Proposal.** `FollowUpReason` (pure, in the queue's Support) turns each item into one plain sentence from data she
can check: "The usual interval for Brazilian Glow (6 weeks) has passed and no return is booked.", "Last visit 74 days
ago and nothing is booked.", "Visit tomorrow at 10:00. Reminders are ready the evening before.", "Visit yesterday. A
check-in is optional.", "You chose Finish later: photos and aftercare are still open." No clinical inference, no promise;
a footer says she decides whether to contact. Strings in all 14 localizations; tests with fixed `now`.

### Order of work
Stage 1: items 1, 2. Stage 2: items 3, 4. Stage 3: items 7, 5, 6, 12. Stage 4: item 8. Each stage: fast tests, the
relevant UI tests, `check-warnings.sh`, the strings gate, DESIGN.md, PROGRESS, push.

## Owner decision during the work (2026-10-11)

AI and voice are postponed to another day. Item 8 keeps only the faster manual record form (useful defaults, few
essential fields, last-used values, quick chips); the presentation of voice capture, AI structuring, the AI settings
row and any AI copy stay exactly as they are (`UnavailableVoiceCapture`, `UnavailableRecordStructuring`, the Register
screen and AI settings are not touched). Item 12 stays (rules, no AI wording). Recorded in PROGRESS as the post-v1 item
"AI and voice: presentation to match real availability (deferred by the owner on 2026-10-11)".

## Stage 1 log (items 1 and 2)

- `InterfaceLanguage`, `InterfaceLocale`, `String(interface:)` (Models/Locale); `InterfaceLanguageService`
  (Managers/Locale); `MainNavigation` (Screens/Main/Support); App language section in 7.2; `RootView` injects locale and
  layout direction and rebuilds `MainView` on a change; notifications, record field names, profession names, legal
  texts and the push registration use the interface language; 150 `String(localized: "key")` calls converted (76
  files), plus the `locale:`-argument and `resolve: { String(localized:) }` cases.
- Found on the way: `RootView.init` built a new `AppDependencies` every time SwiftUI re-created the view value (a
  language change does it); in a UI-test launch that wiped the defaults suite. Now `AppDependencies.shared`.
- `scripts/check-localization-sources.py` (run by `test.sh fast`, with `--self-test`): a Swift unit test cannot read
  the sources from the simulator (the repository is under Desktop, which the simulator may not read), so the scan is a
  script gate. **Pending after the routine-b merge:** six files of agent B's area keep `String(localized: "key")`
  (`PENDING_ROUTINE_B` in the script): convert them and empty the list.
- `BrandMark` from the icon's SVG paths; `BrandPalette`; `BrandMarkContrastTests`.
- Tests: `InterfaceLanguageTests`, `InterfaceLanguageServiceTests` (injected mirror, so the process locale is never
  changed under other tests), `InterfaceLanguageUITests` (pt-BR, pt-PT, de: switch on an open screen, lock, relaunch).
