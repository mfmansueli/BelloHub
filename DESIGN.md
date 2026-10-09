# BelloHub design

Source of truth for the UI. Update it in the same change as the UI (see CLAUDE.md, section 4). The longer
specification is `docs/08-DESIGN-SYSTEM.md` (tokens) and `docs/09-MOTION.md` (motion); this file records what
is actually built and what was decided while building it.

## Identity

Quiet richness. A warm ivory page, graphite as the strong color, dusty rose and soft sage as accents, peach for
warmth. Depth comes from tonal surfaces, two-layer warm shadows and one memorable "hero" card per key screen,
not from decoration. Fraunces gives the headlines and big numerals a human, editorial voice; DM Sans keeps the
interface clear. No theme, no mascot, no illustrations beyond small composed shapes in empty states.
Sentence case everywhere, no all-caps eyebrows. Warm, direct microcopy (docs/01-PRODUCT.md, "Voice").

## Principles

- Native first: system `TabView`, `NavigationStack`, sheets, menus, pickers and toolbars. The system tab and
  navigation bars carry Liquid Glass on iOS 26 for free. A custom component needs a comment saying why the native one can't do the job.
- Every interactive or meaningful element has an `accessibilityIdentifier` (`<screen>.<element>[.<id>]`, camelCase)
  and works with VoiceOver. **Put identifiers on elements, never on a container**: SwiftUI pushes a container's
  identifier down to its children and replaces theirs (a `Button` inside lost its own identifier in the catalog).
- One primary action per screen. Destructive actions are never the visual primary.
- Right-to-left and non-Latin scripts are first-class (Arabic, Hindi): `leading`/`trailing` only, `Directional`
  for horizontal motion, `BidiIsolate` around names, phones and times inside translated text.

## Tokens

All in `BelloHub/DesignSystem/Tokens/`. Screens use these names and never hex, font or spacing literals.

### Color (`Palette`)

Every token is a light/dark pair. Tokens that carry text or UI parts also declare an Increase Contrast pair.
`PaletteContrastTests` measures every text/background pair in all four combinations (light, dark, each with and
without Increase Contrast), and `HeroContrastTests` measures text on the hero at the lightest point of the glow.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F8F6F2` | `#161412` | Screen background |
| `surface` | `#FFFCF8` | `#1F1C1A` | Cards, list cards, sheets |
| `sunken` | `#EFEBE4` | `#272320` | Wells, input fill, quiet chips |
| `hairline` | `#ECE7DF` | `#34302C` | Card borders, dividers (decorative) |
| `ink` | `#242321` | `#F5F1EA` | Primary text, primary button fill (inverts in dark) |
| `inkOnFill` | `#FFFCF8` | `#161412` | Text on the primary button |
| `ink2` | `#65625D` | `#B5AEA5` | Secondary text |
| `ink3` | `#8C8984` | `#8C857D` | Tertiary icons only, never text |
| `fieldBorder` | `#86817A` | `#7A736B` | Input and secondary-button borders |
| `rose` | `#C98F9F` | `#C98F9F` | Dots, ring accents, glow; never behind small text |
| `roseText` (= `accent`) | `#9A5A6C` | `#E3A8B7` | Links and action text on `bg`/`surface` |
| `roseWash` / `roseDeepWash` | `#F7ECEE` / `#F0DCE1` | `#3A2A2F` / `#4A343A` | Soft backgrounds |
| `roseDeepText` | `#7E4757` | `#F2C4D0` | Small text on rose washes |
| `sage` | `#6E8266` | `#8FA585` | Switch on-track, success graphics |
| `sageText` | `#56684F` | `#B9CBAE` | Confirmed and success text |
| `sageWash` / `sageDeepWash` | `#EEF2EA` / `#DFE6D9` | `#263023` / `#30402C` | Chips, tiles |
| `peach` | `#E8B49E` | `#E8B49E` | Decoration |
| `peachText` / `peachWash` | `#8A5238` / `#FBEFE7` | `#EBBFA9` / `#36281F` | Warm tiles and chips |
| `amberText` / `amberBg` | `#7A5C16` / `#F6ECD6` | `#E8CD85` / `#3B3118` | Pending |
| `coralText` / `coralBg` | `#9A4535` / `#F8E1DC` | `#F2A99B` / `#40231F` | Needs attention, allergies, reactions |
| `neutralText` / `neutralWash` | `#4A4036` / `#EADFD2` | `#E2D6C8` / `#2F2923` | Quiet chips |

