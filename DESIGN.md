# BelloHub design

Source of truth for the UI. Update it in the same change as the UI (see CLAUDE.md, section 4). The longer
specification is `docs/08-DESIGN-SYSTEM.md` (tokens) and `docs/09-MOTION.md` (motion); this file records what
is actually built and what was decided while building it.

## Identity

Quiet richness. A warm ivory page (a deep green-graphite one in dark), sage as the strong color of the one primary
action, dusty rose and sage as accents, peach for warmth; medium intensity since the 2026-10-10 refinement (warmer and
more alive than the first pastel proposal, calmer than the saturated one). Depth comes from tonal surfaces, two-layer warm shadows and one memorable "hero" card per key screen,
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
| `bg` | `#FAF7F1` | `#191D19` | App background |
| `surface` | `#FFFFFF` | `#252B25` | Neutral surface: cards, list cards, sheets |
| `sunken` | `#F3EFE7` | `#30382F` | Elevated neutral surface: wells, input fill, quiet round buttons |
| `hairline` | `#D5D8CF` | `#566151` | Neutral separator and card border (decorative) |
| `ink` | `#272522` | `#F7F2E8` | Primary text (no longer a fill) |
| `ink2` | `#625F59` | `#C6C4B9` | Secondary text, placeholders |
| `ink3` | `#888781` | `#8D9787` | Tertiary icons only, never text |
| `fieldBorder` | `#7E8078` | `#82907C` | Input and secondary-button borders (3:1) |
| `action` / `onAction` | `#4F6B4D` / `#FAF5EB` | `#57744E` / `#FAF5EB` | The one primary action; check discs, radios, filled progress |
| `selectionFill` / `selectionInk` | `#CADAC2` / `#3C5638` | `#435C3C` / `#F7F2E8` | Selected chip, day, option (always with a `selectionInk` ring or a check); `selectionInk` is the tab bar tint |
| `sageFill` / `peachFill` / `roseFill` | `#BDD0B3` / `#F0C5A6` / `#E3B5C7` | `#3B5540` / `#704B37` / `#684353` | Solid brand card and illustration fills (insight tiles, empty-state shapes, avatar gradient ends) |
| `onBrandCard` | `#252823` | `#F7F2E8` | Text on a brand card fill |
| `sageBadge` / `peachBadge` / `roseBadge` | `#FAF5EB` (ivory) | `#2C4231` / `#573626` / `#52323F` | Icon discs on a brand card; the icon is the family accent |
| `sageText` | `#4F6B4D` | `#BDDAAA` | Sage icon/accent: confirmed, success, info |
| `peachText` | `#8F5235` | `#FFD1AF` | Peach icon/accent |
| `roseText` (= `accent`) | `#8D4761` | `#F2B8CE` | Rose icon/accent: links, action text, focus ring |
| `roseDeepText` | `#7A3B53` | `#F8CBDB` | Small text on deep rose washes, the "left" count |
| `sageWash` / `sageDeepWash` | `#E8EFE2` / `#D9E5D0` | `#2A372A` / `#34472F` | Quiet tinted surfaces: chips, notices, icon squares |
| `roseWash` / `roseDeepWash` | `#F7E8EE` / `#EFD6E0` | `#3B2A31` / `#4A3440` | Quiet tinted surfaces |
| `peachWash` | `#FBECE1` | `#3D2C22` | Win-back strip, warm icon squares |
| `rose`, `sage`, `ivory`, `brandMark` | `#C98F9F`, `#6E8266`, `#FAF5EB`, `#6E8266` | `#C98F9F`, `#8FA585`, `#FAF5EB`, `#344B3C` | Brand identity (logo swatches): dots, glows, switch track, the mark |
| `peach` | `#E8B49E` | `#E8B49E` | Tag dot |
| `amberText` / `amberBg` | `#7A5C16` / `#F6ECD6` | `#E8CD85` / `#3B3118` | Pending, warnings (status only) |
| `coralText` / `coralBg` | `#9A4535` / `#F8E1DC` | `#F2A99B` / `#40231F` | Needs attention, allergies, contraindications, destructive (status only) |
| `neutralText` / `neutralWash` | `#4A4036` / `#EADFD2` | `#E2D6C8` / `#3A3630` | Completed, quiet chips |

Every text token also has an Increase Contrast value (darker in light, lighter in dark); `onAction` turns white in
dark with Increase Contrast and the light `action` fill deepens to `#435A41`.

