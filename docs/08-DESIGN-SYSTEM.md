# 08 · Design system

The prototype is the visual reference (`design/screenshots/` and the HTML in `design/prototype/screens/`). This file translates it into tokens and components for `BelloHub/DesignSystem/` following `CLAUDE.md` §4: semantic `Palette`, light/dark through `Color(light:dark:)`, typography with `relativeTo:`, one `ButtonStyle` with a `Variant`, generic components as `View` extensions, **no hex, font or radius literal in `Screens/`**.

## 1. Identity

Quiet richness. A warm ivory page, graphite as the strong colour, dusty rose and soft sage as accents, peach for warmth. Depth comes from tonal surfaces, two-layer warm shadows and one memorable "hero" card per key screen, not from decoration. Fraunces gives the headlines and big numerals a human, editorial voice; DM Sans keeps the interface clear. No theme, no mascot, no illustrations beyond small composed shapes in empty states.

Replace the repo's placeholder blue palette and the "Identity: not decided" paragraph in `DESIGN.md` with this identity in stage S1.

## 2. Colour tokens

> **Superseded values (2026-10-10):** the owner approved a medium-intensity sage, rose and peach refinement with new roles (`action`, `selection*`, brand fills, `onBrandCard`, badges), and later the same day replaced its values with the "graphite and orange" palette (same names and roles; `rose…` is now the orange family, `sage…` the green, `peach…` the slate). The current values and roles are in `DESIGN.md` (Tokens, Color) and `BelloHub/DesignSystem/Tokens/Palette.swift`; the table below is the original prototype specification.

Semantic names; each is a light/dark pair. Light values come from the prototype; **dark values are defined here** (the prototype only draws light) and their contrast was computed, but **you must still enforce them with tests** (`PaletteContrastTests`).

### Surfaces and ink

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F8F6F2` | `#161412` | Screen background |
| `surface` | `#FFFCF8` | `#1F1C1A` | Cards, list cards, sheets |
| `sunken` | `#EFEBE4` | `#272320` | Wells, inputs background, quiet chips |
| `hairline` | `#ECE7DF` | `#34302C` | Card borders, dividers (decorative, may be < 3:1) |
| `ink` | `#242321` | `#F5F1EA` | Primary text, primary button fill (inverts in dark) |
| `inkOnFill` | `#FFFCF8` | `#161412` | Text on the primary button |
| `ink2` | `#65625D` | `#B5AEA5` | Secondary text |
| `ink3` | `#8C8984` | `#8C857D` | Tertiary **icons only** (3.4:1 light, 4.6:1 dark). Never text |
| `fieldBorder` | `#D9D4CB` | `#4A443E` | Input and secondary-button borders (must be ≥ 3:1 against `bg`: check and darken if needed) |

### Accents

| Token | Light | Dark | Use |
|---|---|---|---|
| `rose` (fill) | `#C98F9F` | `#C98F9F` | Dots, ring accents, glow (never behind small text) |
| `roseText` | `#9A5A6C` | `#E3A8B7` | Links, "action" text on `bg`/`surface` |
| `roseWash` | `#F7ECEE` | `#3A2A2F` | Soft backgrounds |
| `roseDeepWash` / `roseDeepText` | `#F0DCE1` / `#7E4757` | `#4A343A` / `#F2C4D0` | Chips on rose wash. **Use `roseDeepText` for small text on rose washes** (`roseText` on `roseWash` is 4.49:1 in light, below 4.5) |
| `sage` (strong) | `#6E8266` | `#8FA585` | Switch on-track, success graphics |
| `sageText` | `#56684F` | `#B9CBAE` | "Confirmed" text, success text |
| `sageWash` / `sageDeepWash` | `#EEF2EA` / `#DFE6D9` | `#263023` / `#30402C` | Chips, tile backgrounds |
| `peach` (fill) | `#E8B49E` | `#E8B49E` | Decoration |
| `peachText` / `peachWash` | `#8A5238` / `#FBEFE7` | `#EBBFA9` / `#36281F` | Warm tiles and chips |
| `amberText` / `amberBg` | `#7A5C16` / `#F6ECD6` | `#E8CD85` / `#3B3118` | Pending |
| `coralText` / `coralBg` | `#9A4535` / `#F8E1DC` | `#F2A99B` / `#40231F` | Needs attention, allergies, reactions, safety notices |
| `neutralWash` / `neutralText` | `#EADFD2` / `#4A4036` | `#2F2923` / `#E2D6C8` | Quiet chips |
| `systemBlue` | `#0062CC` | system | Only where the OS expects a link (rare) |

