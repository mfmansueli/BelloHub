# BelloHub design

Source of truth for the UI. Update it in the same change as the UI (see CLAUDE.md, section 4). The longer
specification is `docs/08-DESIGN-SYSTEM.md` (tokens) and `docs/09-MOTION.md` (motion); this file records what
is actually built and what was decided while building it.

## Identity

Graphite and orange (chosen by the owner on 2026-10-10, replacing the sage, rose and peach palette): pure neutrals,
an off-white page in light and a near-black one in dark, black and white text, and one vivid orange that marks the
primary action, links and the "next up" moments. Green only means confirmed or success, red only means attention; a
cool slate is the quiet third family. The color is rare on purpose, so it is noticed. Depth comes from tonal surfaces, two-layer neutral shadows and one memorable "hero" card per key screen,
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
The family names are kept from the earlier palette because a client tag stores `rose`, `sage`, `peach` or `sand` as
its color token, so renaming them would orphan saved tags. The name now means the role: **`rose…` is the orange
family, `sage…` the green, `peach…` the slate**, `sand` a neutral grey.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F4F4F3` | `#0E0E0E` | App background |
| `surface` | `#FFFFFF` | `#1A1A1A` | Neutral surface: cards, list cards, sheets |
| `sunken` | `#EDEDEB` | `#262626` | Elevated neutral surface: wells, input fill, quiet round buttons |
| `hairline` | `#DCDCD9` | `#3A3A3A` | Neutral separator and card border (decorative) |
| `ink` | `#141414` | `#F5F5F4` | Primary text |
| `ink2` | `#5A5A58` | `#ABABA8` | Secondary text, placeholders |
| `ink3` | `#858582` | `#7E7E7B` | Tertiary icons only, never text |
| `fieldBorder` | `#7A7A77` | `#858582` | Input and secondary-button borders (3:1) |
| `action` / `onAction` | `#E84A10` / `#141414` | `#FF6B33` / `#141414` | The one primary action (orange, near-black label); check discs, radios, filled progress |
| `selectionFill` / `selectionInk` | `#FFDCC9` / `#141414` | `#4A2414` / `#F5F5F4` | Selected chip, day, option (always with a `selectionInk` ring or a check); `selectionInk` is the tab bar tint |
| `sageFill` / `peachFill` / `roseFill` | `#C9E8D3` / `#D3D8E6` / `#FFC4A8` | `#1F4A30` / `#2A3045` / `#6A2E14` | Solid brand card and illustration fills, green / slate / orange (insight tiles, empty-state shapes, avatar gradient ends) |
| `onBrandCard` | `#141414` | `#F5F5F4` | Text on a brand card fill |
| `sageBadge` / `peachBadge` / `roseBadge` | `#FFFFFF` | `#163322` / `#222638` / `#4A2414` | Icon discs on a brand card; the icon is the family accent |
| `sageText` | `#1D6638` | `#8EDBA6` | Green icon/accent: confirmed, success, info |
| `peachText` | `#434A5E` | `#B5BCD8` | Slate icon/accent |
| `roseText` (= `accent`) | `#BF3E0A` | `#FF8A5C` | Orange icon/accent: links, action text, focus ring |
| `roseDeepText` | `#8F2E06` | `#FFC4A6` | Small text on deep orange washes, the "left" count |
| `sageWash` / `sageDeepWash` | `#E4F2E8` / `#D2EADA` | `#14291B` / `#1C3826` | Quiet tinted surfaces: chips, notices, icon squares |
| `roseWash` / `roseDeepWash` | `#FFECE2` / `#FFDCC9` | `#3A1D10` / `#4A2414` | Quiet tinted surfaces |
| `peachWash` | `#ECEDF3` | `#1F2230` | Win-back strip, slate icon squares |
| `rose`, `sage`, `ivory`, `brandMark` | `#FF5A1F`, `#2F8F5A`, `#FAFAF9`, `#6E8266` | `#FF5A1F`, `#4CC27A`, `#FAFAF9`, `#344B3C` | Brand identity: the logo orange (dots, glows), the confirmed green (switch track, success graphics), the mark |
| `peach` | `#8C95B3` | `#8C95B3` | Tag dot (slate) |
| `amberText` / `amberBg` | `#7A5C16` / `#F6ECD6` | `#E8CD85` / `#3B3118` | Pending, warnings (status only) |
| `coralText` / `coralBg` | `#AE2419` / `#FDE2E0` | `#FF9C92` / `#3A1816` | Needs attention, allergies, contraindications, destructive (status only); a clear red, never the brand orange |
| `neutralText` / `neutralWash` | `#4A4A48` / `#ECECEA` | `#D0D0CD` / `#2A2A2A` | Completed, quiet chips |

Every text token also has an Increase Contrast value (darker in light, lighter in dark). `onAction` turns pure black
with Increase Contrast; the `action` fill stays put, because a darker orange would lower the label's ratio.

Area namespaces: `StatusPalette` (`confirmed`, `pending`, `nextUp`, `completed`, `attention`; foreground,
background and dot), `AvatarPalette` (four gradient pairs chosen by a stable FNV-1a hash of the id; the ends are the
brand card fills, initials the deep family accent), `HeroPalette` (the hero surface, a neutral graphite `#262626` to
`#141414` in both appearances with an orange `#FF5A1F` glow at 34 % and a faint warm one, white text, `#D6D6D3`
secondary, `#3A3A3A` raised), `Elevation.tint` (`#1A1A1A`, a plain neutral shadow).

Roles are kept apart: brand identity, neutral surfaces and foregrounds, the primary action, selection, the brand
families (fill, badge, accent) and the semantic statuses. Amber and coral never become decorative, and peach or rose
never carry a safety warning.

Decisions, with the reason:

- **2026-10-10 graphite and orange**: the owner compared three directions (plum, petrol, graphite and orange) on the
  prototype canvas, in light and dark, and chose graphite and orange for both appearances. It replaces the
  sage, rose and peach refinement of the same day (`docs/tasks/color-refinement.md`, now historical). Only token
  values changed; names, roles, components and layouts did not.
- **The primary label is near-black, not white**: white on the orange is under 4.5:1, `#141414` is 4.8:1 in light and
  6.5:1 in dark. The light fill `#E84A10` is a shade deeper than the logo orange `#FF5A1F` so filled progress still
  reaches 3:1 on the page (3.5:1); in dark the fill is 6.1:1 on a card, so check discs there stand on their own.
