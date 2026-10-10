# Accessibility audit (S12)

Branch `s8-leftovers`, 2026-10-10. Two halves: the automated audit (`BelloHubUITests/AccessibilityAuditUITests`) and
the manual VoiceOver pass below, which a person runs on a real iPhone (H3) before TestFlight.

## 1. Automated audit

Run: `TEST_RUNNER_BELLO_A11Y=1 ONLY_TESTING=BelloHubUITests/AccessibilityAuditUITests scripts/test.sh full`
(`TEST_RUNNER_AUDIT_LOCALES=en`, `TEST_RUNNER_AUDIT_WALKS=records,clients`, `TEST_RUNNER_AUDIT_SETTINGS=none` narrow it).

- Screens: Welcome, Sign in, onboarding About and Profession, Home (both halves), New appointment, Alerts (with the
  inbox fixtures), More, Account, Plan, Privacy, Booking page, Services, Clients list, client profile, Calendar day and
  week, Record history. `en` and `pt-BR`, default size and AX5.
- Settings: `-uiIncreaseContrast` (window scene `accessibilityContrast = .high`, so every `Palette` color resolves to
  its Increase Contrast pair) and `-uiReduceMotion` (motion kit still, SwiftUI animations off), both new DEBUG hooks.
- Audit types: all except pixel-sampled contrast (see section 2).
- The existing per-feature audits (`HomeAuditUITests`, `ClientsAuditUITests`, ... in the Full plan) keep covering
  `de`, `ar`, `hi` and the deeper sheets with clipping and descriptions.

## 2. What the first run found and what changed

First run (en, default size, before fixes): 187 contrast, 20 Dynamic Type, 4 clipping, 2 hit-region issues.

| Finding | Decision |
|---|---|
| **Contrast** (187): body text such as ink `#272522` on white (15:1), `ink2` on cards (6.4:1), the same with Increase Contrast off | XCTest's pixel-sampled contrast check is not usable on this app's text (it flagged pairs far above 4.5:1; screenshot checked). Contrast stays measured exactly by `PaletteContrastTests` and the per-screen contrast tests, light, dark and Increase Contrast, as CLAUDE.md section 5 requires. The audit runs every other type |
| Onboarding step bar "Step 1 of 6" hit region (4 pt tall) | **Fixed**: `StepProgressBar` speaks through a 44 pt overlay, the bar itself is hidden from VoiceOver |
| Brand lockup "bello" / "hub" / mark: Dynamic Type unsupported | **Fixed**: the lockup is one element read as an image ("Bello Hub"); its fixed size is the logo's |
| Privacy "Form key …" subtitle clipped | **Fixed**: `MoreRow` title and subtitle wrap to every line; the key id is no longer wrapped in isolate marks (the audit measures them as extra width; the id is plain ASCII) |
| Toolbar buttons (Save, Edit, Cancel) "partially unsupported" | System Liquid Glass bar caps its own button text; ignored in the audit |
| Search field / text fields "may be clipped" | They scroll their text horizontally; ignored |
| Home insight tile numbers "partially unsupported" | Capped at AX2 on purpose (`InsightTile`): a 30 pt figure must fit its tile; the label under it scales fully |
| Services "Products" row near the tab bar | Reported only while under the tab bar; the audit now skips elements the screen does not fully show (the next swipe audits them) |
| Calendar week "Camila" (contrast nearly passed) | Week-grid chip text; covered by the calendar contrast tests; to look at on a device in the VoiceOver pass |

Second run (en, AX5 too): the Services add row's fixed-size icon fixed and the link rows wrap. Final run (2026-10-10, en and pt-BR, default and AX5): **both tests pass**.

## 3. Manual VoiceOver pass (rotor order per screen)