Area namespaces: `StatusPalette` (`confirmed`, `pending`, `nextUp`, `completed`, `attention`; foreground,
background and dot), `AvatarPalette` (four gradient pairs chosen by a stable FNV-1a hash of the id),
`HeroPalette` (the graphite surface, dark in both appearances).

Decisions that differ from the prototype, with the reason:

- **`fieldBorder` is darker** (`#86817A` / `#7A736B`, 3.6:1 and 3.9:1 on `bg`). The prototype's soft border is
  1.4:1, below the 3:1 that WCAG 1.4.11 and CLAUDE.md section 5 require of a field boundary.
- **Avatar initials for sage and peach are darker** (`#46573F`, `#74432C`): the prototype's were 4.0:1 on the end of
  the gradient. All eight pairs, both gradient ends, are tested at 4.5:1.
- **`roseText` on `roseWash` is 4.49:1 in light**, so small text on a rose wash uses `roseDeepText` (a test pins the quirk).
- **Secondary text on the hero is a solid `#E0D9D4`** (5.9:1 at the lightest glow point), not cream at 68 % opacity: no
  `.opacity` is ever applied to text.

Contrast, measured (text/background), light then dark: `ink`/`bg` 14.6 / 16.3, `ink2`/`bg` 5.6 / 8.4,
`roseText`/`surface` 5.1 / 8.5, `sageText`/`sageWash` 5.3 / 8.0, `peachText`/`peachWash` 5.6 / 8.5,
`amberText`/`amberBg` 5.3 / 8.2, `coralText`/`coralBg` 5.1 / 7.4, `roseDeepText`/`roseDeepWash` 5.5 / 7.4,
`fieldBorder`/`bg` 3.6 / 3.9, `ink3`/`bg` 3.2 / 5.1. Hero: cream 8.1:1, secondary 5.9:1 at the rose glow peak.
With Increase Contrast every text pair is at least as high (a test asserts it never gets lower).

### Typography (`Typography`)

Fraunces (headings, hero times, numerals, weight 500) and DM Sans (interface, 400 and 600), bundled as variable
fonts in `DesignSystem/Fonts/` with their SIL OFL licenses (`scripts/fetch-fonts.sh` downloads them) and registered
at launch by `FontRegistry` (`UIAppFonts` is an array that `INFOPLIST_KEY_*` cannot express). Every token goes
through `Font.custom(_:size:relativeTo:)`, so Dynamic Type works to AX5. `Font.custom("Fraunces").weight(.medium)`
resolves to `wght` 500 and automatic optical size (checked against an explicit variation on a device-size render).

| Token | Font | Size / weight |
|---|---|---|
| `moment` | Fraunces | 40 / 500 |
| `screenTitle` | Fraunces | 34 / 500 |
| `title` | Fraunces | 28 / 500 |
| `subtitle`, `numeral` | Fraunces | 24 / 500 |
| `section` | DM Sans | 20 / 600 |
| `body`, `bodyStrong` | DM Sans | 17 / 400, 600 |
| `callout`, `calloutStrong` | DM Sans | 16 / 400, 600 |
| `meta`, `metaStrong` | DM Sans | 15 / 400, 600 |
| `footnote`, `footnoteStrong` | DM Sans | 13 / 400, 600 |
| `caption` | DM Sans | 12 / 600 |
| `tabLabel` | DM Sans | 11 / 600 |

Arabic and Hindi have no glyphs in either font; iOS falls back per glyph to the system fonts. They are taller, so
`Typography.lineSpacing(forSize:language:)` adds the 1.15 line-height multiplier for `ar` and `hi`. Numerals that
change use `.contentTransition(.numericText())`; times and durations use monospaced digits.

### Spacing, radius, elevation

