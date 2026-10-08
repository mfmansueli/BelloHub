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
| `SheetHeader` | Title, subtitle, close button, for native sheets |
| `BelloTextField` | 52 pt, radius 14, `sunken`, 1.5 pt `fieldBorder`, 3 pt `roseText` focus ring, error text; `isSensitive` turns off autocorrection |
| `InlineNotice` | `.safety` (coral), `.info` (sage), `.warning` (amber) |
| `Skeleton`, `OfflineBanner`, `FooterNote`, `SuccessSeal` | See Motion for the seal |

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
| Root (state gate) | `Screens/Main/RootView` | none | none |
| Main (tab shell) | `Screens/Main/MainView` | none | `main.tab.home` |
| Home (scaffold placeholder, replaced in S6) | `Screens/Home/HomeView` | none, presentation-only | `home.greeting` |
| Design Catalog (DEBUG) | `DesignSystem/Catalog/` | none | `catalog.*` |

The 97 screens and their stages are in `docs/PROGRESS.md` (traceability table).

## Navigation tree

```
RootView (state gate: onboarding → login → setup → locked → app; only "app" exists)
├── DesignCatalogView (DEBUG, -designCatalog)
└── MainView (TabView)
    └── Home tab → NavigationStack → HomeView
```

Five tabs arrive in S3 (Home, Clients, Calendar, Alerts, More). Secondary flows are sheets. Celebrations and media
viewers are `fullScreenCover`.

## Empty, loading and error states

Home has no data, so none apply yet. Each screen that loads data defines all three before it ships: a loading
state (`Skeleton`), an empty state with the next action (`EmptyState`), and an error state with a retry. Offline
is a normal state: `OfflineBanner` informs and never blocks.

## Accessibility

- Icon-only buttons have `accessibilityLabel`. Cards combine their children into one element. Touch targets are at least 44×44 pt.
- Every string is localized (`SupportFiles/Localizable.xcstrings`, source language `en`, fourteen localizations, see
  `docs/07-LOCALIZATION.md`). Strings no native has read are `needs_review`.
- Check light and dark, Dynamic Type to AX5, Increase Contrast, Reduce Motion and right-to-left before a feature is done.
- Contrast: text 4.5:1, UI parts 3:1, measured by tests, never `.opacity` on text.
