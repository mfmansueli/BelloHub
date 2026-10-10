//
//  Palette.swift
//  BelloHub
//

import SwiftUI

/// Semantic color tokens (docs/08-DESIGN-SYSTEM.md section 2), on the "graphite and orange" direction the owner chose
/// on 2026-10-10: pure neutrals, black and white, and one vivid orange for the primary action. Screens use these names
/// and never hex values or `.opacity(x)` on text. Every token is a light/dark pair, and the ones that carry text or UI
/// parts also declare an Increase Contrast pair. `PaletteContrastTests` measures every text/background pair in all
/// four combinations, so change a value and the tests say if it still passes.
///
/// The family names (`rose`, `sage`, `peach`) are kept from the earlier palette because a client tag stores them as
/// its color token (`TagColor`), so renaming them would orphan saved tags. Their roles, not their hues, are what the
/// names mean now: `rose…` is the orange brand family (links, accent, "next up"), `sage…` is the green of confirmed
/// and success, `peach…` is the cool slate of the third family. DESIGN.md has the table.
///
/// Roles are kept apart on purpose: brand identity (`rose`, `sage`, `ivory`, `brandMark`), neutral surfaces and
/// foregrounds, the primary action, selection, the brand families (card fill, badge, accent) and the semantic
/// statuses (amber, coral), which never borrow a decorative family color.
///
/// Ink-on-surface rules the tests encode: `ink3` is for icons only (never text); `sage` and `rose` fills never sit
/// behind small text; text on a brand card fill uses `onBrandCard`, never `ink2`.
enum Palette {
    // MARK: Surfaces and ink