`Spacing`: `xxs` 2 · `xs` 4 · `sm` 8 · `row` 12 · `md` 16 · `gutter` 20 · `lg` 24 · `section` 30 · `xl` 32 ·
`touchTarget` 44. `Radius`: `hero` 30 · `card` 24 · `tileSmall` 20 · `tile` 18 · `button` 18 · `control` 14 ·
`input` 14, plus `Radius.concentric(outer:inset:)` (inner radius = outer minus padding). Sheets use the system radius.
`Elevation` `e1`, `e2`, `sheet`: two warm shadow layers in light; in dark a 1 pt top highlight replaces the shadow.

### Icons (`Icon`)

The prototype's 50 icons mapped to SF Symbols in one enum (`Image(icon:)`). Directional symbols
(`chevron.forward`, `chevron.backward`) mirror by themselves in right-to-left languages. Decorative icons are
hidden from VoiceOver; an icon-only button needs an `accessibilityLabel`.

## Motion

One motion layer (D20), in `DesignSystem/Motion/` and `Tokens/Motion.swift`; no screen invents its own animation.

- `Motion.ease` (ease-out quint) for nearly everything, `Motion.soft` (one overshoot) only for the success circle.
- **Arrival:** `StaggeredStack` assigns `motionArrival(index:)` to its children: opacity and 14 pt rise, 0.04 s apart for
  the first nine, 0.36 s for the rest, once per screen presentation. **Bottom bar:** `motionBar()`, last, after 0.18 s.
- **Press:** `BelloButtonStyle` scales to 0.97 with a light haptic (`.selection` on chips, `.warning` on destructive).
- **`SuccessSeal`:** circle pop with one overshoot, check drawn, one ring, success haptic.
- **`HeroSurface`:** slow glow drift (28 s period), one sheen crossing; runs only while on screen and active, stops after 60 s.
- **`MotionPolicy`** (pure, tested): Reduce Motion removes movement, loops, overshoot, sheen and ring and keeps a
  0.2 s fade; Low Power Mode stops loops; `-uiTesting` stops everything (the root sets `isMotionDisabled`).
- Horizontal motion goes through `Directional` so it flips in Arabic.

## Components

Generic, no business rules, in `DesignSystem/Components/` (and `Styles/`, `Backgrounds/`). Each takes
`LocalizedStringKey` for its static copy and never builds a user-visible string itself.

| Component | Notes |
|---|---|
| `BelloButtonStyle` (+ `.belloPrimary`, `.belloSecondary`, `.belloTertiary`, `.belloOnHero`, `.belloDestructive`, `.belloChip(selected:)`) | The one button style. 56 pt high, radius 18; chips 44 pt capsules. Disabled is 40 % opacity |
| `Avatar` + `Initials` | Gradient pair by id hash, initials in locale casing (Turkish `İ`), decorative |
| `StatusChip` | 26 pt capsule, dot and a word |
| `SectionHeader` | 20/600 title (heading trait), optional trailing action, 44 pt target |
| `ListCard` + `belloCard()` | Surface, hairline, `e1`, radius 24; inset dividers start at the text edge (72 pt) |
| `InsightTile` | Wash, icon disc, Fraunces numeral (capped before AX3), one accessibility element; put tiles in an `HStack` with `.fixedSize(horizontal: false, vertical: true)` so heights match |
| `HeroCard` + `HeroSurface` | Graphite, radius 30, glow, `e2`; one per key screen |
| `EmptyState` | Composed shapes, title, next action, optional primary button |
| `SheetHeader` | Title, subtitle, close button (optional `closeIdentifier`), for native sheets |
| `BelloTextField` | 52 pt, radius 14, `sunken`, 1.5 pt `fieldBorder`, 3 pt `roseText` focus ring, error text; `isSensitive` turns off autocorrection; `identifier` goes on the text field itself |
| `InlineNotice` | `.safety` (coral), `.info` (sage), `.warning` (amber) |
| `Skeleton`, `OfflineBanner`, `FooterNote`, `SuccessSeal` | See Motion for the seal |
| `BrandMark`, `BrandLockup` | The graphite "b" with a rose dot, drawn (not an image), and the two-line wordmark. The wordmark is the brand name, never localized, and always left-to-right |
| `ChoiceCard` | A tappable card for a profession or suggested service: selected is `surface` with a 1.5 pt `ink` outline and a check, unselected is flat `sunken`. One element for VoiceOver with the selected trait |
| `FlowLayout` | Wraps chips into rows and follows the reading direction (rows start on the right in Arabic); `wrapsLongChildren` lets a chip with a long label wrap instead of overflowing |
| `StepProgressBar` | One 4 pt segment per step, filled up to the current one; spoken as "Step n of m" |
| `ToggleRow` | Title, optional line, the native `Toggle` tinted `sage` |
| `BelloNoteField` | Multi-line field with the same look as `BelloTextField` (S4) |
| `TagDot` + `TagColor` | The tag color as a pastel fill inside a ring in the family's text tone; four tokens `rose`, `sage`, `peach`, `sand` (wash, text, dot, outline each), unknown tokens read as `sand`; the ring is 3:1 or more on `surface`, `bg` and `sunken` (`TagColorContrastTests`) |
| `ErrorNotice` | An error line with an optional "Try again", for a read or save that failed (S4) |
| `GlowBackdrop` | The page color with a rose glow from the top leading corner (300 pt) and a sage one from the top trailing corner (240 pt), peak 20 %. Only `ink`, `ink2` and `coralText` may sit on a glow (`BackdropContrastTests`); `roseText` links live lower, on the plain page color |