Computed contrast (text/background), light: `ink`/`bg` 14.6, `ink2`/`bg` 5.6, `ink2`/`sunken` 5.1, `roseText`/`surface` 5.1, `sageText`/`sageWash` 5.3, `peachText`/`peachWash` 5.6, `amberText`/`amberBg` 5.3, `coralText`/`coralBg` 5.1, `roseDeepText`/`roseDeepWash` 5.5. Dark: `ink`/`bg` 16.3, `ink2`/`surface` 7.7, `roseText`/`roseWash` 6.8, `sageText`/`sageWash` 8.0, `peachText`/`peachWash` 8.5, `amberText`/`amberBg` 8.2, `coralText`/`coralBg` 7.4. White/cream text on `sage` fills uses `sageText`-darkened values, never `#6E8266` (4.0:1).

### Hero (graphite) surface

`HeroSurface`: `LinearGradient` 160° `#2E2C2A → #242321` plus two radial glows (rose `rgba(201,143,159,.30)` from the top right, sage `rgba(169,181,161,.22)` from the bottom left) built with `RadialGradient`/`MeshGradient` (iOS 26 `MeshGradient` is available; either is fine). Text on it: cream `#FFFCF8` (13.6:1), secondary cream at 68 % (≥ 6.4:1 measured on the lightest glow point). In dark mode the hero is the same (it is already dark) with a slightly stronger rim light. **Measure on the lightest point of the glow**, not the average (`CLAUDE.md` §5).

### Increase Contrast
Provide `*HighContrast` variants (darker text, stronger `fieldBorder` and `hairline`) selected by `\.colorSchemeContrast == .increased` and test them.

## 3. Typography

Bundle **Fraunces** and **DM Sans** (variable fonts, SIL OFL) under `DesignSystem/Fonts/`, register them in the app's `INFOPLIST_KEY`/`UIAppFonts` through xcconfig-compatible means (add the files to the target; list in `Info.plist` generation keys or a small checked-in `Info.plist` merged by `GENERATE_INFOPLIST_FILE`; verify the fonts load, and test PostScript names). `scripts/fetch-fonts.sh` downloads the official files from the Google Fonts repositories and verifies licences; if the environment has no network, create task H12 and use system fonts (New York for Fraunces, SF for DM Sans) behind the same tokens until the files arrive.

One scale, nothing outside it. All through `Font.custom(_:size:relativeTo:)` so Dynamic Type works:

| Token | Font | Size / weight | Relative to |
|---|---|---|---|
| `Typography.moment` | Fraunces | 40 / 500 | `.largeTitle` |
| `Typography.screenTitle` | Fraunces | 34 / 500 | `.largeTitle` |
| `Typography.title` | Fraunces | 28 / 500 | `.title` |
| `Typography.subtitle`, `Typography.numeral` | Fraunces | 24 / 500 | `.title2` |
| `Typography.section` | DM Sans | 20 / 600 | `.title3` |
| `Typography.body` / `bodyStrong` | DM Sans | 17 / 400 or 600 | `.body` |
| `Typography.callout` | DM Sans | 16 / 400 or 600 | `.callout` |
| `Typography.meta` | DM Sans | 15 / 400 or 600 | `.subheadline` |
| `Typography.footnote` | DM Sans | 13 / 400 or 600 | `.footnote` |
| `Typography.caption` | DM Sans | 12 / 600 | `.caption` |
| `Typography.tabLabel` | DM Sans | 11 / 600 | `.caption2` (system tab bar controls its own label) |