- **The selection fill never carries the state alone**: `#FFDCC9` is 1.2:1 on the page, so a selected chip, day or
  option also gets a 1.5 pt `selectionInk` ring (16.7:1 on the page) or a check. The native glass tab bar draws its own
  selection pill; only its tint is `selectionInk` (black in light, near-white in dark).
- **Attention is red, not coral**: `coralText` moved to a clear red (`#AE2419`) so an allergy or a destructive action
  never reads as the brand orange. Amber is unchanged.
- **`fieldBorder` is darker than the separator** (3.9:1 / 5.2:1 on `bg`, 3.7:1 / 4.1:1 on the input fill): the
  separator `#DCDCD9` is decorative, a field boundary needs 3:1 (WCAG 1.4.11).
- **The hero's next-up dot is the logo orange**: 4.9:1 on the start of the hero gradient, 5.9:1 on its end.
- **The mark still uses the app icon's sage tile**: `BelloHub.icon` has not been redrawn for the new palette, and the
  mark in the app stays equal to the icon until it is (open: a graphite and orange icon). Its dot is the logo orange.
- **Secondary text on the hero is a solid `#D6D6D3`** (6.3:1 at the lightest glow point): no `.opacity` is ever
  applied to text.

Contrast, measured (text/background), light then dark: `ink`/`bg` 16.7 / 17.7, `ink2`/`bg` 6.3 / 8.4,
`onAction`/`action` 4.8 / 6.5, `selectionInk`/`selectionFill` 14.3 / 12.4, `onBrandCard` on green/slate/orange fills
14.0 / 12.9 / 12.0 and 9.3 / 12.0 / 9.6, badge icons on badges 7.0 / 8.8 / 5.4 and 8.4 / 8.0 / 5.8,
`roseText`/`surface` 5.4 / 7.5, `roseText`/`roseWash` 4.7 / 6.6, `sageText`/`sageWash` 6.0 / 9.4,
`peachText`/`peachWash` 7.6 / 8.4, `coralText`/`coralBg` 5.6 / 7.9, `roseDeepText`/`roseWash` 7.2 / 10.0,
`neutralText`/`neutralWash` 7.5 / 9.3, `fieldBorder`/`bg` 3.9 / 5.2, `ink3`/`bg` 3.4 / 4.7. Hero: white 9.2:1,
secondary 6.3:1 at the orange glow peak. With Increase Contrast every pair is at least as high (a test asserts it
never gets lower).

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
- **`HeroSurface`:** slow glow drift (28 s period), one sheen crossing, and on an animated hero (Home "next up") an orange "mist": a second fainter orange cloud (peak `HeroPalette.mistOpacity` 0.16) that roams on two periods (19 s across, 13 s up and down) and breathes (9 s). Runs only while on screen and active, stops after 60 s where it is, and never with Reduce Motion or Low Power Mode. Text on the hero is measured where the glow and the mist overlap (`HeroPalette.worstGlowOpacity`).
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
| `HeroCard` + `HeroSurface` | Graphite with an orange glow, radius 30, `e2`; one per key screen |
| `EmptyState` | Composed shapes in the illustration fills (`roseFill`, `sageFill`, `peachFill`), title, next action, optional primary button |
| `SheetHeader` | Title, subtitle, close button (optional `closeIdentifier`), for native sheets |
| `BelloTextField` | 52 pt, radius 14, `sunken`, 1.5 pt `fieldBorder`, 3 pt `roseText` focus ring, error text; `isSensitive` turns off autocorrection; `identifier` goes on the text field itself |
| `InlineNotice` | `.safety` (coral), `.info` (sage), `.warning` (amber) |
| `Skeleton`, `OfflineBanner`, `FooterNote`, `SuccessSeal` | See Motion for the seal |
| `BrandMark`, `BrandLockup` | The app icon itself, stacked from its own two layers (`BrandMarkRelief` and `BrandMarkFront` in the asset catalog, copies of `BelloHub.icon/Assets/Relief.png` and `Front.png`) over the icon's background (`BrandPalette`: orange `#E84A10`, near-black `#181717` in dark; ivory "b" `#FAF5EB`) in the rounded square of the icon mask. The 2026-10-11 icon (orange background, ivory "b" with a sage relief) replaced the earlier sage tile. Used on Locked (64 pt), the privacy cover (72 pt) and the lockup. The layers come from raster cut-outs of the approved reference, not vector files. The wordmark is the brand name, never localized, and always left-to-right |
| `ChoiceCard` | A tappable card for a profession or suggested service: selected is `surface` with a 1.5 pt `selectionInk` outline and an `action` check disc, unselected is flat `sunken`. One element for VoiceOver with the selected trait |
| `FittingRow` | Buttons side by side only while every label fits on one line, stacked otherwise; `fillsWidth` gives equal halves side by side and full width stacked. Decides by the labels, not the text size, so a word never breaks in the middle ("appointme / nt" on an iPhone 15 Pro at a large size). Follows the reading direction |
| `FittingGrid` | Cards in equal columns while every label fits its column on one line, one per row otherwise (profession cards, tag colors) |
| `FlowLayout` | Wraps chips into rows and follows the reading direction (rows start on the right in Arabic); `wrapsLongChildren` lets a chip with a long label wrap instead of overflowing |
| `StepProgressBar` | One 4 pt segment per step, filled in `action` up to the current one (`hairline` after it); spoken as "Step n of m" |
| `ToggleRow` | Title, optional line, the native `Toggle` tinted `sage` |
| `BelloNoteField` | Multi-line field with the same look as `BelloTextField` (S4) |
| `TagDot` + `TagColor` | The tag color as a pastel fill inside a ring in the family's text tone; four tokens `rose`, `sage`, `peach`, `sand` (wash, text, dot, outline each), unknown tokens read as `sand`; the ring is 3:1 or more on `surface`, `bg` and `sunken` (`TagColorContrastTests`) |
| `ErrorNotice` | An error line with an optional "Try again", for a read or save that failed (S4) |
| `GlowBackdrop` | The page color with an orange glow (`rose`) from the top leading corner (300 pt) and a faint warm one (`HeroPalette.glowSage`) from the top trailing corner (240 pt), peak 16 %. Only `ink`, `ink2` and `coralText` may sit on a glow (`BackdropContrastTests`); `roseText` links live lower, on the plain page color |
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