Area namespaces: `StatusPalette` (`confirmed`, `pending`, `nextUp`, `completed`, `attention`; foreground,
background and dot), `AvatarPalette` (four gradient pairs chosen by a stable FNV-1a hash of the id; the ends are the
brand card fills, initials the deep family accent), `HeroPalette` (the hero surface, a green-graphite `#2F362E` to
`#232823` in both appearances, ivory `#FAF5EB` text, `#DAD8CE` secondary, `#48524A` raised), `Elevation.tint`
(`#2E3329`, a neutral green-graphite shadow).

Roles are kept apart: brand identity, neutral surfaces and foregrounds, the primary action, selection, the brand
families (fill, badge, accent) and the semantic statuses. Amber and coral never become decorative, and peach or rose
never carry a safety warning.

Decisions, with the reason:

- **2026-10-10 color refinement**: the approved medium-intensity sage, rose and peach (task
  `docs/tasks/color-refinement.md`, mapping in `docs/agent-notes/color-refinement.md`). Implemented from the hex
  specification; the reference mockup was not in the repository. The primary action moved from `ink` to `action`
  (sage); `inkOnFill` is gone.
- **The selection fill never carries the state alone**: `#CADAC2` is 1.4:1 on the page, so a selected chip, day or
  option also gets a 1.5 pt `selectionInk` ring (7.6:1 on the page) or a check. The native glass tab bar draws its own
  selection pill; only its tint is `selectionInk`.
- **The dark `action` fill is 2.8:1 on a dark card**: on a card it only carries an ivory glyph (check disc, radio), and
  selected outlines use `selectionInk`. As filled progress on the page it is 3.3:1.
- **`fieldBorder` is darker than the separator** (3.7:1 / 5.1:1 on `bg`, 3.5:1 / 3.6:1 on the input fill): the
  separator `#D5D8CF` is decorative, a field boundary needs 3:1 (WCAG 1.4.11).
- **The hero's next-up dot is the logo rose**: the hero is dark in both appearances, so a light-mode text token there
  vanished (4.7:1 now).
- **The mark matches the app icon**: a sage tile (darker sage in dark), an ivory "b" and a rose dot.
- **Secondary text on the hero is a solid `#DAD8CE`** (5.3:1 at the lightest glow point), not cream at 68 % opacity:
  no `.opacity` is ever applied to text.

Contrast, measured (text/background), light then dark: `ink`/`bg` 14.3 / 15.3, `ink2`/`bg` 6.0 / 9.8,
`onAction`/`action` 5.45 / 4.82, `selectionInk`/`selectionFill` 5.6 / 6.6, `onBrandCard` on sage/peach/rose fills
9.13 / 9.42 / 8.32 and 7.35 / 6.84 / 7.48, badge icons on badges 5.5 / 5.6 / 6.0 and 7.1 / 7.7 / 6.6,
`roseText`/`surface` 6.6 / 8.6, `roseText`/`roseWash` 5.5 / 8.0, `sageText`/`sageWash` 5.1 / 8.2,
`peachText`/`peachWash` 5.3 / 9.5, `amberText`/`amberBg` 5.3 / 8.2, `coralText`/`coralBg` 5.1 / 7.4,
`roseDeepText`/`roseDeepWash` 6.0 / 7.8, `fieldBorder`/`bg` 3.7 / 5.1, `ink3`/`bg` 3.4 / 5.6. Hero: ivory 7.0:1,
secondary 5.3:1 at the rose glow peak. With Increase Contrast every pair is at least as high (a test asserts it never
gets lower).

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
| `BelloButtonStyle` (+ `.belloPrimary`, `.belloSecondary`, `.belloTertiary`, `.belloOnHero`, `.belloDestructive`, `.belloChip(selected:)`) | The one button style. 56 pt high, radius 18; chips 44 pt capsules. Primary is `action` with an ivory label and a soft `Elevation.tint` lift; a selected chip is `selectionFill`, `selectionInk` label and a 1.5 pt `selectionInk` ring. Disabled is 40 % opacity |
| `Avatar` + `Initials` | Gradient pair by id hash, initials in locale casing (Turkish `İ`), decorative |
| `StatusChip` | 26 pt capsule, dot and a word |
| `SectionHeader` | 20/600 title (heading trait), optional trailing action, 44 pt target |
| `ListCard` + `belloCard()` | Surface, hairline, `e1`, radius 24; inset dividers start at the text edge (72 pt) |
| `InsightTile` | Solid brand fill (`sageFill`, `peachFill`, `roseFill`), a family badge with the family accent icon, `onBrandCard` numeral and label, Fraunces numeral (capped before AX3), one accessibility element; put tiles in an `HStack` with `.fixedSize(horizontal: false, vertical: true)` so heights match |
| `HeroCard` + `HeroSurface` | Green-graphite, radius 30, glow, `e2`; one per key screen |
| `EmptyState` | Composed shapes in the illustration fills (`roseFill`, `sageFill`, `peachFill`), title, next action, optional primary button |
| `SheetHeader` | Title, subtitle, close button (optional `closeIdentifier`), for native sheets |
| `BelloTextField` | 52 pt, radius 14, `sunken`, 1.5 pt `fieldBorder`, 3 pt `roseText` focus ring, error text; `isSensitive` turns off autocorrection; `identifier` goes on the text field itself |
| `InlineNotice` | `.safety` (coral), `.info` (sage), `.warning` (amber) |
| `Skeleton`, `OfflineBanner`, `FooterNote`, `SuccessSeal` | See Motion for the seal |
| `BrandMark`, `BrandLockup` | The ivory "b" on the sage `brandMark` tile with a rose dot (as the app icon), drawn (not an image), and the two-line wordmark. The wordmark is the brand name, never localized, and always left-to-right |
| `ChoiceCard` | A tappable card for a profession or suggested service: selected is `surface` with a 1.5 pt `selectionInk` outline and an `action` check disc, unselected is flat `sunken`. One element for VoiceOver with the selected trait |
| `FlowLayout` | Wraps chips into rows and follows the reading direction (rows start on the right in Arabic); `wrapsLongChildren` lets a chip with a long label wrap instead of overflowing |
| `StepProgressBar` | One 4 pt segment per step, filled in `action` up to the current one (`hairline` after it); spoken as "Step n of m" |
| `ToggleRow` | Title, optional line, the native `Toggle` tinted `sage` |
| `BelloNoteField` | Multi-line field with the same look as `BelloTextField` (S4) |
| `TagDot` + `TagColor` | The tag color as a pastel fill inside a ring in the family's text tone; four tokens `rose`, `sage`, `peach`, `sand` (wash, text, dot, outline each), unknown tokens read as `sand`; the ring is 3:1 or more on `surface`, `bg` and `sunken` (`TagColorContrastTests`) |
| `ErrorNotice` | An error line with an optional "Try again", for a read or save that failed (S4) |
| `GlowBackdrop` | The page color with a rose glow from the top leading corner (300 pt) and a sage one from the top trailing corner (240 pt), peak 20 %. Only `ink`, `ink2` and `coralText` may sit on a glow (`BackdropContrastTests`); `roseText` links live lower, on the plain page color |
| `DataImage` | Image bytes (a vault photo or a scanned paper) drawn as an image; promoted from the treatment flow by D55 because two features use it |
| `PDFDocumentView` | A PDF from memory through PDFKit (`UIViewRepresentable`); nothing is written to disk (D55, the consent paper preview) |