Fraunces letter-spacing −0.015 em at display sizes (`tracking`). Times and durations use monospaced digits (`.monospacedDigit()`). Nothing under 11 pt, no light weights, **no all-caps tracked eyebrows**: section titles are sentence case 20/600. Do not cap Dynamic Type for primary text; cap only dense decorative numerals with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` and verify layouts reflow (stack vertically) at AX5.

## 4. Spacing, radius, elevation

- Spacing: the repo's `xs 4, sm 8, md 16, lg 24, xl 32` plus `xxs 2`, `row 12`, `section 30`, `gutter 20` (side margin). Safe areas: always `safeAreaInset`, never hard-coded 62/34/84 (those were the prototype's phone-frame numbers).
- Radius tokens by role: `hero 30`, `card 24`, `tile 18`, `tileSmall 20`, `control 14`, `input 14`, `button 18`, `chip` capsule, `avatar` circle, `sheet` system. **Concentric rule:** inner radius = outer radius − padding when a shape sits inside another.
- Elevation (warm, tinted, two layers; in dark mode drop to a hairline plus a subtle top highlight, shadows barely show): `e1` = `0 1 2 rgba(70,45,30,.05)` + `0 8 20 −10 rgba(70,45,30,.14)`; `e2` = `0 2 4 .06` + `0 20 36 −18 .28`; `sheet` = `0 −12 40 −12 .25`. Cards on `bg` use 1 pt `hairline` **and** `e1`; wells use `sunken` with no border.

## 5. Native first (what *not* to rebuild)

| Prototype element | iOS 26 implementation |
|---|---|
| Floating pill tab bar | System `TabView` (`Tab { }`), `.tint(Palette.accent)`; the OS draws the floating glass bar. Alerts tab shows a **badge**/dot with `.badge`. |
| Navigation bar, large titles | System `NavigationStack` titles; the Fraunces large title is produced by `toolbarTitleDisplayMode` + a custom title view only where the prototype shows the serif title on tab roots (use `.navigationTitle` with a principal toolbar item in Fraunces; keep a text equivalent for VoiceOver). |
| Bottom sheets | `.sheet` with `presentationDetents`, system corner radius and drag indicator. Keep the content layout from the prototype. |
| Switch | `Toggle` with `.tint(Palette.sageStrong)` |
| Date and time pickers | `DatePicker` (compact, graphical) styled by tint; custom time-slot grids only for the booking slot lists |
| Menus, confirmation dialogs, alerts | `Menu`, `.confirmationDialog`, `.alert` |
| Segmented controls | `Picker(.segmented)` |
| Search | `.searchable` |
| Share | `ShareLink` |

Custom (documented with a "why" comment): `HeroCard` surface, status chips, avatar, insight tiles, list cards with inset dividers, the week grid, the before/after slider, the camera guide overlay, the success seal, the waveform.

## 6. Components (generic, in `DesignSystem/Components/`)

- **`BelloButtonStyle(variant:)`**: `.primary` (56 pt high, radius 18, fill `ink`, text `inkOnFill` 17/600, soft shadow `0 10 20 −10 rgba(36,35,33,.5)`), `.secondary` (surface, 1 pt `fieldBorder`), `.tertiary` (text, `roseText`), `.onHero` (cream pill on graphite), `.destructive` (coral). Disabled = 40 % opacity **and** a different shape cue is not needed, but VoiceOver says "dimmed". Chips are `ChipStyle(selected:)`: 40–44 pt high capsule, selected fill `ink`, unselected `surface` + border.
- **`Avatar`**: 44 pt circle with a 145° gradient from one of four wash pairs (rose `#F6E4E8→#E8C6CF`, sage `#E6ECE0→#C9D6C0`, sand `#F3E7DA→#E2CDB6`, peach `#FBE9DD→#EDC7B2`), initials 15/600 in the pair's deep text colour, inner 1.5 pt ring white 70 %. Pair chosen by a stable hash of the id. Shows a photo when present.
- **`StatusChip`**: 26 pt capsule, 6 pt dot, 12.5/600 label. Confirmed = sage; Pending = amber; Next up = rose; Completed = neutral; Needs attention = coral. **Always a word, never colour alone.**
- **`SectionHeader`**: baseline-aligned title (20/600) + trailing action (14/600 `roseText`), margins 30 top, 12 bottom.
- **`ListCard`**: `surface`, hairline, `e1`, radius 24; rows with **inset dividers** starting at the text edge (72 pt leading for avatar rows).
- **`InsightTile`**: radius 20, wash background, 36 pt white-55 % icon disc, Fraunces numeral 30, label 13; the whole tile is one accessibility element and one tap target.
- **`HeroCard`**: radius 30, graphite surface, glow, avatar with ring, Fraunces time 40, service line, chips, primary `.onHero` action and quiet secondary. One per key screen (Home next-up, ClientProfile, BeforeYouStart).
- **`EmptyState`**: small composed illustration (two or three overlapping tinted shapes and one SF Symbol), 20/600 title, 15 secondary line giving the next action, one primary button.
- **`InlineNotice`**: `.safety` (coral card, icon, title, body: allergies, contraindications, reaction), `.info` (sage), `.warning` (amber).
- **`FieldRow` / `BelloTextField`**: height 52, radius 14, `sunken` fill, 1.5 pt `fieldBorder`; focus ring 3 pt `roseText` outside the field (matches the prototype's keyboard focus ring); error state with message under it and `accessibilityHint`.
- **`SuccessSeal`**: circle pop, check draw, one ring (see `09-MOTION.md`).
- **`OfflineBanner`, `SyncPill`, `Skeleton`**, **`FooterNote`** (privacy copy blocks).
- **`QRCodeView`**, **`BeforeAfterSlider`**, **`WaveformView`** (voice), **`CameraGuideOverlay`**.

## 7. Icons

The prototype uses a 24-pt line icon set (stroke 1.75, round caps). On iOS use **SF Symbols** (regular/medium weight) and keep a single mapping table `IconToken → symbol name` in `DesignSystem/Tokens/Icon.swift` so the whole app changes in one place. Mapping for the prototype's 50 icons:

`home→house`, `clients→person.2`, `calendar→calendar`, `bell→bell`, `plus→plus`, `check→checkmark`, `chev→chevron.forward`, `back→chevron.backward` (these mirror automatically in right-to-left languages, `07-LOCALIZATION.md` §2.5), `x→xmark`, `key→key`, `print→printer`, `lock→lock`, `camera→camera`, `mic→mic`, `link→link`, `phone→phone`, `chat→bubble.left`, `clock→clock`, `user→person`, `userplus→person.badge.plus`, `tag→tag`, `shield→checkmark.shield`, `gear→gearshape`, `image→photo`, `doc→doc.text`, `download→arrow.down.to.line`, `share→square.and.arrow.up`, `qr→qrcode`, `search→magnifyingglass`, `trash→trash`, `info→info.circle`, `sparkle→sparkles`, `repeat→arrow.triangle.2.circlepath`, `mail→envelope`, `globe→globe`, `faceid→faceid`, `star→star`, `bolt→bolt`, `help→questionmark.circle`, `pencil→pencil`, `box→shippingbox`, `scissors→scissors`, `sliders→slider.horizontal.3`, `cloud→icloud`, `wifi→wifi`, `alert→exclamationmark.triangle`, `logout→rectangle.portrait.and.arrow.right`, `gift→gift`, `moon→moon`, `whatsapp→` a small template asset (bundled monochrome glyph; WhatsApp's brand rules apply, confirm usage in H-tasks). Decorative symbols are hidden from VoiceOver.

## 8. Layout rules from the prototype

- Side margin 20; 24–30 between sections, 12 inside groups.
- Tab roots: Fraunces title + one-line subtitle. Flows (onboarding, record, new appointment): top bar with back/close, progress where the prototype shows it, **sticky bottom action** (`safeAreaInset(edge: .bottom)`) with one primary button.
- Sheets: handle, title, content, one primary action.
- One primary action per screen. Destructive actions are never the visual primary.
- The `Calendar` week grid is the one place where targets may be smaller than 44 pt; the day list is the accessible alternative and is reachable by a segmented control and by VoiceOver rotor.
- Content width on iPhone only (D1); still use `frame(maxWidth: .infinity)` and avoid fixed widths so Dynamic Type and long locales reflow.

## 9. Accessibility (D34)

44×44 pt targets (`contentShape` where the glyph is smaller); each card is one combined element with a meaningful label ("Camila Rocha, Glow Facial, 11:30, confirmed"); icon-only controls labelled; custom controls expose traits and values (the slider as adjustable); focus order follows the visual order; Dynamic Type to AX5 with reflow; Bold Text and Increase Contrast honoured; Reduce Motion and Reduce Transparency honoured (glass falls back to solid `surface`); no information by colour alone; accessibility identifiers `"<screen>.<element>[.<id>]"`.

## 10. DESIGN.md

Keep the repo's `DESIGN.md` as the live source: identity, tokens (this file's tables), components, screen inventory (the 97 screens with ids and folders), navigation tree, empty/loading/error states per screen, motion (`09`), accessibility. Update it in the same commit as each UI change.