Strings with arguments use a semantic key plus a default value, never `Text("key \(arg)")` (which looks up the key
`key %@`): `LocalizedStringResource("home.greeting", defaultValue: "Good morning, \(name)")`, with
`.localized(in: locale)` where the environment locale must apply.

### Design Catalog (DEBUG)

`-designCatalog` shows every token and component, with a menu for language (all fourteen, including right-to-left
Arabic and Hindi), text size (small to AX5) and appearance. Launch arguments: `-uiLocale <id>`,
`-catalogSection colors|typography|buttons|components|motion`, `-catalogTextSize small|standard|large|accessibility3|accessibility5`,
`-catalogDark`. `DesignCatalogAuditUITests` runs the accessibility audit (clipped text, element description) on
the catalog in `en`, `pt-BR`, `de`, `ar` and `hi`, at the default size and at AX5.

## Screen inventory

| Screen | Folder | ViewModel | Identifiers |
|---|---|---|---|
| Root (state gate) | `Screens/Main/RootView` | `RootViewModel` | none |
| Main (five-tab shell) | `Screens/Main/MainView` | none | none (the system tab bar does not pass identifiers to its buttons; UI tests find tabs by position) |
| 1.1 Welcome | `Screens/Welcome/WelcomeView` | none | `welcome.tagline`, `welcome.getStartedButton`, `welcome.signInButton` |
| 1.2 SignIn | `Screens/SignIn/SignInView` | `SignInViewModel` | `signIn.title`, `signIn.phoneField`, `signIn.countryMenu`, `signIn.sendButton`, `signIn.codeField`, `signIn.verifyButton`, `signIn.resendButton`, `signIn.differentNumberButton`, `signIn.switchModeButton`, `signIn.backButton`, `signIn.error`, `signIn.phoneError` |
| Setup (1.3 to 1.10) | `Screens/Onboarding/OnboardingView` (+ `SetupView`) | `OnboardingViewModel` | `onboarding.<step>.title`, `onboarding.<step>.continueButton`, `onboarding.backButton` |
| About you (new, S3) | `Steps/AboutStepView` | shared | `onboarding.about.nameField`, `onboarding.about.businessField` |
| 1.3 Profession | `Steps/ProfessionStepView` | shared | `onboarding.profession.choice.<id>` |
| 1.4 Services | `Steps/ServicesStepView` | shared | `onboarding.services.choice.<key>`, `onboarding.services.custom.<id>`, `onboarding.services.addCustomButton` |
| 1.5 CustomService (sheet) | `Onboarding/CustomServiceSheet` | local `@State` | `customService.nameField`, `categoryField`, `priceField`, `durationMenu`, `followUp.<weeks>`, `photosToggle`, `aftercareToggle`, `addButton`, `cancelButton` |
| 1.6 Terminology | `Steps/TerminologyStepView` + `AddNameSheet` | shared | `onboarding.terminology.term.<id>`, `onboarding.terminology.addButton`, `addName.*` |
| 1.7 Tags | `Steps/TagsStepView` | shared | `onboarding.tags.choice.<key>`, `onboarding.tags.newButton` |
| 1.8 Record | `Steps/RecordStepView` | shared | `onboarding.record.profession.<id>`, `onboarding.record.field.<key>`, `onboarding.record.intake.<item>` |
| 1.9 Permissions | `Steps/PermissionsStepView` | none (reads `PermissionService`) | `onboarding.permissions.title`, `allowButton`, `notNowButton`, `continueButton` |
| 1.10 Ready | `Steps/ReadyStepView` | shared | `onboarding.ready.title`, `onboarding.ready.continueButton`, `onboarding.ready.error` |
| 1.11 Locked | `Screens/Locked/LockedView` | none (reads `AppLockService`) | `locked.title`, `locked.unlockButton`, `locked.passcodeButton`, `locked.error` |
| 2.1 Home | `Screens/Home/HomeView` -> `HomeContentView` (`HomeNextVisitCard`, `HomeVisitRow`, `RemindersReadyCard`, `HomeFollowUpsCard`, `HomeWinBackLink`) | `HomeViewModel` (reads `AgendaDigestService`) | `home.*` |
| 2.7 FollowUps, 2.8 WinBack | `Screens/FollowUps/`, `Screens/WinBack/` | one view model each (pure lists in `Support/`) | `followUps.*`, `winBack.*` |
| Client message (sheet, `AgendaSheet.clientMessage`) | `Screens/Shared/ClientMessage/` | `ClientMessageViewModel` (`ClientMessageComposer` is pure; nothing is sent by the app, D14) | `clientMessage.*` |
| 7.11 Shared states | `Screens/Shared/States/` (`ScreenPhase`, `ScreenStateView`, `ListLoadingView`) | none | caller-defined |
| 2.2 Clients | `Screens/Clients/ClientsTabView` (stack, `ClientsRoute`) + `ClientsView` | `ClientsViewModel` | `clients.empty`, `clients.row.<uuid>`, `clients.filter.<chip>`, `clients.newButton`, `clients.importButton` |
| 4.1 ClientProfile | `Clients/Profile/ClientProfileView` | `ClientProfileViewModel` | `clientProfile.*` |
| 4.2 NewClient (sheet) | `Clients/Form/NewClientView` | `ClientFormViewModel` | `clientForm.*` (inline "already saved" notice, D42 counter) |
| 4.3 ClientEdit (+ merge sheet) | `Clients/Form/ClientEditView`, `ClientMergeSheet` | `ClientFormViewModel`, `ClientMergeViewModel` | `clientEdit.*`, `clientMerge.*` |
| 4.4 ClientKnowledge | `Clients/Knowledge/ClientKnowledgeView` | `ClientKnowledgeViewModel` | `clientKnowledge.*` |
| 4.5 ClientHealth (+ health form, patch test, signed text sheets) | `Screens/Health/ClientHealthView`, `Health/Sheets/` | `ClientHealthViewModel`, `HealthFormViewModel`, `PatchTestViewModel` | `health.*`, `healthForm.*`, `patch.*`, `signedConsent.*` |
| 4.6 ImportClients (sheet: sources, contacts, column mapping, result) | `Clients/Import/ImportClientsView` | `ImportClientsViewModel` | `importClients.*`, `onboarding.ready.importButton` |
| 6.1 Services (+ 6.2 ServiceEdit sheet, 6.3 AddOns pushed) | `Screens/Services/ServicesView` -> `ServicesContentView`, `AddOns/` | `ServicesViewModel`, `AddOnsViewModel` | `services.*`, `serviceEditor.*`, `addOns.*` |
| 6.4 Products | `Screens/Products/ProductsView` | `ProductsViewModel` | `products.*` |
| 6.10 Credentials (+ preview sheet) | `Screens/Credentials/CredentialsView` | `CredentialsViewModel` | `credentials.*` |
| 6.11 Team (static, D5) | `Screens/Team/TeamView` | none | `team.*` |
| 6.5 Availability (+ hours, break, days-off sheets) | `Screens/Availability/AvailabilityView` | `AvailabilityViewModel` | `availability.*` |
| 6.7 BookingSettings (+ pause sheet) with 6.8 ShareLink, 6.16 CancelPolicy, 6.15 NoShowPolicy | `Screens/BookingSettings/` | `BookingSettingsViewModel`, policy and share view models | `bookingSettings.*`, `shareLink.*`, `cancelPolicy.*`, `noShowPolicy.*` |
| 6.9 QuickReplies (+ editor sheet) | `Screens/QuickReplies/QuickRepliesView` | `QuickRepliesViewModel` | `quickReplies.*` |
| 6.12 Tags (+ tag sheet) | `Screens/Tags/TagsView` | `TagsViewModel` | `tags.*`, `tagEditor.*` |
| 6.13 RecordTemplate (+ field sheet) | `Screens/RecordTemplate/RecordTemplateView` | `RecordTemplateViewModel` | `recordTemplate.*`, `fieldEditor.*` |
| 6.14 FormTemplates (+ consent preview) | `Screens/Health/FormTemplates/FormTemplatesView` | `FormTemplatesViewModel` | `formTemplates.*`, `consentPreview.*` |
| 2.3 Calendar (day timeline + list, week grid + agenda), 2.6 WeekGlance, 3.1 NewAppointment, 3.4 Reschedule, 6.6 BlockTime | `Screens/Calendar/` (rules in `Calendar/Support/`) | one view model per screen; `TimeBlockService` | `calendar.*`, `newAppointment.*`, `reschedule.*`, `blockTime.*` |
| 3.2 Appointment (pushed, `AgendaRoute.appointment`), 3.3 BeforeYouStart, 3.5 Cancel, 3.6 MessageClient, 3.7 NoShowMark, 2.12 RunningLate (sheets), 4.8 SessionPlan, 4.11 NoShowHistory (pushed) | `Screens/Appointments/` | one view model per screen; `MessageService` behind `MessageSending` | `appointment.*` and one prefix per sheet |
| 2.4 Alerts (local part) | `Screens/Alerts/` (`AlertsContentView`, `AlertCard`, `NotificationPermissionNotice`) | `AlertsViewModel` (`AlertsList` is pure) | `alerts.*` |
| 5.1 to 5.9 Treatment flow (`fullScreenCover`, own stack: Register, Listening, Organizing, Review or Form, Saved, Photos, Camera, NextSession) | `Screens/Treatment/` | flow and step view models; voice and AI behind `VoiceCapturing` / `RecordStructuring` (unavailable stubs in v1, D53) | `treatment.*` |
| 4.7 RecordHistory (pushed, `RecordRoute.history`), 4.9 Incident and 4.10 ExportRecord (sheets, `RecordSheet`) | `Screens/Records/` | history, incident and export view models | `recordHistory.*`, `incident.*`, `exportRecord.*` |
| 7.5 AISettings | `Screens/AISettings/` | one screen | `aiSettings.*` (the More row lands with S10) |
| 2.5 More | `Screens/More/MoreTab` (stack, `MoreRoute`) + `MoreView` | none (`MoreSummary` is pure) | `more.profileCard`, `more.<row>Row` (services, products, bookingPage, availability, credentials, team, recordFields, forms, tags, quickReplies), `more.lockNowButton`, `more.signOutButton`, `more.signOutConfirmButton` |
| Privacy cover, storage unavailable | `Screens/Main/PrivacyCover`, `StorageUnavailableView` | none | `storage.unavailable` |
| Design Catalog (DEBUG) | `DesignSystem/Catalog/` | none | `catalog.*` |