Strings with arguments use a semantic key plus a default value, never `Text("key \(arg)")` (which looks up the key
`key %@`): `LocalizedStringResource("home.greeting", defaultValue: "Good morning, \(name)")`, with
`.localized(in: locale)` where the environment locale must apply.

### Design Catalog (DEBUG)

`-designCatalog` shows every token and component, with a menu for language (all fourteen, including right-to-left
Arabic and Hindi), text size (small to AX5) and appearance. Launch arguments: `-uiLocale <id>`,
`-catalogSection colors|typography|buttons|components|motion`, `-catalogTextSize small|standard|large|accessibility3|accessibility5`,
`-catalogDark`. `DesignCatalogAuditUITests` runs the accessibility audit (clipped text, element description) on
the catalog in `en`, `pt-BR`, `de`, `ar` and `hi`, at the default size and at AX5.

Review screenshots of the app in light and dark (Home, Calendar, Alerts, Clients, a client, the new-appointment sheet,
the catalog): `TEST_RUNNER_SCREENSHOT_DIR=$PWD/build/screenshots ONLY_TESTING=BelloHubUITests/ColorReviewUITests
scripts/test.sh full` (skipped in every plan otherwise). `-uiDark` runs the whole app in dark, because the iOS 27
simulator's appearance switch does not reach apps.

