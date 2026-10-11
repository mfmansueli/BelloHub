# INDEX · todas as telas e como chegar a cada uma

Gerado a partir dos links do protótipo. O **ID** (ex.: `2.1`) é o mesmo do hub do protótipo, de `SCREENS.md` e de `HANDOFF.md`.


## 01 · Entrada e configuração inicial

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 1.1 | `Onb-1-Welcome` | 01 Welcome | Onb-2-Profession, SignIn | X |
| 1.2 | `SignIn` | Sign in | Account, More, Onb-1-Welcome | S |
| 1.3 | `Onb-2-Profession` | 02 Profession | Account, Onb-1-Welcome, Onb-3-Services | I |
| 1.4 | `Onb-3-Services` | 03 Services | Onb-2-Profession, Onb-4-CustomService, Onb-5-Terminology | I+S |
| 1.5 | `Onb-4-CustomService` | 04 Custom service | Onb-3-Services | I+S |
| 1.6 | `Onb-5-Terminology` | 05 Your terminology | Onb-3-Services, Onb-6-Tags | I |
| 1.7 | `Onb-6-Tags` | 06 Tags | Onb-5-Terminology, Onb-6b-Record | I |
| 1.8 | `Onb-6b-Record` | 07 Your client record | Onb-6-Tags | I |
| 1.9 | `Permissions` | Permissions | Onb-6b-Record | X |
| 1.10 | `Onb-7-Ready` | 08 Workspace ready | Permissions | S |
| 1.11 | `Locked` | Locked | entrada | L |

## 02 · Abas da profissional

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 2.1 | `Home` | Home | BeforeYouStart, Cl-3-Rebook, FollowUps, Locked, Onb-7-Ready, RunningLate, SignIn, Tx-1-Register, Tx-5-Saved, Tx-7-NextSession, WeekGlance, WinBack | I+S |
| 2.2 | `Clients` | Clients | ClientEdit, ClientProfile, ImportClients, NewClient, Notifications | I |
| 2.3 | `Calendar` | Calendar | Appointment, BlockTime, BookingRequest, CancelAppointment, Home, NewAppointment, NoShowMark, Notifications, Reschedule, RescheduleRequest, RunningLate, Waitlist, WeekGlance | I+S |
| 2.4 | `Notifications` | Alerts | BookingRequest, Incident, RescheduleRequest, Waitlist | I+S |
| 2.5 | `More` | More | AISettings, Account, Availability, BookingSettings, Credentials, Help, Home, Integrations, NotificationSettings, Plan, Privacy, Products, QuickReplies, RecordTemplate, Services, States, Tags, Team | X |
| 2.6 | `WeekGlance` | Week at a glance | Calendar, Home | I |
| 2.7 | `FollowUps` | Follow-ups due | Home, Notifications | I |
| 2.8 | `WinBack` | Win back clients | Clients, FollowUps, Home, Notifications, WeekGlance | I |
| 2.9 | `Waitlist` | Waitlist | BlockTime, Calendar, CancelAppointment, Home, Notifications, WeekGlance | I+S |
| 2.10 | `BookingRequest` | Booking request | Notifications | I+S |
| 2.11 | `RescheduleRequest` | Reschedule request | Notifications | I+S |
| 2.12 | `RunningLate` | Running late | Appointment, Home | I |

## 03 · Agendamentos

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 3.1 | `NewAppointment` | New appointment | Calendar, ClientProfile, FollowUps, Home, Incident, NewClient, Tx-7-NextSession | I+S |
| 3.2 | `Appointment` | Appointment detail | Calendar, CancelAppointment, Home, NoShowMark, Notifications, Reschedule | I+S |
| 3.3 | `BeforeYouStart` | Before you start | Appointment, Home, Notifications | I |
| 3.4 | `Reschedule` | Reschedule | Appointment | I+S |
| 3.5 | `CancelAppointment` | Cancel appointment | Appointment | I+S |
| 3.6 | `MessageClient` | Message a client | Appointment, BookingRequest, ClientProfile, NewAppointment, NoShowMark, RescheduleRequest | X |
| 6.6 | `BlockTime` | Block time | Availability, NewAppointment | I+S |
| 3.7 | `NoShowMark` | Mark a no-show | Appointment | I |