The 97 screens and their stages are in `docs/PROGRESS.md` (traceability table).

## Navigation tree

```
RootView (state gate, `RootGate`: welcome → sign-in → setup → locked → app)
├── DesignCatalogView (DEBUG, -designCatalog)
├── WelcomeView ── Get started / Sign in ──▶ SignInView (create | existing)
├── SetupView → OnboardingView: About → Profession → Services (sheet: CustomService) → Terminology (sheet: AddName)
│                → Tags → Record → Permissions → Ready
├── LockedView
└── MainView (TabView, five tabs, each with its own NavigationStack)
    ├── Home      → HomeView → Appointment · FollowUps · WinBack · WeekGlance (same `AgendaRoute` / `AgendaSheet`)
    ├── Clients   → ClientsTabView → ClientsView (title = the term she chose; sheets: NewClient, ImportClients)
    │                → ClientProfile → ClientEdit (sheet: merge) · ClientKnowledge · ClientHealth (sheets: health form,
    │                  patch test, signed text) · RecordHistory (sheets: Incident, ExportRecord)
    │                Start (appointment or profile) → TreatmentFlow (fullScreenCover)
    ├── Calendar  → CalendarView (day | week) → Appointment → SessionPlan · NoShowHistory; WeekGlance
    │                (sheets through `AgendaSheet`: NewAppointment, Reschedule, BlockTime, BeforeYouStart, Cancel,
    │                MessageClient, NoShowMark, RunningLate, ClientMessage)
    ├── Alerts    → AlertsView
    └── More      → MoreTab → MoreView: Business (Services → Add-ons, Products, Booking page → Share link · Cancel policy · No-show policy, Availability, Credentials, Team; S5),
                     Clients (Record fields, Forms, Tags), Messages (Quick replies; S5), Account (Lock now, Sign out)
```

