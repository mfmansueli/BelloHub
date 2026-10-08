# BelloHub design

Source of truth for the UI. Update it in the same change as the UI (see CLAUDE.md, section 4).

## Identity

Not decided yet. The color values below are **provisional placeholders** chosen to pass contrast, not a brand.
Open: brand colors, brand font, app icon, one-line description of the product.

## Principles

- Native first: system `TabView`, `NavigationStack`, sheets, menus, pickers and toolbars. The system tab and
  navigation bars carry Liquid Glass on iOS 26 for free. A custom component needs a comment saying why the native one can't do the job.
- Every interactive or meaningful element has an `accessibilityIdentifier` (`<screen>.<element>[.<id>]`, camelCase)
  and works with VoiceOver.

## Tokens

All in `BelloHub/DesignSystem/Tokens/`. Screens use these names and never hex, font or spacing literals.

### Color (`Palette`)

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F7F7F9` | `#0B0B0E` | Screen background |
| `surface` | `#FFFFFF` | `#1A1A20` | Cards, grouped content |
| `ink` | `#111114` | `#F5F5F7` | Primary text |
| `ink2` | `#595963` | `#A6A6B2` | Secondary text |
| `accent` | `#0A4FD6` | `#7FA8FF` | Tint, interactive text |

Contrast (WCAG 2.2 AA, text needs 4.5:1), enforced by `PaletteContrastTests`:

| Pair | Light | Dark |
|---|---|---|
| `ink` on `bg` / `surface` | 17.6 / 18.9 | 18.1 / 15.9 |
| `ink2` on `bg` / `surface` | 6.5 / 6.9 | 8.2 / 7.2 |
| `accent` on `bg` / `surface` | 6.3 / 6.8 | 8.4 / 7.4 |

Not measured yet: Increase Contrast variants, and text over Liquid Glass or media. Measure on the worst point of the real surface when those appear.

### Typography (`Typography`)

System text styles, so Dynamic Type works without extra code: `title` (semibold), `body`, `caption`.
A brand font, once chosen, joins through `Font.custom(_:size:relativeTo:)`.

### Spacing (`Spacing`)

`xs` 4 · `sm` 8 · `md` 16 · `lg` 24 · `xl` 32.

### Radius

No token yet. It is added with the first component that rounds.

## Components

None yet. Generic components go in `DesignSystem/Components/` as `View` extensions, and button styles in
`DesignSystem/Styles/` as one `ButtonStyle` with an `enum Variant`.

## Screen inventory

| Screen | Folder | ViewModel | Identifiers |
|---|---|---|---|
| Root (state gate) | `Screens/Main/RootView` | none | none |
| Main (tab shell) | `Screens/Main/MainView` | none | `main.tab.home` |
| Home | `Screens/Home/HomeView` | none, presentation-only | `home.greeting` |

## Navigation tree

```
RootView (state gate: onboarding → login → setup → app; only "app" exists)
└── MainView (TabView)
    └── Home tab → NavigationStack → HomeView
```

Secondary flows are sheets. Celebrations and media viewers are `fullScreenCover`.

## Empty, loading and error states

Home has no data, so none apply yet. Each screen that loads data defines all three before it ships:
a loading state, an empty state with the next action, and an error state with a retry.

## Motion

Only system transitions so far. Continuous animations must respect Reduce Motion. In Debug builds, UI tests launch with
`-uiTesting`, which removes SwiftUI animations.

## Accessibility

- Icon-only buttons have `accessibilityLabel`. Cards combine their children into one element. Touch targets are at least 44×44 pt.
- Every string is localized (`SupportFiles/Localizable.xcstrings`, source language `en`). Target languages are not decided.
- Check light and dark, Dynamic Type at the largest sizes, and Reduce Motion before a feature is done.
