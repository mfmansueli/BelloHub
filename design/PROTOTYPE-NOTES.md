# Prototype notes

How to read `design/prototype/` and what the demo data is. The prototype is a set of `.dc.html` files (one 390×844 iPhone screen each) from a design tool; **they do not run outside that tool**, so read them as structured markup (layout, spacing, copy) and look at `design/screenshots/` for the rendered result. `Hub.dc.html` is the whole app running in one phone frame (generated from the other files; do not edit).

## 1. Reading a `.dc.html`
- `<x-dc>` holds the markup; `{{a.b}}` are data lookups; `<sc-for>` repeats; `<sc-if>` branches; `<a href="Other.dc.html">` is navigation; `onClick="{{fn}}"` are handlers defined in `renderVals()` in the `<script type="text/x-dc">` block at the bottom (`this.state` / `this.setState` hold the screen's state).
- `<dc-import name="TabBar">` marks where the tab bar sits (use the system `TabView`).
- Inline styles hold the exact values (padding, radius, colors). Cross-check them against `docs/08-DESIGN-SYSTEM.md`: the tokens win.
- Classes `m-bar`, `m-scrim`, `m-sheet`, `m-pop`, `m-check`, `m-hero`, `m-dot` mark where the motion layer applies; see `docs/09-MOTION.md`.
- `hubState` keys (for example `CancelPolicy`, `NoShowPolicy`, `BookingSettings`, `AddOns`, `LanguageRegion`, `RecoveryKey`) are state shared between screens in the prototype; in the app they are domain values owned by repositories/services.
- The prototype is **English**. The fourteen localizations (ten languages) come from `docs/07-LOCALIZATION.md`; the prototype shows the five original ones in the language screen.

## 2. Boards
`project/canvas.json` lists 103 boards: 97 phone screens (ids in `docs/screens/SCREENS.md`), plus `TabBar`, `Main`, `Options`, `FontPairs` and `Inventory` (reference boards, not screens) and `Hub`.

## 3. Demo data (use it for fixtures, previews and UI tests; never as shipped defaults)
- Pro: Maria (esthetician). Booking page: bellohub.app/maria. Working Tue-Sat 09:00-19:00, lunch 12:30-13:30, buffer 15 min.
- Today's appointments: 09:00 Julia Mendes, Deep Cleansing (completed); 11:30 Camila Rocha, Glow Facial (next up); 15:00 Ana Costa, Brazilian Glow (confirmed).
- Phones (demo): Ana Costa +55 11 98765 4321, Camila Rocha +55 11 99876 5432.
- Clients (name, last visit): Ana Costa (Glow Facial, Aug 30), Beatriz Lima (Glow Facial, Sep 2), Camila Rocha (Glow Facial, Sep 11), Helena Duarte (new, booked Oct 1 15:00 Brazilian Glow), Julia Mendes (Deep Cleansing, today), Larissa Souza (Acne Treatment, Sep 18), Marina Alves (Deep Cleansing, Aug 26), Paula Nunes (Glow Facial, Aug 19), Renata Alves (Glow Facial, Sep 29), Gisele Matos (Deep Cleansing, Jul 29), Fernanda Lopes (Glow Facial, Jul 8), Tatiana Brandão (Acne Treatment, Jun 24).
- Follow-ups due now (28-42 days): Beatriz 28 d, Marina 35 d, Paula 42 d. "Haven't returned" (60+ days): Gisele 63 d, Fernanda 84 d, Tatiana 98 d.
- Client habits (private to the pro; cancellation rate only shown after 4 visits): Ana 2 visits, 0 cancelled, 0 no-shows, back every ~6 weeks, books afternoons, late cancellations 0, most booked Glow Facial, found you via booking link. Beatriz 6 visits, 3 cancelled (2 late, under 24 h), 1 no-show, rate 40% of 10 booked, "Cancels often". Camila 3 visits, 0 cancelled.
- Ana: Sensitive skin; fragrance-free; allergy: fragrance; session plan "Skin barrier repair", 6 sessions every 4 weeks, today is session 3 of 6; consent signed Sep 12; patch test Jul 20 calming serum no reaction. Record Aug 30 Glow Facial (calming serum, Good response) has an edit trail: Created Aug 30 17:42 by voice note; edited 18:05 Result Neutral to Good response; correction note added Sep 2 (aftercare). Records lock 24 h after creation; later changes are logged corrections.
- Helena Duarte (booking-flow client) books Thu Oct 1 15:00 Brazilian Glow; she cancels from her appointment page, which frees 15:00 and notifies the waitlist: Paula Nunes, Marina Alves, Beatriz Lima.
- Alerts content: Helena cancelled Thu 15:00 (3 on the waitlist) -> Waitlist.dc.html. Renata Alves answered today's next-day check-in: "A bit irritated, cheeks red since morning" (treatment Sep 29 Glow Facial) -> Incident.dc.html. Haven't-returned: 3 clients -> WinBack.dc.html.
- Cancellation rules are set by the professional in CancelPolicy and NoShowPolicy and read by clients in Bk-1, Bk-5, Bk-9 and Cl-8 (defaults: free changes up to 24 h, reschedule up to 2 times, cancelling after that is allowed with an honest warning, 15 min grace). Client-side demo appointment: Helena Duarte, Thu Oct 1 15:00, 90 min.
- Credentials (Maria): Aesthetics technical course, Senac SP, 2019; Dermaplaning certification, 2022; Biosafety training, 2024; registration number field is empty "Add yours".
- Quick replies templates: Confirm appointment, Running late, Reschedule, Aftercare, Check-in, Come back soon. Variables `{name}`, `{service}`, `{date}`, `{time}`, `{link}`.

## 4. Link contract (who links to what in the prototype)
Existing: Main, TabBar, Onb-1-Welcome, Onb-2-Profession, Onb-3-Services, Onb-4-CustomService, Onb-5-Terminology, Onb-6-Tags, Onb-6b-Record, Onb-7-Ready, ImportClients, Home, Calendar, Appointment, BeforeYouStart, NewAppointment, Clients, NewClient, ClientProfile, Notifications, More, Services, ServiceEdit, Products, BookingSettings, FollowUps, Availability, ClientHealth, ClientKnowledge, Tx-1-Register, Tx-2-Listening, Tx-3-Organizing, Tx-4-Review, Tx-5-Saved, Tx-6-Photos, Tx-7-NextSession, Tx-Form, Bk-1-Page ... Bk-9-Appointment, Cl-1-Reminder, Cl-2-Portal, Cl-3-Rebook, Cl-4-Intake.
New (14): WinBack, Waitlist, WeekGlance, QuickReplies, ShareLink, Credentials, SessionPlan, RecordHistory, Incident, ExportRecord, Camera, Privacy, Cl-5-CheckIn, Cl-6-Cancel. All named `<Name>.dc.html`.

Link contract (link to these, exact filenames):
- Home -> WinBack, WeekGlance, ShareLink, NewAppointment, NewClient, Tx-1-Register, Camera, BeforeYouStart, Appointment, FollowUps, Notifications.
- Clients -> NewClient, ImportClients, ClientProfile, WinBack; filter chips (state) incl. "Due to return", "Cancels often", "New".
- Notifications -> Waitlist, Incident, WinBack, FollowUps, ClientProfile.
- More -> Services, Products, Availability, BookingSettings, Credentials, QuickReplies, Privacy, ShareLink, ImportClients, ClientKnowledge.
- BookingSettings -> ShareLink, Credentials, Availability, Services.
- Calendar / Appointment -> Appointment, BeforeYouStart, NewAppointment, ClientProfile, Waitlist (empty slot "Fill this slot").
- ClientProfile -> ClientKnowledge, ClientHealth, RecordHistory, ExportRecord, SessionPlan, Incident, Tx-1-Register, NewAppointment, Tx-6-Photos, QuickReplies.
- Tx-5-Saved -> RecordHistory, ClientProfile, Home, Tx-7-NextSession. Tx-6-Photos <-> Camera.
- Privacy / Credentials / QuickReplies / ShareLink back to More (ShareLink back to BookingSettings is OK too).
- WinBack -> QuickReplies, Clients, ClientProfile. Waitlist -> Notifications, Calendar. WeekGlance -> WinBack, Waitlist, Home, Calendar.
- Client side: Bk-9-Appointment -> Cl-6-Cancel, Bk-4-DateTime (reschedule); Cl-6-Cancel -> Bk-9-Appointment, Bk-4-DateTime, Cl-3-Rebook; Cl-1-Reminder -> Cl-2-Portal (confirm), Cl-6-Cancel; Cl-5-CheckIn -> Cl-2-Portal; Bk-8-Confirmed -> Cl-4-Intake, Bk-9-Appointment.

## 5. Later additions (cancellation, no-show, day-to-day) and their links
New screens: NoShowPolicy, NoShowMark, NoShowHistory, BookingRequest, Bk-10-Review, CancelPolicy, RescheduleRequest, Bk-11-Find, Cl-8-Reminder, Cl-9-Reschedule, BlockTime, RunningLate, AddOns, ExportAll.
- BookingSettings -> CancelPolicy, NoShowPolicy (policy rows show live values). CancelPolicy <-> NoShowPolicy, CancelPolicy -> Cl-8-Reminder, Bk-1-Page.
- Notifications -> RescheduleRequest, BookingRequest, Appointment (client running late), FollowUps (birthdays).
- Availability ("Block days") and NewAppointment ("Block time instead") -> BlockTime (BlockTime -> Waitlist, Availability, Calendar).
- Home ("Running late?") and Appointment ("Running late") -> RunningLate.
- Services -> AddOns. Bk-2-Service shows the offered add-ons; Bk-5-Info shows guests when BookingSettings allows them; Bk-8 and Bk-9 show the totals.
- Bk-1-Page -> Bk-11-Find; Bk-6-Verify -> Bk-10-Review when new clients need confirmation or the client reached the no-show limit; Bk-8-Confirmed -> Bk-9-Appointment; Bk-9-Appointment -> Cl-9-Reschedule, Cl-6-Cancel.
- Privacy -> ExportAll, ExportRecord. Incident (done) -> NewAppointment (check visit). ClientEdit toggles "Stop online booking" (ClientProfile shows the pill).
- Messages that need sending (late, blocked day, birthday, reminder) always open WhatsApp with the text ready; the app never sends by itself.
- State flows through hub state: CancelPolicy, NoShowPolicy, BookingSettings, AddOns, Bk_2_Service, Bk_5_Info, ClientEdit, BlockTime.


## 6. Prototype conventions worth keeping in the app
- Sentence case everywhere, no all-caps eyebrows.
- 44 pt minimum targets (the Calendar week grid is the one exception).
- Safe areas come from the system, not from the prototype's 62/34/84 pt numbers.
- Allergy and safety notices use the coral card; confirmations use sage; "next up" uses rose.
- Prices are shown only if the professional chose to show them.
- All messages to clients open WhatsApp with the text ready (D14, D31).