The scene being inactive puts `PrivacyCover` over everything (the app switcher shows the brand, never a client).
Secondary flows are sheets. Celebrations and media viewers are `fullScreenCover`.

### Changes from the prototype (S3)

- **About you** is a new first step (name and optional business name): the prototype greets her by name but never asks.
- **Sign-in** has no "Use email instead": the professional signs in with a phone code only (D3). "Get started" opens the
  same screen with a "Create your workspace" heading; the bottom link switches between creating and signing in.
- **Terminology** asks what she calls the people she serves (client, patient, student, guest) above the names list,
  because `docs/07` section 4 puts that choice here; the prototype only shows the names.
- **Progress** is six segments (About to Record) instead of four.
- **Ready** shows the booking link as "Ready once you go online": the link needs the server (S8). The import shortcut is
  hidden until the import screen exists (S4).
- **Tabs** that have no data yet show an honest empty state without a button; **More** shows the profile card and the two
  actions that work (Lock now, Sign out). Sign-out moves to Account in S10.
- The prototype's custom permission dialogs are the system's own; the page before each one is ours.

### Changes from the prototype (S5)

- **Services**: contraindications use the health-form catalog's tokens (grouped native picker); "Pre-appointment questions" waits for the booking intake (S8); duration is a menu; a switched-off service stays in her list with a badge; add-ons are pushed from Services.
- **Products and credentials**: products are private by default with a Shared/Private chip; the professional registration number is a credential of kind `registration`; no certificate photo until S7.
- **Team** is static: it lists what she will be able to decide once teams exist.
- **Availability**: a starting week (Monday to Friday, 09:00 to 18:00) shown with a notice until she saves; a day can have several stretches (hours sheet); days off from here do not touch booked visits (the cancel-or-invite choice is 6.6, S6).
- **Booking page**: the link says "Ready once you go online"; the pause sheet has an optional return date; the address (slug) is a local preference until the server claims it (S8); no preview, WhatsApp auto-reply or profile section yet.
- **Policies**: the client-facing rule text comes from one pure owner (`PolicyRuleText`) in all 14 localizations; saved policies apply to bookings made afterwards ("Bookings already made keep the rules they were made under"); no-show counting period is 3, 6 or 12 months.
- **Quick replies**: six built-in replies in the business language with fixed ids, editable and restorable; variables `{name} {service} {date} {time} {link}` are rendered locale-aware.
- **More**: Business and Messages sections with subtitles under Booking page and Availability.