Home's two starts, "New booking" and "Register visit", sit side by side under the greeting as `belloSecondary` buttons
(stacked at the accessibility sizes); the next visit card keeps the screen's one primary action.

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
| 1.4 Your first service | `Steps/ServicesStepView` | shared (`OnboardingProgressStore` keeps it across a relaunch) | `onboarding.services.firstMenu`, `onboarding.services.durationMenu`, `onboarding.services.priceField`, `onboarding.services.choice.<key>`, `onboarding.services.custom.<id>`, `onboarding.services.addCustomButton` |
| 1.5 CustomService (sheet) | `Onboarding/CustomServiceSheet` | local `@State` | `customService.nameField`, `categoryField`, `priceField`, `durationMenu`, `followUp.<weeks>`, `photosToggle`, `aftercareToggle`, `addButton`, `cancelButton` |
| 1.6 Terminology | removed from the setup (routine-a): the word for clients is in 7.2 | | `languageRegion.clientTermMenu` |
| 1.7 Tags | removed from the setup (routine-a): defaults stored, edited in More, Tags | | |
| 1.8 Record | removed from the setup (routine-a): defaults stored, edited in More, Record fields | | |
| 1.9 Permissions | removed (routine-a): each permission is asked when its feature is used; notifications from Home once a visit is coming | | `home.today.notificationsButton` |
| 1.10 Ready | `Steps/ReadyStepView` | shared | `onboarding.ready.title`, `onboarding.ready.continueButton`, `onboarding.ready.error` |
| 1.11 Locked | `Screens/Locked/LockedView` | none (reads `AppLockService`) | `locked.title`, `locked.unlockButton`, `locked.passcodeButton`, `locked.error` |
| 2.1 Home | `Screens/Home/HomeView` -> `HomeContentView` (`HomeNextVisitCard`, `HomeTodayCard`, `HomeRecordsCard`, `HomeVisitRow`, `HomeReachOutCard`, `HomeCountRow`) | `HomeViewModel` (reads `AgendaDigestService`, `FollowUpQueueService`; `HomePending`, `RecordPending`, `HomeReachOut`) | `home.*`, `home.quick.newAppointment`, `home.quick.registerVisit`, `home.records[.<kind>:<id>, .seeAll]` |
| Choose client (sheet, from "Register visit") | `Screens/Shared/ClientRecord/ClientPickerSheet` | none (filters `AgendaDigestService.clients` with `ClientSearch`) | `clientPicker.list`, `clientPicker.client.<uuid>`, `clientPicker.empty`, `clientPicker.cancelButton` |
| Time-zone notice (Home card, Calendar row) | `Screens/Shared/TimeZoneNotice/` (`TimeZoneNoticeView` -> `TimeZoneNoticeContent`, `TimeZoneNoticeCard`, `TimeZoneNoticeRow`, `Support/TimeZoneNoticeText`) | `TimeZoneNoticeViewModel` (reads `TimeZoneNoticeService`, `ProfileService`, `BookingSetupService`; rule `Models/Business/TimeZoneMismatch`) | `home.timeZoneNotice[.message, .regionNote, .usePhone, .keep, .languageRegion, .error]`, `calendar.timeZoneNotice[.usePhone, .keep, .languageRegion, .error]` |
| 2.7 To reach out (2.8 Win back is its "Not back" filter) | `Screens/FollowUps/` (`FollowUpRowCard`) | `FollowUpsViewModel` (`FollowUpQueue`, `FollowUpAction`) | `followUps.*` (`followUps.filter.<filter>`, `followUps.row.<client>`, `followUps.reason.<occurrence>`, `followUps.action.<occurrence>`) |
| Client message (sheet, `AgendaSheet.clientMessage`) | `Screens/Shared/ClientMessage/` | `ClientMessageViewModel` (`ClientMessageComposer` is pure; nothing is sent by the app, D14) | `clientMessage.*` |
| 7.11 Shared states | `Screens/Shared/States/` (`ScreenPhase`, `ScreenStateView`, `ListLoadingView`) | none | caller-defined |
| 2.2 Clients | `Screens/Clients/ClientsTabView` (stack, `ClientsRoute`) + `ClientsView` | `ClientsViewModel` | `clients.empty`, `clients.row.<uuid>`, `clients.filter.<chip>`, `clients.newButton`, `clients.importButton` |
| 4.1 Client record (the center of a client) | `Clients/Profile/ClientProfileView` (`ClientProfileHero`, `ImportantNoteCard`, `SessionPlanCard`, `ClientRecordSectionPicker`; sections `History/`, `Photos/`, `Info/`, `Documents/`); pushed from the agenda as `Screens/Shared/ClientRecord/ClientRecordScreen` | `ClientProfileViewModel` (`ClientTimelineBuilder`, `ClientTimeline`, `VisitSummary`, `PhotoGroup` are pure) | `clientProfile.*`, `clientRecord.registerButton`, `clientRecord.sections`, `clientRecord.menu[.edit, .book, .incident, .export]`, `clientRecord.history`, `clientRecord.visit.<id>`, `clientRecord.booking.<id>`, `clientRecord.pending.fill.<id>`, `clientRecord.unlinked[.organize]`, `clientRecord.photos[.filter.<id>, .compare, .photo.<id>]`, `clientRecord.info`, `clientRecord.documents[.sharingCard, .portfolioCard, .manage]` |
| Visit details (pushed, `RecordRoute.visit`; sheets: Use as base, Visit day) | `Screens/Records/Visit/` (`VisitDetailHeader`, `VisitPhotosCard`, `VisitFieldsCard`, `VisitLinksCard`, `ReuseVisitSheet`, `VisitDaySheet`) | `VisitDetailViewModel` (+ corrections, visit day; `RecordCurrentValues`, `VisitReuse`, `RecordTrailBuilder` pure) | `visitDetail.*`, `reuseVisit.*`, `visitDay.*` |
| Organize photos (sheet, `RecordSheet.organizePhotos`) | `Screens/Records/Organize/` | `OrganizePhotosViewModel` | `organizePhotos.*` |
| Compare photos (sheet) | `Screens/Records/Components/PhotoCompareSheet` | none | `photoCompare.*` |
| Personalization (More, Clients) | `Screens/Personalization/PersonalizationView` | none (reads `OptionCatalogService`) | `personalization.*` |
| Add option (sheet from "+ Add") | `Screens/Shared/Options/OptionAddSheet`, `AddOptionChip` | none (`OptionNameRules` pure) | `optionAdd.*` |
| 4.2 NewClient (sheet) | `Clients/Form/NewClientView` | `ClientFormViewModel` | `clientForm.*` (inline "already saved" notice, D42 counter) |
| 4.3 ClientEdit (+ merge sheet) | `Clients/Form/ClientEditView`, `ClientMergeSheet` | `ClientFormViewModel`, `ClientMergeViewModel` | `clientEdit.*`, `clientMerge.*` |
| 4.4 ClientKnowledge | `Clients/Knowledge/ClientKnowledgeView` | `ClientKnowledgeViewModel` | `clientKnowledge.*` |
| 4.5 ClientHealth "Health and consents", a folder (+ patch test and record sheets; the record sheet keeps health forms and consents) | `Screens/Health/ClientHealthView`, `Health/Sheets/` | `ClientHealthViewModel`, `PatchTestViewModel`, `ConsentRecordViewModel` | `health.*`, `patch.*`, `consent.*` (D55, D60) |
| 4.6 ImportClients (sheet: sources, contacts, column mapping, result) | `Clients/Import/ImportClientsView` | `ImportClientsViewModel` | `importClients.*`, `onboarding.ready.importButton` |
| 6.1 Services (+ 6.2 ServiceEdit sheet, 6.3 AddOns pushed) | `Screens/Services/ServicesView` -> `ServicesContentView`, `AddOns/` | `ServicesViewModel`, `AddOnsViewModel` | `services.*`, `serviceEditor.*`, `addOns.*` |
| 6.4 Products | `Screens/Products/ProductsView` | `ProductsViewModel` | `products.*` |
| 6.10 Credentials (+ preview sheet) | `Screens/Credentials/CredentialsView` | `CredentialsViewModel` | `credentials.*` |
| 6.11 Team (static, D5) | `Screens/Team/TeamView` | none | `team.*` |
| 6.5 Availability (+ hours, break, days-off sheets) | `Screens/Availability/AvailabilityView` | `AvailabilityViewModel` | `availability.*` |
| 6.7 BookingSettings (+ pause sheet) with 6.8 ShareLink, 6.16 CancelPolicy, 6.15 NoShowPolicy, Where you work (design addition, 2026-10-11) | `Screens/BookingSettings/` (`Workplace/`) | `BookingSettingsViewModel`, policy and share view models, `WorkplaceViewModel` (`BusinessLocationFormat`, `WorkplaceCountries` pure) | `bookingSettings.*` (`.workplaceRow`), `shareLink.*`, `cancelPolicy.*`, `noShowPolicy.*`, `workplace.*` (`.streetField`, `.postalCodeField`, `.cityField`, `.countryPicker`, `.directionsField`, `.tooLong`, `.visibility.<confirmedClients|bookingPage>`, `.preview.address`, `.preview.empty`, `.map.apple`, `.map.google`, `.saveButton`, `.removeButton`, `.removeConfirmButton`, `.saveError`) |
| 6.9 QuickReplies (+ editor sheet) | `Screens/QuickReplies/QuickRepliesView` | `QuickRepliesViewModel` | `quickReplies.*` |
| 6.12 Tags (+ tag sheet) | `Screens/Tags/TagsView` | `TagsViewModel` | `tags.*`, `tagEditor.*` |
| 6.13 RecordTemplate (+ field sheet, services sheet) | `Screens/RecordTemplate/RecordTemplateView` (`FieldServicesSheet`) | `RecordTemplateViewModel` | `recordTemplate.*` (`.required.<key>`, `.services.action.<key>`, `.services.<id>`, `.services.all`), `fieldEditor.*` |
| 6.14 FormTemplates | `Screens/Health/FormTemplates/FormTemplatesView` | `FormTemplatesViewModel` | `formTemplates.*` |
| 2.3 Calendar (day timeline + list, week grid + agenda), 2.6 WeekGlance, 3.1 NewAppointment, 3.4 Reschedule, 6.6 BlockTime | `Screens/Calendar/` (rules in `Calendar/Support/`) | one view model per screen; `TimeBlockService` | `calendar.*`, `newAppointment.*`, `reschedule.*`, `blockTime.*` |
| 3.2 Appointment (pushed, `AgendaRoute.appointment`; the client's name opens her record, `AgendaRoute.clientRecord`; previous visit card; Register visit / Continue record / Open record), 3.3 BeforeYouStart (last visit with photos, "Remember today", what was written; complete then "Register now" or "Later"), 3.5 Cancel, 3.6 MessageClient, 3.7 NoShowMark, 2.12 RunningLate (sheets), 4.8 SessionPlan, 4.11 NoShowHistory (pushed) | `Screens/Appointments/` | one view model per screen; `MessageService` behind `MessageSending` | `appointment.*` and one prefix per sheet |
| 2.4 Alerts | `Screens/Alerts/` (`AlertsContentView`, `AlertCard`, `RecordPendingAlertCards`, `NotificationPermissionNotice`) | `AlertsViewModel` (`AlertsList`, `InboxAlerts` and `RecordPending` are pure) | `alerts.*`, `alerts.request.<bookingId>[.action]`, `alerts.reschedule.<requestId>[.action]`, `alerts.waitlist[.action]`, `alerts.records.<kind>:<id>[.action]` |
| 2.10 BookingRequest, 2.11 RescheduleRequest, 2.9 Waitlist (pushed, `AgendaRoute.bookingRequest` / `.rescheduleRequest` / `.waitlist`) | `Screens/Inbox/` (`RequestSummaryCard`, `RequestAnswerBar`, `RequestOutcomeNotice`, `WaitlistPersonRow`) | one per screen over `BookingSyncService` (`InboxRequestPhase`, `RescheduleTiming` pure; `WaitlistBoard` in `Models/Inbox`) | `bookingRequest.*`, `rescheduleRequest.*` (`.client`, `.note`, `.time` / `.current` / `.requested`, `.reason`, `.unverified`, `.resetCountToggle`, `.acceptButton`, `.declineButton`, `.outcome`, `.needsPlan`, `.seePlansButton`, `.historyButton`, `.timing`, `.slotTaken`, `.missing`), `waitlist.*` (`.openTime`, `.person.<id>`, `.offer.<id>`, `.offerAllButton`, `.slotTaken`, `.empty`, `.error`) |
| 5.1 to 5.9 Visit form (`fullScreenCover`, own stack: the one-screen form with drafts at the root; Listening, Organizing, Review, Camera, Saved and the record pushed on it) | `Screens/Treatment/` (`Steps/VisitFormStepView`, `Form/VisitDetailsCard`, `Form/VisitPhotosSection`, `Form/VisitAutosaveStatus`, `Form/VisitNextSessionPicker`, `Steps/SavedStepView`) | `TreatmentFlowViewModel` (+ draft, photos, options, review, voice; `TreatmentRecordBuilder`, `TreatmentDraftLoader`, `VisitFormSections` pure); voice and AI behind `VoiceCapturing` / `RecordStructuring` (unavailable stubs in v1, D53) | `treatmentFlow.*`, `visitForm.*` |
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
    │                Register visit → Choose client (sheet) → visit form (fullScreenCover)
    │                To follow up → visit form of a draft or of a completed booking with nothing written
    ├── Clients   → ClientsTabView → ClientsView (title = the term she chose; sheets: NewClient, ImportClients)
    │                → Client record (History · Photos · Information · Documents) → Visit details (sheets: Use as
    │                  base, Visit day, Incident; → the visit form to complete it) · ClientEdit (sheet: merge) ·
    │                  ClientKnowledge (sheet: Add option) · ClientHealth (sheets: health form, patch test, consent
    │                  record with its visit) · RecordHistory (sheets: Incident, ExportRecord, Organize photos)
    │                NewClient / Import at the 11th registration → Paywall sheet (the Plan screen, D42)
    │                Start (appointment or profile) → TreatmentFlow (fullScreenCover)
    ├── Calendar  → CalendarView (day | week) → Appointment → Client record · Visit details · SessionPlan ·
    │                NoShowHistory; WeekGlance; visit form (fullScreenCover)
    │                (sheets through `AgendaSheet`: NewAppointment, Reschedule, BlockTime, BeforeYouStart, Cancel,
    │                MessageClient, NoShowMark, RunningLate, ClientMessage)
    ├── Alerts    → AlertsView → BookingRequest (sheet: Paywall; → NoShowHistory) · RescheduleRequest · Waitlist;
    │                Records to complete → visit form (fullScreenCover)
    └── More      → MoreTab → MoreView: Business (Services → Add-ons, Products, Booking page → Share link · Where you work · Cancel policy · No-show policy, Availability, Credentials, Team; S5),
                     Clients (Record fields → Services sheet, Forms, Tags, Personalization), Messages (Quick replies; S5),
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

### Changes from D60 (health forms are her own papers too)

- **4.5** is a folder. First section "Health forms": the same list card as the consents (label or "Health form",
  Signed / Not signed chip, date, "Photo kept"), an "Add health form" row, a footnote that the app asks no health
  question and nothing leaves the iPhone, and under it "Review every 12 months" with the review chip, counted from the
  last signed health form. The empty folder says to use her own form, sign it with the client and keep a photo or file.
  The in-app questionnaire and its "Fill in the form" button are gone. Answers recorded in the app before D60, or sent
  from the booking page, show read-only under "Answers recorded in the app". Then "Consents" (every kind but health
  form) and the patch test log. The record sheet adds the "Health form" kind first and reads "New health form" /
  "Health form" for it.

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
- **2.10 BookingRequest, "Not verified"** (verify-fallback): a request the client made with "Confirm on WhatsApp"
  (the e-mail code never arrived) shows a coral `InlineNotice` (safety style) above the reason: title "Not verified",
  message "The client could not receive the code. Check that the WhatsApp message came from <phone> and quotes the
  reference <K7M2P>." (phone and reference isolated left-to-right), then a meta line "If you do not answer, the time
  opens up again on <date, time>." No "new client" notice is guessed when the server gave no reason; a server reason
  (no-show limit, free registrations, her switch) still shows below it. Approve and Decline are unchanged; the badge
  goes with the answer. Rule: `UnverifiedRequestBadge` (`Screens/Inbox/BookingRequest/Support/`). Identifiers
  `bookingRequest.unverified`, `bookingRequest.unverified.releases`.
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
- **Bk-6, the code does not come** (verify-fallback): under the lead line a tertiary "Change email" opens an inline
  e-mail field with "Send the code to this email" (primary, inline) and "Cancel" (tertiary); the code field hides while
  it is open. After the first 30 s wait (or after a resend) a quiet link-button "I didn't get the code" appears under
  the resend row and opens a `Sheet` "No code yet?": the spam-folder sentence with the address, the resend control,
  a secondary "Change email", and, only when the professional has a public WhatsApp number, a `well` section "Still
  nothing?" with one primary "Confirm with <Name> on WhatsApp" (busy while it sends; errors as `ErrorNotice`).
  Identifiers `change-email`, `new-email`, `save-email`, `cancel-email`, `no-code`, `no-code-sheet`, `help-spam`,
  `help-resend`, `help-timer`, `help-change-email`, `help-whatsapp`, `confirm-whatsapp`.
- **Bk-10, unverified version**: amber seal, title "Now message <Name> on WhatsApp", the line "Your request is saved,
  but nothing is booked yet…", a card "Your reference" with the code in the `moment` style (left-to-right in every
  language) and the service and time under it, a quiet notice with the release time, and the bottom bar's primary
  link "Send the message on WhatsApp" (`wa.me` with the prefilled message). WhatsApp opens on the client's tap only:
  an automatic jump after the network call is blocked by in-app browsers and would lose the page. Identifiers
  `reference-card`, `reference`, `request-expires`, `send-whatsapp`.
