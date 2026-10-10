# color-refinement: medium-intensity sage, rose and peach (task `docs/tasks/color-refinement.md`)

Single agent on `build/v1`, from `cbb6787`. The approved reference mockup (light/dark Home) was **not** in `design/`
and was not provided; the work follows the hex specification and the "apply by role" rules of the task. The old
prototype screenshots in `design/screenshots/` show layout only and were not used to judge intensity.

## How color reaches the screen today (inspection)

- One source: `DesignSystem/Tokens/` (`Palette`, `StatusPalette`, `AvatarPalette`, `HeroPalette`, `TagColor`,
  `Elevation.tint`). Every token is `Color(light:dark:lightIncreased:darkIncreased:)`, a trait-based `UIColor`, so
  light/dark, system switching and Increase Contrast propagate without any `colorScheme` branch. The only
  `colorScheme` reads are `Elevation` (shadow vs top highlight), Sign in with Apple's button style and the catalog.
- No named color assets in use (`AccentColor` is empty); no `UIAppearance` bridges. The tab bar is the native
  `TabView` tinted with `.tint(Palette.ink)` in `MainView`.
- `web/` generates its CSS variables from the same Swift files (`web/scripts/gen-tokens.ts`) and measures its own
  pairs (`web/scripts/check-contrast.ts`), so a token change reaches the page on its next build.
- Literals found outside the tokens: `Color(hex: 0x242321)` in `BrandMark`, `SuccessSeal`, the primary button
  shadow and **`Screens/Welcome/WelcomeView.swift` (a hex in Screens, a rule break)**; `Color.white.opacity` in the
  avatar ring and the hero sheen (decorative). Opacity on a brand color only in the two glows (`GlowBackdrop`,
  `HeroSurface`), both measured at their peak by tests. No gradient besides hero, glow backdrop, avatar and the dark
  elevation highlight.
- Contrast tests: `PaletteContrastTests` (core pairs, all four appearances, Increase Contrast never lower),
  `HeroContrastTests`, `BackdropContrastTests`, `AvatarPaletteTests`, `TagColorTests` and one suite per screen
  family (Home, Clients, Calendar, Appointments, Records, Health, Treatment, BookingSetup, Services).

## Mapping: current token -> new role -> components

| Current | New role (approved spec) | Affected components and screens |
|---|---|---|
| `bg` | App background `#FAF7F1` / `#191D19` | every screen, `GlowBackdrop`, sheets' page |
| `surface` | Neutral surface `#FFFFFF` / `#252B25` | `belloCard`, `ListCard`, secondary button and unselected chip fill, tiles in sheets |
| `sunken` | Elevated neutral surface `#F3EFE7` / `#30382F` | input fill (`BelloTextField`, `BelloNoteField`), wells, close and step buttons, `Skeleton`, `ChoiceCard` unselected |
| `ink` | Primary text `#272522` / `#F7F2E8` | all primary text. **No longer a fill** (it was the primary button and the "selected" fill) |
| `ink2` | Secondary text `#625F59` / `#C6C4B9` | all secondary text, placeholders (`Text+Prompt`) |
| `ink3`, `fieldBorder` | derived neutrals (icons 3:1, field boundary 3:1) retinted to the green-grey family | chevrons, input and secondary-button borders |
| `hairline` | Neutral separator/border `#D5D8CF` / `#566151` | card borders, dividers, unfilled progress segments |
| `ink` fill + `inkOnFill` | **Primary action** `action` `#4F6B4D` / `#57744E` + `onAction` `#FAF5EB` | `.belloPrimary` (every screen's primary), progress views inside primary buttons, step progress, check discs and radios (`ChoiceCard`, tag editor, new-appointment client card, products input, import rows), `ChoiceCard` selected outline |
| (new) | **Selection** `selectionFill` `#CADAC2` / `#435C3C` + `selectionInk` `#3C5638` / `#F7F2E8` | native tab bar tint (foreground only, the glass bar draws its own pill), `.belloChip(selected: true)` (fill, label, 1.5 pt ring), calendar strip selected day and week-grid today (fill, number, ring), region preset code tile |
| `sageText` | Sage icon/accent `#4F6B4D` / `#BDDAAA` | confirmed status, success text, sage tile icon, `InlineNotice.info`, avatar sage family |
| `peachText` | Peach icon/accent `#8F5235` / `#FFD1AF` | win-back strip, peach tile icon, peach tags |
| `roseText` (= `accent`) | Rose icon/accent `#8D4761` / `#F2B8CE` | links, tertiary buttons, focus ring, today marker, rose tile icon |
| `roseDeepText` | deeper rose for small text on deep rose washes | "next up" chip, rest-of-today count |
| `sageWash`/`roseWash`/`peachWash` (+ deep) | quiet tinted surfaces for chips and notices (kept as washes, retinted to the new family) | status chips, notices, icon squares in rows, alert cards |
| `InsightTile` wash | **Card fill** `sageFill` `#BDD0B3`/`#3B5540`, `peachFill` `#F0C5A6`/`#704B37`, `roseFill` `#E3B5C7`/`#684353` | Home tiles, Week at a glance tiles, onboarding Ready tiles |
| `ink`/`ink2` on a tile | **Text on brand cards** `onBrandCard` `#252823` / `#F7F2E8` | tile numeral and label |
| `surface` icon disc on a tile | **Badge** `sageBadge`/`peachBadge`/`roseBadge`: ivory `#FAF5EB` in light, deeper family surface in dark; icon in the family accent | tile icon discs |
| `EmptyState` washes | illustration fills (`roseFill`, `sageFill`, `peachFill`) | every empty state (55 consumers) |
| `rose`, `sage` | logo swatches stay `#C98F9F`, `#6E8266` (dots, glows, switch track) | tag dots, next-up dot, switches |
| `0x242321` literals | `BrandPalette` (logo: sage tile, ivory "b", rose dot, like the app icon) and `HeroPalette` | `BrandMark`, `SuccessSeal` hero tone, welcome pill, button shadow |
| `HeroPalette` graphite | retinted to the green-graphite of the dark neutrals | `HeroCard` (Home next visit, client profile, plan, booking link, more, waitlist) |
| `AvatarPalette` | gradient ends move to the approved card fills; initials in the family accent | every avatar |
| `amber*`, `coral*` | **unchanged semantics** (warning, safety, destructive); values kept | allergies, contraindications, errors, destructive buttons, offline banner |
| `neutralWash`/`neutralText` | quiet sand; dark value moved off brown-grey | completed status, sand tags |
| `Elevation.tint` | shadow tint moved from warm brown to a neutral green-graphite | `belloElevation` in light mode |

Kept as they are on purpose: amber and coral (safety and status semantics), the logo rose and sage, `systemBlue`,
the native tab bar and navigation bars (only the tint changes), Liquid Glass materials, `BelloHub.icon`.

Home "New appointment": the quick action becomes `.belloPrimary` while the day has visits; on a clear day the empty
state's own primary "New appointment" stays the one primary and the quick action stays secondary (one primary per
screen).