### Changes from the prototype (S4)

- **Clients**: an "Archived" filter chip and a Restore row; a merge picker with search; an inline "this number is already
  saved" notice with a button to open her; a warning over a list that shows old data after a failed refresh; a "this
  profile is no longer here" state. Omitted until their stages: Message and Book actions, history, photos and products
  tabs, the "Send my booking link" switch, "Save and book", photo changes, delete client data, no-show history.
- **Client edit and knowledge** are pushed with Cancel (and a confirmation when something changed); New client is the only
  sheet. The knowledge screen also edits the private note.
- **Copy is neutral**: no "she" for the client; "New" reads "First visit" where the word would need gender agreement.
- **Health and consent (4.5)**: "Send form again" waits for the server (S8); review status chip and date; one consent
  row per signed consent (treatment, photo, guardian) that opens the exact signed text; a minor notice with guardian rows
  (D17); new sheets for the health form (questions then consent, one signature), patch test and signed text. Questions
  are never pre-answered.
- **Client forms (6.14)**: the consent texts are read-only versioned documents (three rows), with a language menu; "Ask
  again every" offers 3, 6, 12 and 24 months; "Preview as client" waits for S9. No "draft" wording in the app
  (`legal/STATUS.md`).
- **Import (4.6)**: a column-mapping screen, a "can't be imported" list, a partial-import notice and an "n more need a
  plan" card (D42); contacts come from the system picker (no permission flow); CSV only (the row says so; Excel and
  Numbers export CSV); no booking-link invitation in the result yet.