## 04 · Ficha da cliente

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 4.1 | `ClientProfile` | Client profile | Appointment, BeforeYouStart, ClientEdit, ClientHealth, ClientKnowledge, Clients, ExportRecord, Incident, MessageClient, NewAppointment, NoShowHistory, RecordHistory, SessionPlan | I |
| 4.2 | `NewClient` | New client | Clients, Home, NewAppointment | I |
| 4.3 | `ClientEdit` | Edit client | ClientProfile | I |
| 4.4 | `ClientKnowledge` | Edit client knowledge | ClientProfile | I |
| 4.5 | `ClientHealth` | Health and consent | BeforeYouStart, ClientProfile, NewAppointment, Notifications, Tx-6-Photos | I |
| 4.6 | `ImportClients` | Import clients | Clients, Integrations, More, NewClient, Onb-7-Ready | I |
| 4.7 | `RecordHistory` | Record history | BeforeYouStart, ClientProfile, Tx-5-Saved | I |
| 4.8 | `SessionPlan` | Session plan | BeforeYouStart, ClientProfile | I |
| 4.9 | `Incident` | Report a reaction | ClientProfile, Notifications | I |
| 4.10 | `ExportRecord` | Export record | ClientProfile, Privacy | I |
| 4.11 | `NoShowHistory` | No-show history | BookingRequest, ClientProfile, NoShowMark | I |

## 05 · Registro de atendimento

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 5.1 | `Tx-1-Register` | 01 Register treatment | Appointment, BeforeYouStart, ClientProfile, Home, Tx-2-Listening, Tx-Form | I |
| 5.2 | `Tx-2-Listening` | 02 Listening | Tx-1-Register, Tx-Form | I |
| 5.3 | `Tx-3-Organizing` | 03 AI organizing | Tx-2-Listening, Tx-4-Review | I |
| 5.4 | `Tx-4-Review` | 04 Review and save | Tx-3-Organizing | I |
| 5.5 | `Tx-Form` | Manual treatment record | Tx-1-Register | I |
| 5.6 | `Tx-5-Saved` | 05 Saved treatment | Tx-4-Review, Tx-6-Photos, Tx-7-NextSession, Tx-Form | I+S |
| 5.7 | `Tx-6-Photos` | 06 Before and after | BeforeYouStart, Camera, ClientProfile, Tx-5-Saved | I |
| 5.8 | `Camera` | Camera | ClientProfile, Home, Tx-6-Photos | I |
| 5.9 | `Tx-7-NextSession` | 07 Next session | Cl-1-Reminder, Tx-5-Saved, Tx-6-Photos | I+S |

## 06 · Configuração do negócio

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 6.1 | `Services` | Services | AddOns, More, ServiceEdit | I+S |
| 6.2 | `ServiceEdit` | New service | Services | I+S |
| 6.4 | `Products` | Products | More, Services | I |
| 6.5 | `Availability` | Availability | BlockTime, More | I+S |
| 6.7 | `BookingSettings` | Booking page settings | CancelPolicy, More, NoShowPolicy, ShareLink | I+S |
| 6.8 | `ShareLink` | Share link and QR | BookingSettings, Clients, Home, Integrations, More | S |
| 6.9 | `QuickReplies` | Quick replies | MessageClient, More, NoShowPolicy, WinBack | I |
| 6.10 | `Credentials` | Training and credentials | Bk-1-Page, More | I+S |
| 6.11 | `Team` | Team | More | X |
| 6.12 | `Tags` | Client tags | More, NewClient, Onb-6-Tags | I |
| 6.13 | `RecordTemplate` | Record fields | AISettings, FormTemplates, More | I |
| 6.14 | `FormTemplates` | Client forms | More, RecordTemplate | I+S |
| 6.3 | `AddOns` | Add-ons | Services | I+S |
| 6.16 | `CancelPolicy` | Cancellations and changes | BookingSettings, Cl-8-Reminder, NoShowPolicy | I+S |
| 6.15 | `NoShowPolicy` | No-show protection | BookingSettings, CancelPolicy, NoShowHistory, NoShowMark | I+S |