Home's "New appointment" quick action is the screen's primary (`action`) while the day has visits; on a clear day the
empty state's own "New appointment" is the primary and the quick action is secondary.

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
| 4.5 ClientHealth "Health and consents" (+ health form, patch test, consent record sheets) | `Screens/Health/ClientHealthView`, `Health/Sheets/` | `ClientHealthViewModel`, `HealthFormViewModel`, `PatchTestViewModel`, `ConsentRecordViewModel` | `health.*`, `healthForm.*`, `patch.*`, `consent.*` (D55) |
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
| 6.14 FormTemplates | `Screens/Health/FormTemplates/FormTemplatesView` | `FormTemplatesViewModel` | `formTemplates.*` |
| 2.3 Calendar (day timeline + list, week grid + agenda), 2.6 WeekGlance, 3.1 NewAppointment, 3.4 Reschedule, 6.6 BlockTime | `Screens/Calendar/` (rules in `Calendar/Support/`) | one view model per screen; `TimeBlockService` | `calendar.*`, `newAppointment.*`, `reschedule.*`, `blockTime.*` |
| 3.2 Appointment (pushed, `AgendaRoute.appointment`), 3.3 BeforeYouStart, 3.5 Cancel, 3.6 MessageClient, 3.7 NoShowMark, 2.12 RunningLate (sheets), 4.8 SessionPlan, 4.11 NoShowHistory (pushed) | `Screens/Appointments/` | one view model per screen; `MessageService` behind `MessageSending` | `appointment.*` and one prefix per sheet |
| 2.4 Alerts | `Screens/Alerts/` (`AlertsContentView`, `AlertCard`, `NotificationPermissionNotice`) | `AlertsViewModel` (`AlertsList` and `InboxAlerts` are pure) | `alerts.*`, `alerts.request.<bookingId>[.action]`, `alerts.reschedule.<requestId>[.action]`, `alerts.waitlist[.action]` |
| 2.10 BookingRequest, 2.11 RescheduleRequest, 2.9 Waitlist (pushed, `AgendaRoute.bookingRequest` / `.rescheduleRequest` / `.waitlist`) | `Screens/Inbox/` (`RequestSummaryCard`, `RequestAnswerBar`, `RequestOutcomeNotice`, `WaitlistPersonRow`) | one per screen over `BookingSyncService` (`InboxRequestPhase`, `RescheduleTiming` pure; `WaitlistBoard` in `Models/Inbox`) | `bookingRequest.*`, `rescheduleRequest.*` (`.client`, `.note`, `.time` / `.current` / `.requested`, `.reason`, `.resetCountToggle`, `.acceptButton`, `.declineButton`, `.outcome`, `.needsPlan`, `.seePlansButton`, `.historyButton`, `.timing`, `.slotTaken`, `.missing`), `waitlist.*` (`.openTime`, `.person.<id>`, `.offer.<id>`, `.offerAllButton`, `.slotTaken`, `.empty`, `.error`) |
| 5.1 to 5.9 Treatment flow (`fullScreenCover`, own stack: Register, Listening, Organizing, Review or Form, Saved, Photos, Camera, NextSession) | `Screens/Treatment/` | flow and step view models; voice and AI behind `VoiceCapturing` / `RecordStructuring` (unavailable stubs in v1, D53) | `treatment.*` |
| 4.7 RecordHistory (pushed, `RecordRoute.history`), 4.9 Incident and 4.10 ExportRecord (sheets, `RecordSheet`) | `Screens/Records/` | history, incident and export view models | `recordHistory.*`, `incident.*`, `exportRecord.*` |
| 7.5 AISettings | `Screens/AISettings/` | one screen | `aiSettings.*` (More → Preferences) |
| 7.1 Account (+ Delete account sheet) | `Screens/Account/` | `AccountViewModel` (the sheet runs on it; `AccountDeletionFlow`, `AccountRules` pure) | `account.*` (`account.signOutButton`, `account.languageRegionRow`, `account.nameField`) |
| 7.2 LanguageRegion | `Screens/LanguageRegion/` (`RegionPresetRow`, `WeekClockCard`) | `LanguageRegionViewModel` (`LanguageRegionRules`, `LanguageRegionDraft`) | `languageRegion.*` |
| 7.3 Plan, and the paywall (same screen in `PaywallSheet`, D42) | `Screens/Plan/` | `PlanViewModel` (`PlanPresentation`) over `SubscriptionService` | `plan.*`, `paywall.*` |
| 7.4 NotificationSettings | `Screens/NotificationSettings/` | `NotificationSettingsViewModel` | `notificationSettings.*` |
| 7.6 Integrations | `Screens/Integrations/` | `IntegrationsViewModel` over `CalendarIntegrationService` | `integrations.*` |
| 7.7 Privacy (+ Legal notice sheet) | `Screens/Privacy/` | `PrivacyViewModel` (`LegalNoticeLibrary`) | `privacy.*`, `legalNotice.*` |
| 7.8 ExportAll | `Screens/ExportAll/` | `ExportAllViewModel` over `DataExportService` | `exportAll.*` |
| 7.9 RecoveryKey (+ Restore key sheet from Locked) | `Screens/RecoveryKey/` | `RecoveryKeyViewModel`, `RestoreKeyViewModel` over `RecoveryKeyService` | `recoveryKey.*`, `restoreKey.*`, `locked.restoreKeyButton` |
| 7.10 Help | `Screens/Help/` | none (`HelpTopics`) | `help.*` |
| 2.5 More | `Screens/More/MoreTab` (stack, `MoreRoute`) + `MoreView` | none (`MoreSummary` is pure) | `more.profileCard`, `more.<row>Row` (services, products, bookingPage, availability, credentials, team, recordFields, forms, tags, quickReplies, plan, notifications, integrations, privacy, aiSettings, help, account), `more.lockNowButton` (sign out moved to Account in S10) |
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
├── LockedView (sheet: Restore key, when this phone has no key)
└── MainView (TabView, five tabs, each with its own NavigationStack)
    ├── Home      → HomeView → Appointment · FollowUps · WinBack · WeekGlance (same `AgendaRoute` / `AgendaSheet`)
    ├── Clients   → ClientsTabView → ClientsView (title = the term she chose; sheets: NewClient, ImportClients)
    │                → ClientProfile → ClientEdit (sheet: merge) · ClientKnowledge · ClientHealth (sheets: health form,
    │                  patch test, consent record) · RecordHistory (sheets: Incident, ExportRecord)
    │                NewClient / Import at the 11th registration → Paywall sheet (the Plan screen, D42)
    │                Start (appointment or profile) → TreatmentFlow (fullScreenCover)
    ├── Calendar  → CalendarView (day | week) → Appointment → SessionPlan · NoShowHistory; WeekGlance
    │                (sheets through `AgendaSheet`: NewAppointment, Reschedule, BlockTime, BeforeYouStart, Cancel,
    │                MessageClient, NoShowMark, RunningLate, ClientMessage)
    ├── Alerts    → AlertsView → BookingRequest (sheet: Paywall; → NoShowHistory) · RescheduleRequest · Waitlist
    └── More      → MoreTab → MoreView: Business (Services → Add-ons, Products, Booking page → Share link · Cancel policy · No-show policy, Availability, Credentials, Team; S5),
                     Clients (Record fields, Forms, Tags), Messages (Quick replies; S5),
                     Preferences (Plan, Notifications, Integrations, Privacy → Recovery key · Export all · Legal notice,
                     AI assistant, Help; S10), Account (profile card or row → Account → Language and region,
                     Delete account sheet → Export all; Sign out; S10), Lock now
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
- **Health and consent (4.5)**: "Send form again" waits for the server (S8); review status chip and date; new sheets
  for the health form and patch test. Questions are never pre-answered. (S4's consent texts, signatures and signed
  text sheet were removed by D55; see below.)