- **Record fields (6.13)** save as she goes (no "Save changes" bar); her own fields can be renamed, reordered and
  switched off, and keep the data they hold.
- **Tags (6.12)**: four named colors (never color alone), delete inside the sheet and on swipe, counts in people.

### Changes from the prototype (S6 to S8)

- **Home and Alerts**: the digest is rebuilt every minute; "Reminders ready" (D31) is a queue she opens one chat at a
  time, the row then says "Opened"; nothing is sent by the app (D14). Local notifications are generic (counts only, no
  client or service name, tested in all 14 localizations).
- **Calendar**: time blocks are a vault record; the Apple Calendar write-through is one way.
- **Treatment flow (5.x)**: voice and AI structuring are stubs that say they are unavailable (D53); the manual form is
  fully real. No AI sensitivity card, no photo slider or timeline, no reminder parts in 5.9.
- **Record (4.7, 4.9, 4.10)**: history with a lock notice and a correction sheet; the export is a PDF shared through the
  system sheet.
- **Booking page (6.7, 6.8), S8 publish**: hero status line per publish state; `Go online` (`.belloOnHero`) on the hero
  before online, `.belloPrimary` on Share link; `Stop` (`.belloSecondary`) under the share row with a destructive
  confirmation; failure notice (`ErrorNotice`, "Try again" only for offline, busy, locked or rejected). More's Booking
  page row says "Not online yet" or "Needs attention" before the page exists. Identifiers:
  `bookingSettings.{notOnline,onlineStatus,goOnlineButton,stopButton,stopConfirmButton,publishError}`,
  `shareLink.{online,notOnline,goOnlineButton,publishError}`.
- New tokens: none in S6, S7 or S8.

## Empty, loading and error states

Home, Calendar and Alerts use the shared `ScreenPhase` / `ScreenStateView` (loading skeleton, caller-defined empty
state, error with retry; precedence is one rule in `ScreenPhase`). An empty day on Home is an `EmptyState`.
The treatment flow, record history, incident and export define their own states (failed, missing, empty, saved). The Locked screen has an error state (`InlineNotice`): the face did not match, or this
phone has no key for her records. A vault that cannot be opened shows `StorageUnavailableView` and never offers to
erase anything. Each screen that loads data defines all three before it ships: a loading
state (`Skeleton`), an empty state with the next action (`EmptyState`), and an error state with a retry. Clients, the client profile, health and consent, tags and record fields (S4) have all three; their
errors keep what is on screen and offer "Try again". Offline
is a normal state: `OfflineBanner` informs and never blocks.

## Accessibility

- Icon-only buttons have `accessibilityLabel`. Cards combine their children into one element. Touch targets are at least 44×44 pt.
- Every string is localized (`SupportFiles/Localizable.xcstrings`, source language `en`, fourteen localizations, see
  `docs/07-LOCALIZATION.md`). Strings no native has read are `needs_review`.
- Check light and dark, Dynamic Type to AX5, Increase Contrast, Reduce Motion and right-to-left before a feature is done.
- Contrast: text 4.5:1, UI parts 3:1, measured by tests, never `.opacity` on text.