## 07 · Conta e ajustes

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 7.1 | `Account` | Account | ExportAll, LanguageRegion, More, RecoveryKey | S |
| 7.2 | `LanguageRegion` | Language and region | Account | I+S |
| 7.3 | `Plan` | Your plan | More | X |
| 7.4 | `NotificationSettings` | Notification settings | More, Notifications | I |
| 7.5 | `AISettings` | AI assistant | More | L |
| 7.6 | `Integrations` | Integrations | More | L |
| 7.7 | `Privacy` | Privacy and security | Account, ClientEdit, ExportAll, More, NotificationSettings, RecoveryKey | I |
| 7.10 | `Help` | Help and support | More | X |
| 7.11 | `States` | System states | More | X |
| 7.8 | `ExportAll` | Export all my data | Privacy | I |
| 7.9 | `RecoveryKey` | Recovery key | Privacy | L |

## 08 · Página de agendamento da cliente (web)

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 8.1 | `Bk-1-Page` | 01 Public booking page | Bk-10-Review, Bk-11-Find, Bk-2-Service, BookingSettings, CancelPolicy, Credentials | S |
| 8.2 | `Bk-2-Service` | 02 Select service | Bk-1-Page, Bk-3-Professional, Bk-4-DateTime | S |
| 8.3 | `Bk-3-Professional` | 03 Choose professional (teams only) | entrada | S |
| 8.4 | `Bk-4-DateTime` | 04 Date and time | Bk-3-Professional, Bk-5-Info | S |
| 8.5 | `Bk-5-Info` | 05 Your details | Bk-4-DateTime, Bk-6-Verify | S |
| 8.6 | `Bk-6-Verify` | 06 Verification | Bk-10-Review, Bk-5-Info, Bk-7-Questions | S |
| 8.7 | `Bk-7-Questions` | 07 First-time questions | entrada | S |
| 8.8 | `Bk-8-Confirmed` | 08 Booking confirmed | Bk-7-Questions, Bk-9-Appointment | S |
| 8.9 | `Bk-9-Appointment` | 09 View appointment | Bk-11-Find, Bk-8-Confirmed, Cl-6-Cancel, Cl-8-Reminder, Cl-9-Reschedule | S |
| 8.10 | `Bk-10-Review` | 10 Booking needs Maria | entrada | S |
| 8.11 | `Bk-11-Find` | 11 Find your appointment | Bk-1-Page | S |

## 09 · Portal da cliente (web)

| ID | Tela | Título | Chega de | Dados |
|---|---|---|---|---|
| 9.1 | `Cl-1-Reminder` | 01 Reminder on WhatsApp | FollowUps, Tx-7-NextSession | S |
| 9.2 | `Cl-2-Portal` | 02 Client portal | Cl-3-Rebook, Cl-4-Intake, Cl-5-CheckIn, Cl-7-MyData | S |
| 9.3 | `Cl-3-Rebook` | 03 Book again | Bk-9-Appointment, Cl-1-Reminder, Cl-2-Portal, Cl-6-Cancel | S |
| 9.4 | `Cl-4-Intake` | 04 Health form | Bk-8-Confirmed, ClientHealth, FormTemplates | S |
| 9.5 | `Cl-5-CheckIn` | 05 Skin check-in | entrada | S |
| 9.6 | `Cl-6-Cancel` | 06 Cancel or change | Bk-9-Appointment | S |
| 9.7 | `Cl-7-MyData` | 07 Your information | entrada | S |
| 9.8 | `Cl-8-Reminder` | 8 Appointment reminder | CancelPolicy | S |
| 9.9 | `Cl-9-Reschedule` | 9 Reschedule | Bk-9-Appointment, Cl-6-Cancel | S |