- **Bk-5 for a returning client**: with a trusted device for the same address the "Send verification code" button
  goes straight to Bk-7 (no visual change); when the server wants the code after all, Bk-6 opens as usual.
- **Bk-9, "Forget this device"**: only when this browser keeps a trusted-device token for the page, a centred meta
  line ("This browser remembers your email…") with a link-button under "My data"; after the tap a quiet notice
  "Done. Next time this browser will ask for a code." Identifiers `forget-device`, `device-forgotten`.

### Smart slots (D56)

- **6.2 ServiceEdit, "Time around the visit"** (`ServiceTimingSection`, right after the basics card; since routine
  item 10 a disclosure "Extra time (optional)", see below): native menu rows
  "Prep before" and "Clean-up after" (None, 5 to 60 min; `serviceEditor.prepMenu`, `serviceEditor.cleanupMenu`), a
  "Processing time" switch with its hint ("You're free while it works…", `serviceEditor.processingToggle`) and, only
  while it is on, "Processing lasts" and "Starts after" (`serviceEditor.processingMenu`,
  `serviceEditor.processingStartMenu`; "Right away" for 0). The menus offer only processing that fits the visit, and
  shortening the visit moves processing earlier, then shortens it, then turns it off (`ServiceRules.fittingProcessing`),
  so the form can never hold a shape the server rejects. Footnote: clients never see this time in the length or price.