On a real iPhone, VoiceOver on, swipe right through each screen from the top. Each line is one stop, in order. Check:
the stop exists, the words are as written (in `en`; repeat in `pt-BR`), no stop reads an identifier, a raw date or an
emoji, buttons say "button", headings are on the Headings rotor, and actions are reachable without seeing the screen.
Repeat with Increase Contrast, Reduce Motion and the largest text size.

**Welcome**: Bello Hub (image) · tagline · Sign in with Apple (button) · Continue with phone (button) · Terms and privacy (link).

**Sign in**: Back · title (heading) · explanation · phone field (text field, with its label) · note about texts · Send code (button) · Sign in with Apple.

**Onboarding (each step)**: Back · "Step n of 6" · step title (heading) · step text · the choices in reading order (each "selected" when chosen) · Continue (button, dimmed until valid).

**Home**: greeting (heading) · date · next visit card (client, service, time, one stop) · quick actions (New appointment, Share link, …) · today's visits (one stop each: client, service, time, status) · insight tiles (number and label together) · follow-ups and win back cards · tab bar (Home, Clients, Calendar, Alerts, More).

**New appointment (sheet)**: Cancel · title · client search field · client results (one stop each) · service · day and time pickers · notes · Save (button).

**Alerts**: title (heading) · subtitle · permission strip (if any) · "Waiting for your answer" (heading) · each request card (one stop) then its "Open" button · "From your clients" (heading) · each card (title and text as one stop; a check-in photo as "Photo the client sent", image) then its action ("Mark as handled", "Dismiss", "Got it") · reminders ready · coming up · reach out.

**Booking request**: Back · title · subtitle · summary card (client, service and duration, time, "Cancels often" when shown, her note) · reason notice · "Start her count from zero" switch (when shown) · Suggest another time (button) · Decline · Approve. **Suggest another time sheet**: Close · title · explanation · date and time picker · Keep this time (button); after: notice · Send the link (button).

**Waitlist**: Back · title · the open time · each person (name, when asked, service, "Cancels often" when shown, status) then Offer (button) · actions in the rotor: Remove · Offer to everyone (button).

**More**: profile card (name, business) · sections (headings) · each row (title and subtitle as one stop, "button") · Lock now.

**Account**: Back · name field · business name field · phone, profession, region (read-only) · Language and region · Sign out · Delete account. **Delete account**: export offer · Continue · confirmation · Apple button or Delete.

**Plan**: Back · title · what is included (each item) · monthly and yearly choices (one selected) · Subscribe · Restore purchases · Manage subscription · terms.

**Privacy**: Back · "Where your data lives" (heading) · this iPhone · your iCloud · our servers · no analytics · Booking form key (title and "Form key …") · Recovery key row (status) · Lock section (Face ID lock switch, Lock after) · Photos and names (lock-screen names switch) · Client data (Export all, per client, retention) · Legal (terms, privacy policy).

**Booking page**: Back · status (online / paused / error with Try again) · address · page rows (services, hours, rules, form) · Go online or Stop.

**Services**: Back · Edit · Add (button "Add a service") · each service (name, duration, price when shown) · Add a service row · Add-ons · Products.

**Clients list**: title (heading) · search field · filter chips (each "selected" or not) · each client (name, last visit or next booking, badge such as "Cancels often") · Add (button).

**Client profile**: Back · Edit · name (heading) · chips (habits, tags) · actions (Message, Book) · Health and consent · Records · Photos · Knowledge · Session plan. **Edit**: fields · Online booking switch · reminders switch · Archive · Merge · Delete data (then the confirmation dialog: Delete data, Cancel).

**Calendar**: title · Day / Week picker (segmented, "selected") · previous, today, next · each visit block (client, service, time, status) · New (button). Week: each day (heading) then its visits.

**Record history**: Back · title and client · locked notice · each record (service, date, lock status, one stop) · its trail (each change: when, who, what) · Edit or Change (button) · Reactions (heading) and each incident · Photos (heading) · compare view (before and after) · each photo in the strip (kind and date, button).