    static let bg = Color(light: 0xF4F4F3, dark: 0x0E0E0E)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1A1A)
    /// The elevated neutral surface: input fill, wells, quiet round buttons.
    static let sunken = Color(light: 0xEDEDEB, dark: 0x262626)
    /// Card borders and dividers. Decorative, so it may stay below 3:1.
    static let hairline = Color(light: 0xDCDCD9, dark: 0x3A3A3A, lightIncreased: 0xA3A3A0, darkIncreased: 0x6E6E6B)
    static let ink = Color(light: 0x141414, dark: 0xF5F5F4)
    static let ink2 = Color(light: 0x5A5A58, dark: 0xABABA8, lightIncreased: 0x3F3F3D, darkIncreased: 0xD2D2CF)
    /// Tertiary icons only, never text.
    static let ink3 = Color(light: 0x858582, dark: 0x7E7E7B)
    /// Input and secondary-button borders. Darker than the separator so it reaches the 3:1 that WCAG 1.4.11 asks of
    /// a field boundary, on the page, a card and the input fill.
    static let fieldBorder = Color(light: 0x7A7A77, dark: 0x858582, lightIncreased: 0x5A5A57, darkIncreased: 0xB0B0AD)

    // MARK: Primary action

    /// Fill of the one primary button of a screen and of check discs and filled progress: the brand orange. The light
    /// fill is a shade deeper than the logo orange so filled progress still reaches 3:1 on the page. The label is
    /// near-black, not white: white on this orange is under 4.5:1, black is well above it in both appearances.
    /// Increase Contrast keeps the fill and turns the label pure black, since a darker fill would lower the label's
    /// ratio.
    static let action = Color(light: 0xE84A10, dark: 0xFF6B33)
    /// Label and glyph on `action`.
    static let onAction = Color(light: 0x141414, dark: 0x141414, lightIncreased: 0x000000, darkIncreased: 0x000000)

    // MARK: Selection

    /// Fill of a selected chip, day or option: a soft orange wash. Close to the page in light, so a selected element
    /// always pairs it with a `selectionInk` ring or a check: the fill alone never carries the state.
    static let selectionFill = Color(light: 0xFFDCC9, dark: 0x4A2414)
    /// Label of a selected element and its ring; also the tab bar tint (the native bar draws its own selection
    /// pill).
    static let selectionInk = Color(light: 0x141414, dark: 0xF5F5F4, lightIncreased: 0x000000, darkIncreased: 0xFFFFFF)

    // MARK: Brand identity

    /// The logo orange: dots, ring accents and glows. Never behind small text.
    static let rose = Color(hex: 0xFF5A1F)
    /// Switch on-track and success graphics: the confirmed green.
    static let sage = Color(light: 0x2F8F5A, dark: 0x4CC27A)
    static let ivory = Color(hex: 0xFAFAF9)
    /// The mark's tile. Still the app icon's sage: `BelloHub.icon` has not been redrawn for the new palette, and the
    /// mark in the app stays equal to the icon on the home screen until it is.
    static let brandMark = Color(light: 0x6E8266, dark: 0x344B3C)

    // MARK: Brand families: card fills, text on them, badges

    /// Solid fills of insight tiles and empty-state shapes (green, slate, orange). Decorative against the page (they
    /// need no 3:1 there); text on them is `onBrandCard`.
    static let sageFill = Color(light: 0xC9E8D3, dark: 0x1F4A30)
    static let peachFill = Color(light: 0xD3D8E6, dark: 0x2A3045)
    static let roseFill = Color(light: 0xFFC4A8, dark: 0x6A2E14)
    /// Text on a brand card fill.
    static let onBrandCard = Color(light: 0x141414, dark: 0xF5F5F4, lightIncreased: 0x000000, darkIncreased: 0xFFFFFF)
    /// Icon discs on a brand card: white with the dark family accent in light, a deeper family surface with the light
    /// family accent in dark (never a generic black circle). The icon is the family's `…Text` token.
    static let sageBadge = Color(light: 0xFFFFFF, dark: 0x163322)
    static let peachBadge = Color(light: 0xFFFFFF, dark: 0x222638)
    static let roseBadge = Color(light: 0xFFFFFF, dark: 0x4A2414)

    // MARK: Orange family (named rose)

    /// Orange icon/accent: links, action text, focus ring, icons.
    static let roseText = Color(light: 0xBF3E0A, dark: 0xFF8A5C, lightIncreased: 0x9A3007, darkIncreased: 0xFFB08A)
    static let roseWash = Color(light: 0xFFECE2, dark: 0x3A1D10)
    static let roseDeepWash = Color(light: 0xFFDCC9, dark: 0x4A2414)
    /// Small text on the deeper orange washes and counts that need more weight than a link.
    static let roseDeepText = Color(light: 0x8F2E06, dark: 0xFFC4A6, lightIncreased: 0x6E2204, darkIncreased: 0xFFDCC9)

    // MARK: Green family (named sage)

    /// Green icon/accent: confirmed and success text, icons.
    static let sageText = Color(light: 0x1D6638, dark: 0x8EDBA6, lightIncreased: 0x154D2A, darkIncreased: 0xB5EBC6)
    static let sageWash = Color(light: 0xE4F2E8, dark: 0x14291B)
    static let sageDeepWash = Color(light: 0xD2EADA, dark: 0x1C3826)

    // MARK: Slate family (named peach)

    /// Tag dot of the slate family.
    static let peach = Color(hex: 0x8C95B3)
    /// Slate icon/accent.
    static let peachText = Color(light: 0x434A5E, dark: 0xB5BCD8, lightIncreased: 0x2E3446, darkIncreased: 0xD3D8EC)
    static let peachWash = Color(light: 0xECEDF3, dark: 0x1F2230)

    // MARK: Amber and coral (status, never decorative)

    static let amberText = Color(light: 0x7A5C16, dark: 0xE8CD85, lightIncreased: 0x5C450F, darkIncreased: 0xF3DCA0)
    static let amberBg = Color(light: 0xF6ECD6, dark: 0x3B3118)
    /// Needs attention: allergies, reactions, safety notices, destructive actions. A clear red, so it never reads as
    /// the brand orange.
    static let coralText = Color(light: 0xAE2419, dark: 0xFF9C92, lightIncreased: 0x8A1A11, darkIncreased: 0xFFC0B8)
    static let coralBg = Color(light: 0xFDE2E0, dark: 0x3A1816)

    // MARK: Neutral

    static let neutralWash = Color(light: 0xECECEA, dark: 0x2A2A2A)
    static let neutralText = Color(light: 0x4A4A48, dark: 0xD0D0CD, lightIncreased: 0x2E2E2C, darkIncreased: 0xEAEAE7)

    // MARK: Semantic aliases

    /// Tint for interactive text and links. System controls that need a fill use `sage` or `action`.
    static let accent = roseText
    /// Only where the operating system expects a link.
    static let systemBlue = Color(light: 0x0062CC, dark: 0x6EB1FF)
}