- **Booking settings, "Booking rules"** (since routine item 10 both under "More options", see below): a "Start times" menu row (`bookingSettings.slotStepPicker`:
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

### Routine simplification, items 9 to 11 (2026-10-11, `routine-b`)

- **4.6 Import, choose step**: "Before you import" (`ImportPlanSummary`) is the first section of the list, under the
  "Choose clients" header with its controls and above the people, at every text size: label/value rows in a `ListCard` ("New registrations", "Already in your list
  (skipped)", "Free registrations left: 3 of 10", and, when part of the group waits, "Registered now" and "Waiting
  for a plan"), then one `InlineNotice` sentence: `.info` when everyone new fits or she has a plan, `.warning` when
  part or all waits ("The rest are not saved and nothing is charged…") or nobody is new. Label/value rows avoid
  plural agreement in fourteen languages; at accessibility sizes the value goes under its label; each row is one
  VoiceOver element (label + value). Rows already in her
  list say so under the name (`footnoteStrong`, `ink2`) and start unticked. Header: a native `Menu` "Try a small
  group" ("First 3 / 5 / 10 new", plus the free count when smaller) beside Select all. The amber partial-import box
  of S4 and its accessibility-size footer are gone; the bottom bar is the count and the button. Identifiers
  `importClients.plan.{new,duplicates,freeLeft,now,waiting,outcome,unchecked}`, `importClients.trialMenu`,
  `importClients.trial.<n>`.
- **4.6 Import, result**: under "n more need a plan" a line says they were not saved and nothing was charged; after
  the paywall closes with a plan, the "See plans" button becomes "Import the rest (n)"
  (`importClients.result.importRestButton`, `.belloSecondary`).
- **6.7 Booking page, "Booking rules"** is progressive: a "Suggested for: Hair stylist" card (`belloCard`, three
  value lines, "Use these" `.belloSecondary`, `bookingSettings.suggestion.useButton`) only while her values differ
  from her profession's; then the basics card (hours, time between clients, minimum notice, booking window,
  cancellations, no-show); then a native `DisclosureGroup` "More options" (`bookingSettings.moreOptions`, rose
  chevron) with "Start times" and "Keep my day compact", open by itself only when one is not at its default. Each
  menu row has a footnote example from the routine (`MenuPickerRow.hint`, `footnote`, `ink2`).
- **6.7 "What clients see"** (`SlotPreviewSection`, after the rules): a card with an optional native service menu
  (`bookingSettings.preview.servicePicker`, only with two or more services), a caption (day, service, "Already
  booked in this sample: Haircut at 10:00"), "Shown first" time chips (`selectionInk` on `selectionFill`, the
  selected-chip pair; not buttons; one VoiceOver element reading the list), "Also bookable, one tap away: …" in
  `ink2`, and a footnote that notice and window are not applied. Empty: "No free times…"; no hours: "Add your
  working hours…". Recomputed on the phone at each change.
- **6.2 Service editor**: "Extra time (optional)" is a native `DisclosureGroup` (`serviceEditor.timingDisclosure`),
  closed unless the service has prep, clean-up or processing; under the card, the owner's example ("a 75-minute
  color with 30 minutes of processing lets you fit a 20-minute bangs trim inside it").
- **5.8 Camera, framing reference**: when the client has an earlier photo, it lies over the preview (default 35 %)
  with thin `ivory` rule-of-thirds lines (`FramingGuides`, decorative, VoiceOver-hidden; over a live picture no fixed
  contrast can be measured, which is why they only help and never carry meaning). The native switch "Show previous
  photo" (`treatmentFlow.camera.referenceToggle`) and, while it is on, "How visible" with a slider 15 to 60 %
  (`treatmentFlow.camera.referenceOpacity`, value spoken as a percentage) sit in the pinned bar above "Take photo", so
  they are on screen without scrolling on every iPhone (on a 6.1-inch screen the 3:4 preview fills the view and a card
  under it was hidden behind the bar); at large text the bar grows and the preview scrolls. The two-line guide stays
  under the preview while the reference shows. The old "Ghost" bar button is gone. Evaluation:
  `docs/agent-notes/photo-framing.md`.
- No new tokens and no new text/background pairs (every pair above is an existing measured one).

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
- **No word breaks in the middle**, in any language or text size: pairs of buttons use `FittingRow` and card grids
  `FittingGrid`, which stack when a label does not fit whole; wrapping between words is fine. The old rule (stack
  only at accessibility sizes) cut "New appointment" on Home at a large size.
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

### Routine simplification A (2026-10-11, `docs/agent-notes/routine-a.md`)
- **App language (item 1).** 7.2 Language and region opens with "App language": a native menu with "Same as iPhone"
  and the fourteen localizations in their own names, applied at once (no Save) with a footnote that texts iOS draws
  (permission requests) follow at the next launch. The old picker is the language of her messages and page. The
  interface locale is injected at the root (every stage, sheet, alert, menu, the lock screen and the privacy cover);
  the tab view is rebuilt on a change so navigation titles and tab names follow, and `MainNavigation` keeps the selected
  tab and the More stack (also across a lock). What she wrote is never translated.
- **Lock screen logo (item 2).** `BrandMark` is the official icon (see Components).
- **Setup (item 3).** Three counted steps and Ready: About you, Profession, **Your first service** (1.4: the
  profession's most common service in a native menu, its duration menu, an optional price whose placeholder is zero
  in the region's currency; other suggestions as optional `ChoiceCard`s; "Add your own"). Terminology, Tags, Record
  and Permissions (1.6 to 1.9) are no longer steps: the catalog's defaults are stored, the word for clients is a menu
  in 7.2 "Words the app uses", tags and record fields are in More; Ready says so in a quiet `FooterNote`. Progress is
  saved after every change and the setup resumes on the same step after a relaunch.
- **Home (item 4).** "New appointment" is a toolbar button (title and icon) in the navigation bar, one tap away on
  every day. Order: greeting; next visit hero or the clear-day `EmptyState` (no button of its own now); **Today**
  (`HomeTodayCard`: booking requests to answer, which switch to Alerts; reminders ready to send; visits to finish
  closing; the notification offer, only while the system was never asked and a visit is coming); the rest of today;
  **To reach out** (`HomeReachOutCard`: the first two clients with their reason, and "See everyone" with the count);
  the week row (`HomeCountRow`, open slots). Removed: the three tiles, the follow-ups card, the win-back link, the
  "Reminders ready" list and the quick actions section (every destination is still reachable).
- **Follow-up queue (items 5, 6, 12).** 2.7 is now "To reach out" (`FollowUpsView`, large title): a subtitle, booking
  requests kept apart in one labelled row that opens Alerts, filter chips (All, Reminders, After visits, Returns, Not
  back, Birthdays, each with its count), one `FollowUpRowCard` per client with every reason (the plain sentence of
  `FollowUpReasonText`, the message state line, the main action, "I sent it" once a chat was opened, "Book" for returns
  and not back, and a native menu with "Later (one week)" and "Dismiss"), a collapsible "Set aside" section with "Bring
  back", and a footer that says where the suggestions come from. 2.8 Win back is the queue on "Not back". Message
  states: "Ready to send", "Conversation opened … Opening WhatsApp does not confirm the message was sent.", "Marked
  as sent by you, …". Alerts (2.4) keeps requests, mailbox and the visit that starts soon, and replaces the reminders
  list and the follow-up, win-back and birthday cards with one "To reach out" card.
- **Visit detail reminder line (item 6).** 3.2's amber line says "Conversation opened …" or "Marked as sent by you, …"
  and "No answer from the client yet.", with "I sent it" while only the chat was opened and "Remind again".
- **Visit closing (item 7).** After Save the treatment flow shows a `StepProgressBar` "Step n of 4" (`ClosingProgress`)
  on Saved (1), Photos (2), the new **Aftercare** step (3: the record's aftercare text in a `BelloNoteField` while the
  record can be edited, read-only with an info notice and the way to the history once locked, and "Send the aftercare
  message" through the visit's message sheet with a note that the message never carries the record's words) and Next
  visit (4: "Save suggestion" only while the record can be edited). Saved's bottom bar is "Continue" with a line saying
  the next steps are optional; its toolbar button is "Finish later" while a step is open ("Done" once all are settled).
  Every step has Skip or Continue; a visit left with Finish later is listed in the queue ("Continue" resumes it on the
  first open step, "Mark as done" in its menu).
- **Manual record (item 8, non-AI part).** The form shows the observations, the record's own fields (technique,
  products, result, aftercare) and the first two of her own fields; the rest are in a native `DisclosureGroup` "More
  fields" with the count, unless already answered. A chip "Same as last visit, <date>" fills only empty fields from the
  client's last record of the same service. The voice and AI presentation (Register screen, AI settings) is unchanged:
  deferred by the owner.

### Time-zone notice (2026-10-11, `docs/agent-notes/tz-mismatch-notice.md`)
- **When.** The iPhone's zone shows another hour than the business zone *right now* (`TimeZoneMismatch`: offsets at
  `now`, not identifiers, so Rome and Paris, or São Paulo and Buenos Aires, say nothing). Never during setup (no
  profile yet), never once she kept that pair of zones, and in UI tests only with `-uiTimeZoneNotice`.
- **Home.** Under the greeting, before the day: a `belloCard()` with a decorative globe (`ink2`), the sentence "Your
  iPhone is on Rome time, but your business uses São Paulo time." (`bodyStrong`, `ink`), then in `meta` / `ink2` the
  difference ("Your iPhone is 5 hr ahead of your business."), "Your calendar and your booking page follow the business
  time zone." and, when the iPhone's zone belongs to another region preset, "Your region and currency do not change
  automatically.". The text is one VoiceOver element naming both zones. Then "Use my iPhone's time zone"
  (`belloSecondary`, full width, a spinner while saving; Home's primary action stays the toolbar button) and two
  `belloTertiary` buttons, "Keep it" and "Language and region" (side by side, stacked when they do not fit: AX sizes).
  A failed save shows `ErrorNotice` inside the card. Every pair is on `surface`, already measured; no new color.
- **Calendar.** A quiet line pinned under the header (it scrolls with the header at AX sizes): globe, "Times are in
  São Paulo time. Your iPhone is on Rome time." in `meta` / `ink2`, a `chevronUpDown`. It is the label of a native
  `Menu`: a section titled with the difference (use the iPhone's zone, keep it) and a section with "Language and
  region", titled with the region note when it applies. 44 pt minimum height.
- **Names.** Zones are named by their city in the interface language (`Formatters.zoneName`: CLDR exemplar city,
  "Roma", "روما"); a zone without a city reads as its offset ("GMT-03:00"). Differences use `Formatters.duration`.
- **Motion.** "Keep it" fades the notice out (`Motion.Duration.fade`, kept under Reduce Motion, none in UI tests).
- **Nothing changes without her tap.** "Use my iPhone's time zone" saves the profile's zone and re-saves her stored
  hours with that zone (same wall-clock hours, same day-off dates); the page republishes by itself if it is online.
  "Language and region" opens 7.2 in the More tab.

### Client messages and location (2026-10-11, `docs/agent-notes/client-messages-location.md`)
- **Links in messages.** Every link a client reads is the full `https://` address on a line of its own, nothing glued
  after it, never inside bidi isolates (`ClientLinkText`, applied by `QuickReplyRenderer`, so replies she wrote
  earlier come out clickable too). The short `bellohub.app/maria` stays only where she reads it herself: the link card,
  the QR caption, the printed table card and the Instagram bio line.
- **3.6 Message <client>.** Under the preview, a quiet line in `meta` / `ink2` with an icon (`check` for her client's
  own link, `link` otherwise) says which link the message carries: "The link lets Ana change or cancel this visit.",
  or her booking link and why (added by hand, no longer ahead, offline: Open tries again, could not be prepared).
  While the server prepares the client's own link the line is a `ProgressView` with "Preparing the link…" and Open
  waits (disabled). Shown only when the selected message has `{link}`. Identifiers `messageClient.linkNote.<manage |
  addedByHand | notActive | offline | failed | preparing>`.
- **Quick replies.** A sixth word chip, `{address}`: her address lines, the "how to find us" note and a Google Maps
  link on lines of their own; without an address the word and its line disappear. The built-in "Confirm appointment"
  and "Reschedule" carry it and end with the link on its own line.
- **2.9 Waitlist.** Once the server holds the time for a person, the row shows "Send" (`belloChip`, `waitlist.send.<id>`,
  "Send again" after the chat opened) that opens WhatsApp with the offer and its one-time link; the share-sheet card
  (`ShareFallbackCard`, `waitlist.shareFallback`) when no chat app opens.
- **Where you work** (Booking settings, design addition). A "Where you work" `SettingsSection` with one `MoreRow`
  (`mapPin` icon on the rose tile) whose subtitle is the saved address on one line and who sees it, or "Not added yet".
  The pushed screen (inline title) stacks: the subtitle, the four `BelloTextField`s (street and number, postal code,
  city) and a country row with the native menu `Picker` (her business region first), the `BelloNoteField` "How to find
  us (optional)"; "Who sees it" as two `ChoiceCard`s (only clients with a confirmed booking, the default; also on my
  booking page, with the warning that anyone sees it); "What clients see", a `surface` card with the lines
  (`bodyStrong` / `ink`), the note (`meta` / `ink2`) and two `Link`s "Apple Maps" and "Google Maps" (`metaStrong` /
  `roseText`, 44 pt, side by side or stacked by `ViewThatFits`); Save (`belloPrimary`, "Saved" when nothing changed) and
  Remove address (`belloSecondary`, destructive, confirmation dialog); a lock `FooterNote`. Every pair is already
  measured (`BookingSetupContrastTests`). Audited in en and pt-BR at the default size and AX5.
- **Web.** The management page says "Change or cancel" right under the booking card (heading, then Reschedule and
  Cancel and the policy note); "Add to calendar" moved to its own card below. A `PlaceCard` ("Where", the lines in
  `<bdi>`, the note, "Open in Apple Maps" / "Open in Google Maps" as 44 px links) on the confirmation and the
  management page when the booking may see it, and on the booking page when she made it public.
- **E-mails.** The HTML part uses the web tokens (ivory page, graphite text, `rose-text` links, a `surface` place box,
  an `action` button with `on-action` text, all at least 4.5:1, measured in `messaging.test.ts`) and `dir="rtl"` in
  Arabic.

### Client record and agenda (2026-10-12, `docs/agent-notes/client-records.md`)

The two pillars, agenda and Client Records, now meet on every screen where a visit is touched.

- **Client record** (4.1) is the center of a client: a hero with name, contact and compact message, call and edit
  actions; allergies, sensitivities and her important note in one highlighted card; the screen's one primary action,
  "Register visit"; a compact session-plan card; then four sections in a segmented control (a menu at the
  accessibility sizes): History (default), Photos, Information, Documents. Export, booking, incident and edit live in
  the actions menu.
- **History** is a timeline of `VisitTimelineCard`s: the real visit day (`RecordVisitDate`: the visit day she noted,
  else the linked booking's start, else "written on"), service, a short summary, photo thumbnails and the state chip
  (Draft only; Finalized and Locked appear in the details). The newest visit is highlighted. Bookings that did not
  happen (cancelled, no-show) are thin rows, never treatment cards; a completed booking with nothing written is
  "Record pending" with a Fill action. Everything is grouped by stored links, never by date; photos with no visit
  wait in an "Organize" card.
- **Visit details** show everything the record holds with corrections applied, the photos, incidents and linked
  documents, and the change history collapsed at the end. Actions: Add photo, Complete (the visit form), Use as the
  base of a new visit (choose parts; never photos, result, reaction, day or signed documents).
- **Visit form**: one screen, any order. Photos first or last (one "Take photo" button: before, then after, then
  progress; kind and visibility change on the tile), client, service and the real visit day, a quick note, the
  profession's fields (needed fields never fold), result and reaction, aftercare and "Remember next time". It saves a
  draft by itself (`VisitAutosaveStatus` says saving, saved at, or not saved with a retry). "Finalize record" is the
  one primary action; the confirmation is compact (open the record, book the return, done). Closing with a draft asks
  keep or delete.
- **Appointment and Before you start**: the client's name opens her record; the previous visit shows with photos;
  the actions follow the record's state (Register visit, Continue record, Open record). "Mark completed" never
  finalizes a record; with nothing written it asks "Register now" or "Later". Before you start shows only what was
  written: "Remember today" (rose wash), the last visit card and technique, products, result and reaction.
- **Home and Alerts**: "To follow up" (Home, three rows, then "See all in Alerts") and "Records to complete" (Alerts,
  every one) list completed bookings of the last 14 days with nothing written and drafts, one line per visit. An
  optional evening notification says only a count.
- **Options**: "+ Add" chips on techniques, products, her fields' choices and the client's preferences, sensitivities
  and recurring requests open `OptionAddSheet` (suggestions while typing, create and select, "Only this time" or "Save
  to reuse"). More → Personalization renames, reorders, archives and restores; written records keep their words.
- **Documents**: four parts, private documentation, sent by the client, sharing with the client and portfolio use; a
  consent can name the visit it belongs to.
- **Record fields**: "Needed to finalize" (never blocks a draft) and "Only for…" services per field.
- **Welcome**: "Organize your agenda. Follow every client." with a sample record card; voice and the assistant are
  shown as optional, never as active.

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
that cannot be read or is above 10 MB shows an error in the sheet. Client records (2026-10-12): the record has empty
lines per section (no visits, no photos, no documents), Visit details have loading, missing and error states, the
visit form says when a draft is not saved and offers a retry, Organize photos and the client picker have empty
states, Personalization has an empty line per list and an error alert for a duplicate or a failed save.

## Accessibility

- Icon-only buttons have `accessibilityLabel`. Cards combine their children into one element. Touch targets are at least 44×44 pt.
- Every string is localized (`SupportFiles/Localizable.xcstrings`, source language `en`, fourteen localizations, see
  `docs/07-LOCALIZATION.md`). Strings no native has read are `needs_review`.
- Check light and dark, Dynamic Type to AX5, Increase Contrast, Reduce Motion and right-to-left before a feature is done.
- `LocalizationScreenshotUITests` (Full plan) renders the key screens in all fourteen localizations at the default size
  with no clipped text, checks Arabic mirroring (first tab and back button on the right) and runs a double-length
  pseudolanguage; with `TEST_RUNNER_SCREENSHOT_DIR` it saves `<localization>-<screen>.png` for native readers.
- Contrast: text 4.5:1, UI parts 3:1, measured by tests, never `.opacity` on text.