- **Client forms (6.14)**: "Ask again every" offers 3, 6, 12 and 24 months; "Preview as client" waits for S9. No
  "draft" wording in the app (`legal/STATUS.md`). (S4's consent text rows and preview were removed by D55.)
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
- **Calendar**: time blocks are a vault record; the Apple Calendar write-through is one way (built in S12, see "Release hardening").
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

### Changes from the prototype (S10, account and settings)

- **7.1 Account**: no photo (initials stand in) and no "Change photo" sheet; the email is not editable (the session has
  no email); no city field (the region row covers it). Sign out moved here from More; Delete account is a sheet that
  offers the export first, then asks "Delete everything?", then shows a done screen (the server answers first, D44).
- **7.3 Plan**: no trial lines (D33/D42); two price cards (yearly highlighted and chosen by default, the saving read
  from the store's prices). The paywall is this screen in a sheet with the D42 headline.
- **7.6 Integrations**: Google Calendar is "Coming soon" (H9); Apple Calendar is a switch, one way.
- **7.7 Privacy**: the terms with the DPA and the privacy policy open in a Legal notice sheet read from the bundle;
  pending operator fields are visibly pending in DEBUG and absent in Release; the word "draft" never appears.
- **7.8 Export**: D18 copy (Save to Files or share, no e-mail link, no format choice).
- **7.9 Recovery key**: the real twelve words behind Face ID (two columns, one above the default text size, so an
  eight-letter word is never cut; forced left to right, `privacySensitive`); Restore lives on the Locked screen.
- **7.10 Help**: six questions as rows, "Write to support" and "Send feedback" as `mailto:` links; no chat.
- Feature-local components (not Design System): `RegionPresetRow`, `WeekClockCard`, the 12-word grid, the preview
  bubbles. No new tokens, colors or fonts.

### Changes from D55 (consents are the professional's own business)

- **4.5**: title "Health and consents". Section "Consents": a list card of records (her label or the kind title; chip
  Signed / Not signed, sage / amber; "Signed · date" or "Not signed · noted date"; "Photo kept · Note"), an "Add
  consent" row and a footnote that the paper is signed with her. Sheet "New consent" / "Consent": kind chips
  (Treatment, Photo, Guardian, Other), optional label, "Signed" switch with a date, note, an optional photo
  (`PhotosPicker`) or file (`fileImporter`) of the signed paper with a preview (photo, PDF through PDFKit, or a file
  icon with name and size), Remove, Delete consent (destructive, confirmed) when editing, Save consent (primary) in a
  bottom bar.
- **Health form sheet**: questions and the under-18 switch with the minor's name only; no agreement, signature or
  guardian name; Save is "Save answers".
- **6.14**: the consent text section and preview sheet are gone. **Export PDF**: consents print the label and
  "Signed <date>" or "Not signed", never the photo or file.
- Design System: `DataImage` (bytes to image, promoted from the treatment flow) and `PDFDocumentView` (a PDF from
  memory; nothing touches the disk).
- Identifiers: `health.addConsentButton`, `health.consent.<uuid>`, `health.consent.empty`, `health.consent.footnote`,
  `consent.{closeButton,kind.<kind>,labelField,signedToggle,datePicker,noteField,addPhotoButton,addFileButton,
  removeDocumentButton,documentPreview,preparingDocument,deleteButton,deleteConfirmButton,error,saveButton}`.

### Changes from the prototype (S8 inbox: 2.9, 2.10, 2.11)

- **Entry**: the three screens are pushed from cards at the top of Alerts ("Waiting for your answer"): one card per
  booking request (rose when the no-show limit holds it), one per reschedule request, and one Waitlist card ("A time
  opened up" when a cancelled time can be offered, with the number of people waiting).
- **2.10 BookingRequest**: the reason it waits is a notice per `PendingReason` (no-show limit: coral, with "See history"
  when the phone matches one of her clients; free registrations used: amber; new client: sage). "Start the count from
  zero" only for the no-show limit, sent before the approval. Approving when a plan is needed shows an amber notice
  with "See plans" (the paywall sheet, D42); she approves again after buying. **"Suggest another time" is not built**:
  the server has no counter-offer call; she can decline and message the client.
- **2.11 RescheduleRequest**: "Now" (struck through while the request is open) and "Asks for"; the primary button
  says "Move the visit" (not the weekday name, which needs grammar per language); the timing notice says how long
  before the visit the client asked and her free-change rule, shown only when the request came inside the window;
  a time taken in the meantime leaves Decline only. "Suggest another time" is not built (same reason).
- **2.9 Waitlist**: the hero is the earliest future cancellation nobody re-booked ("Freed by", time, day and service,
  length and end); "Waiting for this day" lists people whose days cover it, each with Offer (chip style) or "Offered
  until"; "Also waiting" lists the rest; "Offer to everyone" (primary, bottom bar) offers in order and stops when
  the time is taken. Remove is in the row's context menu and VoiceOver actions (no swipe inside a card). The
  prototype's "Cancels often" chip is not built (no cancellation history on the server's waitlist entry).
- **States**: requests show a skeleton until the first sync, an empty state when the request is gone, "Sending your
  answer…" (or "Saved. It is sent as soon as you are online.") while queued, and an outcome notice after; the waitlist
  has a skeleton, an empty state, an offer error (offers are never queued) and a taken-time notice.
- No new tokens.

### Changes from the security review (S8 leftovers)

- **Alerts, "From your clients"** (`MailboxAlertCards`, pure `MailboxAlerts`): after the request cards, one `AlertCard`
  per thing her clients sent through their sealed links: a check-in (feeling and her note in quotes; rose for
  irritation or a reaction, sage otherwise), a copy or deletion request (name and phone as the client typed them, and
  what to do), a form that could not be opened (rose, "Ask the client to send it again") or that waits for its client
  (peach), and "Health forms received" with a count. Each card has one secondary action ("Mark as handled",
  "Dismiss", "Got it") that clears it and acknowledges it on the server. Identifiers `alerts.mailbox.<itemId>[.action]`,
  `alerts.mailbox.imported[.action]`. A check-in photo shows under its text (180 pt tall, rounded, spoken "Photo the
  client sent"), from memory only.
- **2.10 BookingRequest, "Suggest another time"**: a tertiary button under the reason opens `SuggestTimeSheet` (graphical
  date and time picker in the business time zone, primary "Keep this time"); after the server held the time, an info
  notice and a primary `ShareLink` "Send the link" with a ready message. Identifiers `bookingRequest.suggestButton`,
  `bookingRequest.suggest.*`.
- **"Cancels often" on 2.9 and 2.10** (`CancelsOftenBadge`): the client list's coral dot and words, under the person's
  details on the waitlist and inside the request's summary card.
- **Accessibility (S12)**: `StepProgressBar` speaks through a 44 pt overlay; `BrandLockup` reads as one image; `MoreRow`
  title and subtitle wrap to every line.
- **4.3 ClientEdit, "Delete data"** (`ClientDeleteDataRow`): a coral `ActionRow` under Merge, a destructive
  confirmation ("Delete the data of Ana?") and an error alert; after it the Clients stack returns to the list.
  Identifiers `clientEdit.deleteDataRow`, `clientEdit.deleteDataConfirmButton`.
- **7.7 Privacy, "Booking form key"**: a neutral `MoreRow` at the end of "Where your data lives" with the key id the
  booking form shows in its footer (`privacy.inboxKeyRow`), hidden while the vault is locked.
- **Booking page error "key mismatch"**: `PublishFailureNotice` with Try again, when the page serves a form key that is
  not this iPhone's (`PublishFailure.keyMismatch`).
- **Recovery words while the screen is recorded or shared**: the words grid is replaced by a footnote ("Hidden while
  your screen is recorded or shared.") through the generic `hiddenWhileCaptured()` modifier (`SceneCaptureObserver`
  reads `UITraitCollection.sceneCaptureState`; SwiftUI has no environment value for it). The app-switcher snapshot was
  already covered by `PrivacyCover`.

### Client web app (S9, `web/`)

The web pages use the same tokens (generated into CSS variables by `web/scripts/gen-tokens.ts`); the screen inventory
of Bk-1 to Bk-11 and Cl-1 to Cl-9 and the per-screen gaps are in `docs/agent-notes/s9-web.md`. Changes from the
prototype that are not owner decisions (D45 to D52, D55 are listed there):
- **Waiting-list offer link** (`/{slug}/time?offer=<key>`): no screen of its own in the prototype. It opens on Bk-5
  with the kept service and time already chosen; while it loads, the page skeleton; an offer that ended (or a key
  that never existed, which looks the same) is a full-page state "This offer has ended." with "See free times".
- **Bk-1**: when she confirms new clients herself, an info notice says so up front ("New here? … confirms your first
  booking personally"); never a word about money or limits (D42).
- **Bk-8**: the "Complete your health form" card shows only when the booking's `intakeRequired` says so (first visit,
  or no form in 12 months); until the booking is read back it is not shown.
- **Cl-7**: the row is "Health form" (no "and consent", D55); the portfolio-photos row stays a read-only status (no
  server field for a client's choice).
- **Motion**: colour fades of chips, buttons and options run only under `prefers-reduced-motion: no-preference`.

### Smart slots (D56)

- **6.2 ServiceEdit, "Time around the visit"** (`ServiceTimingSection`, right after the basics card): native menu rows
  "Prep before" and "Clean-up after" (None, 5 to 60 min; `serviceEditor.prepMenu`, `serviceEditor.cleanupMenu`), a
  "Processing time" switch with its hint ("You're free while it works…", `serviceEditor.processingToggle`) and, only
  while it is on, "Processing lasts" and "Starts after" (`serviceEditor.processingMenu`,
  `serviceEditor.processingStartMenu`; "Right away" for 0). The menus offer only processing that fits the visit, and
  shortening the visit moves processing earlier, then shortens it, then turns it off (`ServiceRules.fittingProcessing`),
  so the form can never hold a shape the server rejects. Footnote: clients never see this time in the length or price.
- **Booking settings, "Booking rules"**: after the buffer, a "Start times" menu row (`bookingSettings.slotStepPicker`:
  Every 10, 15, 20, 30, 60 min, "Match the service" last) and a "Keep my day compact" switch with its hint
  (`bookingSettings.compactToggle`, on by default). Same `MenuPickerRow` and `ToggleRow` as the rows around them.
- **New appointment and Reschedule** (`SchedulingTimeSection`): the chips are the suggested times (her slot interval,
  the extra and processing time of each visit, the compact day); a "Show all times" text button
  (`<prefix>.showAllTimesButton`, rose text, 44 pt tall, VoiceOver hint) reveals the other free times in place and
  closes again on another day. "Another time" (any minute, with warnings) is unchanged.
- **Web Bk-4, Cl-3 rebook and Cl-9 reschedule** (`SlotChoices`): the same "Show all times" link
  (`data-testid="show-all-times"`, `link-button` style, 44 px tall) under the time list; a time already picked from
  the hidden ones keeps the list open.
- No new tokens.

### Navigation titles and long text (S11, localization)

- **Large titles only where they fit in all fourteen localizations** on the smallest supported iPhone (34 pt bold within
  343 pt). Tab roots keep large titles; settings-like pushed screens (Booking page, Cancellations and changes, No-show
  protection, Credentials, Privacy and security, Recovery key, Export all, Help), the request screens (2.10, 2.11) and
  long sheet titles use **inline** titles, as iOS Settings does. The prototype shows large titles; the German, French,
  Italian and Portuguese titles of these screens did not fit ("Pedido de agendamen…"). `NavigationTitleFitTests`
  measures every title and `check-strings.sh` keeps its lists in step with the screens.
- Shorter titles where the old one was a sentence: "Contraindications" for the picker (was "Not suitable if the client
  has"), shorter no-show and pause titles in es, fr, it.
- **Counts** read "Not back in 2+ months: 3 clients", "Ready for a follow-up: 2 clients": the counted noun follows the
  language's plural rules (`ClientTerm.countText`, Arabic six forms, German "Personen"), so the sentence needs no
  agreement.
- **Chips** keep a one-line label on one line (`FlowLayout` places them at their natural size; "12 hr" wrapped before).
- **5.8 Camera**: the preview and the "only saved in Bello" note scroll above the pinned bottom bar, and the bar
  (`FlowBottomBar`) always keeps the height its buttons need; at AX5 in German the 3:4 preview squeezed the capture
  button into one cut line. The booking link's accessibility label is the card title plus the address.
- The client terms in the plural are tab titles, so they are short: generic plurals in pt, es, it, fr ("convidados",
  "alunos"), "Kundschaft", "Patienten" and "Schüler" in German; profession names are fields, not gendered job titles
  ("Kosmetik", "Cabelo", "Acconciatura", "Coiffure").

### Release hardening (S12)
- **4.3 ClientEdit, "Export data"**: a peach `ActionRow` (share icon) right above "Delete data", opening 4.10
  ExportRecord as a sheet; the two answers to a data-subject request sit together, export first. Help ("A client asked
  me to delete her data") and Privacy ("From her profile, under Edit") now describe this screen.
- **7.6 Apple Calendar write-through**: switched on with full access, the app keeps a calendar named "Bello Hub" in her
  default calendar account, one event per visit (booked, confirmed, completed; cancelled and no-shows leave), from
  yesterday to 90 days ahead, no alarm, no notes. Titles are "Ana Costa · Glow Facial" only when Privacy lets names
  reach the lock screen; otherwise "Bello Hub appointment". Switching off or signing out removes the calendar.
- **1.1 Welcome**: "Continue with phone" shows only when the build can send a code (`supportsPhoneSignIn`); the v1
  Firebase provider cannot, so Release shows Sign in with Apple alone.

## Empty, loading and error states

Home, Calendar and Alerts use the shared `ScreenPhase` / `ScreenStateView` (loading skeleton, caller-defined empty
state, error with retry; precedence is one rule in `ScreenPhase`). An empty day on Home is an `EmptyState`.
The treatment flow, record history, incident and export define their own states (failed, missing, empty, saved). The Locked screen has an error state (`InlineNotice`): the face did not match, or this
phone has no key for her records. A vault that cannot be opened shows `StorageUnavailableView` and never offers to
erase anything. Each screen that loads data defines all three before it ships: a loading
state (`Skeleton`), an empty state with the next action (`EmptyState`), and an error state with a retry. Clients, the client profile, health and consent, tags and record fields (S4) have all three; their
errors keep what is on screen and offer "Try again". Offline
is a normal state: `OfflineBanner` informs and never blocks. S10: Plan (checking, none, active renews or ends,
grace; offers skeleton; store error with retry; purchased, restored, nothing to restore, pending, failed notices),
Export (idle, preparing, ready, error), Recovery key (masked, revealed, not recognized, no key, done), Delete account
(offer, confirm, deleting, done per outcome, error), Notifications (ask, denied, granted), Integrations (available,
connected, denied in Settings, coming soon). D55: the consent list has an empty text inside its card; a document
that cannot be read or is above 10 MB shows an error in the sheet.

## Accessibility

- Icon-only buttons have `accessibilityLabel`. Cards combine their children into one element. Touch targets are at least 44×44 pt.
- Every string is localized (`SupportFiles/Localizable.xcstrings`, source language `en`, fourteen localizations, see
  `docs/07-LOCALIZATION.md`). Strings no native has read are `needs_review`.
- Check light and dark, Dynamic Type to AX5, Increase Contrast, Reduce Motion and right-to-left before a feature is done.
- `LocalizationScreenshotUITests` (Full plan) renders the key screens in all fourteen localizations at the default size
  with no clipped text, checks Arabic mirroring (first tab and back button on the right) and runs a double-length
  pseudolanguage; with `TEST_RUNNER_SCREENSHOT_DIR` it saves `<localization>-<screen>.png` for native readers.
- Contrast: text 4.5:1, UI parts 3:1, measured by tests, never `.opacity` on text.
