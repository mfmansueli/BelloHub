# Task: approved color refinement (medium-intensity sage/rose/peach)

Queued by the owner on 2026-10-10. Runs after the integration agent (build/v1 stabilization, D55 merge, deploy)
finishes. One agent, `model: opus`, `effort: high`. Commit first, test after.

## Goal

Implement the approved medium-intensity sage/rose/peach palette. The first proposal was too pale and the stronger
one too saturated; the owner approved the midpoint. Keep layouts, typography, spacing, component shapes, copy,
navigation behavior and functionality. Warmer, more alive, clearly readable, still calm and professional.

The hex values are the implementation specification for the approved mockup, not pixel-extracted values. Solid
color fills for cards; no incidental gradients from the mockup. The approved reference mockup (light/dark Home) is
the visual direction; if it is not in `design/`, ask the owner for it before judging intensity.

## First inspect and map

Locate the design system (`DesignSystem/Tokens/Palette`, `StatusPalette`, `AvatarPalette`, `HeroPalette`,
`Color(light:dark:)`), named color assets, tint and foreground/background styling, UIKit appearance bridges,
`BelloButtonStyle`, cards, badges, empty states, navigation. Search for hex/RGB literals, opacity-based brand
fills, gradients, hard-coded black/white and `colorScheme` branches. Identify how theme selection propagates
(Increase Contrast pairs exist).

Produce a compact mapping: current token -> new semantic role -> affected components. Extend the existing
architecture; no competing palette, no new hex literals in `Screens/`. Separate brand identity, surface fills,
foreground colors, interaction states and semantic statuses. A global find/replace is not acceptable.

Audit Home, Clients, Calendar, Alerts, More/settings, onboarding, booking creation/editing, client profiles,
histories, photos/consent, voice capture, sheets, forms, search, filters, loading/empty/error states. Follow shared
components through their consumers. Inspect `web/` (public booking page) and carry over the brand roles where
appropriate, respecting its own appearance support. Report anything outside the app left untouched.

## Approved tokens

| Semantic role                  | Light   | Dark    |
|--------------------------------|---------|---------|
| App background                 | #FAF7F1 | #191D19 |
| Neutral surface                | #FFFFFF | #252B25 |
| Elevated neutral surface       | #F3EFE7 | #30382F |
| Primary text                   | #272522 | #F7F2E8 |
| Secondary text                 | #625F59 | #C6C4B9 |
| Text on light brand cards      | #252823 | n/a     |
| Text on dark brand cards       | n/a     | #F7F2E8 |
| Primary action fill            | #4F6B4D | #57744E |
| Primary action label           | #FAF5EB | #FAF5EB |
| Sage card/illustration fill    | #BDD0B3 | #3B5540 |
| Peach card/illustration fill   | #F0C5A6 | #704B37 |
| Rose card/illustration fill    | #E3B5C7 | #684353 |
| Sage icon/accent               | #4F6B4D | #BDDAAA |
| Peach icon/accent              | #8F5235 | #FFD1AF |
| Rose icon/accent               | #8D4761 | #F2B8CE |
| Selected navigation fill       | #CADAC2 | #435C3C |
| Selected navigation foreground | #3C5638 | #F7F2E8 |
| Neutral separator/border       | #D5D8CF | #566151 |

Logo identity swatches stay: #6E8266 sage, #C98F9F rose, #FAF5EB ivory. Do NOT modify `BelloHub.icon`.

## Apply by role

- Home's primary "New appointment" uses the primary action pair in both modes; carry the role to equivalent
  primary actions; keep secondary/tertiary/destructive hierarchy.
- Home statistics keep their semantics: sage = remaining appointments, peach = open slots, rose = clients who have
  not returned. Solid opaque card fills, not low-opacity brand colors over the page. Labels on colored cards use the
  card foreground tokens, not global secondary gray.
- Empty-state decorative shapes use the illustration fills; artwork and layout unchanged.
- Light icon badges: ivory with dark family accents. Dark badges: deeper family surface with the light family
  accent; no generic black circles. Define badge tokens centrally; validate the exact pairs.
- Selected navigation state uses the selection pair where the native/custom implementation supports it. Keep the
  native tab bar and material behavior; inactive items keep legible neutral foregrounds.
- Forms, placeholders, dividers, chips, calendar selection, focus, pressed, loading and disabled states stay
  distinguishable; derive roles deliberately, not with one universal opacity.
- Error, allergy, contraindication, destructive, warning and success colors keep their semantics (never decorative
  peach/rose for a safety warning); verify accessibility.
- No neon, no excess saturation, no muddy brown-gray surfaces, no barely visible pastel cards, no heavy shadows,
  no new gradients.

## Accessibility and validation

Reference ratios (opaque colors only): ivory on light CTA 5.45:1; ivory on dark CTA 4.82:1; dark card text on
sage/peach/rose light cards 9.13/9.42/8.32:1; ivory on dark cards 7.35/6.84/7.48:1.

Measure every changed foreground/background pair after compositing (the contrast test suite in `BelloHubTests`
does this): >= 4.5:1 normal text, >= 3:1 large text and essential non-text UI. Decorative card backgrounds need
not contrast 3:1 with the page. For a failing pair, adjust minimally and document the final hex and ratio.

Verify light, dark, system switching, Increase Contrast, Reduce Transparency, disabled states, common text sizes.
Build with `scripts/build.sh`, run `scripts/test.sh fast`, `smoke`, `scripts/check-warnings.sh`. Capture Home in
both modes plus representative client, calendar, form/sheet and alert screens (Design Catalog `-designCatalog`
and `-catalogDark` help) under `build/` and compare with the reference. No business-logic changes; no redundant
tests that only mirror constants. Update `DESIGN.md` tokens section in the same change.

## Deliver

Final token table; files/components changed; affected screen families; semantic exceptions; build/visual checks
and contrast evidence; any unavailable validation. Adapt to the branch's real architecture while preserving the
approved visual intent.
