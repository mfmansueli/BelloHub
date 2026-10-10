//
//  Palette.swift
//  BelloHub
//

import SwiftUI

/// Semantic color tokens (docs/08-DESIGN-SYSTEM.md section 2, refined to the approved medium-intensity sage, rose and
/// peach on 2026-10-10). Screens use these names and never hex values or `.opacity(x)` on text. Every token is a
/// light/dark pair, and the ones that carry text or UI parts also declare an Increase Contrast pair.
/// `PaletteContrastTests` measures every text/background pair in all four combinations, so change a value and the
/// tests say if it still passes.
///
/// Roles are kept apart on purpose: brand identity (`rose`, `sage`, `ivory`, `brandMark`), neutral surfaces and
/// foregrounds, the primary action, selection, the brand families (card fill, badge, accent) and the semantic
/// statuses (amber, coral), which never borrow a decorative family color.
///
/// Ink-on-surface rules the tests encode: `ink3` is for icons only (never text); `sage` and `rose` fills never sit
/// behind small text; text on a brand card fill uses `onBrandCard`, never `ink2`.
enum Palette {
    // MARK: Surfaces and ink

    static let bg = Color(light: 0xFAF7F1, dark: 0x191D19)
    static let surface = Color(light: 0xFFFFFF, dark: 0x252B25)
    /// The elevated neutral surface: input fill, wells, quiet round buttons.
    static let sunken = Color(light: 0xF3EFE7, dark: 0x30382F)
    /// Card borders and dividers. Decorative, so it may stay below 3:1.
    static let hairline = Color(light: 0xD5D8CF, dark: 0x566151, lightIncreased: 0xA3A89B, darkIncreased: 0x7C8975)
    static let ink = Color(light: 0x272522, dark: 0xF7F2E8)
    static let ink2 = Color(light: 0x625F59, dark: 0xC6C4B9, lightIncreased: 0x4A4743, darkIncreased: 0xDEDCD2)
    /// Tertiary icons only, never text.
    static let ink3 = Color(light: 0x888781, dark: 0x8D9787)
    /// Input and secondary-button borders. Darker than the separator so it reaches the 3:1 that WCAG 1.4.11 asks of
    /// a field boundary, on the page, a card and the input fill.
    static let fieldBorder = Color(light: 0x7E8078, dark: 0x82907C, lightIncreased: 0x5C5F57, darkIncreased: 0xA9B5A3)

    // MARK: Primary action

    /// Fill of the one primary button of a screen and of check discs and filled progress. Ivory on it is 5.45:1 in
    /// light and 4.82:1 in dark. On a dark card the fill is 2.8:1, so a check disc there relies on its ivory glyph and
    /// selected outlines use `selectionInk`. The dark Increase Contrast fill stays put (a darker one would sink into the
    /// page) and the label turns white instead.
    static let action = Color(light: 0x4F6B4D, dark: 0x57744E, lightIncreased: 0x435A41)
    /// Label and glyph on `action`.
    static let onAction = Color(light: 0xFAF5EB, dark: 0xFAF5EB, darkIncreased: 0xFFFFFF)

    // MARK: Selection

    /// Fill of a selected chip, day or option. Close to the page in light (1.4:1), so a selected element always pairs
    /// it with a `selectionInk` ring or a check: the fill alone never carries the state.
    static let selectionFill = Color(light: 0xCADAC2, dark: 0x435C3C)
    /// Label of a selected element and its ring; also the tab bar tint (the native bar draws its own selection
    /// pill).
    static let selectionInk = Color(light: 0x3C5638, dark: 0xF7F2E8, lightIncreased: 0x2E442B, darkIncreased: 0xFFFBF3)

    // MARK: Brand identity (logo swatches, never retinted)

    /// Dots, ring accents and glows. Never behind small text.
    static let rose = Color(hex: 0xC98F9F)
    /// Switch on-track and success graphics.
    static let sage = Color(light: 0x6E8266, dark: 0x8FA585)
    static let ivory = Color(hex: 0xFAF5EB)
    /// The mark's tile: the app icon's sage, and its darker sage in dark mode.
    static let brandMark = Color(light: 0x6E8266, dark: 0x344B3C)

    // MARK: Brand families: card fills, text on them, badges

    /// Solid fills of insight tiles and empty-state shapes. Decorative against the page (they need no 3:1 there);
    /// text on them is `onBrandCard`.
    static let sageFill = Color(light: 0xBDD0B3, dark: 0x3B5540)
    static let peachFill = Color(light: 0xF0C5A6, dark: 0x704B37)
    static let roseFill = Color(light: 0xE3B5C7, dark: 0x684353)
    /// Text on a brand card fill: 9.13 / 9.42 / 8.32:1 on sage / peach / rose in light, 7.35 / 6.84 / 7.48:1 in dark.
    static let onBrandCard = Color(light: 0x252823, dark: 0xF7F2E8, lightIncreased: 0x1A1C18, darkIncreased: 0xFFFFFF)
    /// Icon discs on a brand card: ivory with the dark family accent in light, a deeper family surface with the light
    /// family accent in dark (never a generic black circle). The icon is the family's `…Text` token.
    static let sageBadge = Color(light: 0xFAF5EB, dark: 0x2C4231)
    static let peachBadge = Color(light: 0xFAF5EB, dark: 0x573626)
    static let roseBadge = Color(light: 0xFAF5EB, dark: 0x52323F)

    // MARK: Rose

    /// Rose icon/accent: links, action text, focus ring, icons.
    static let roseText = Color(light: 0x8D4761, dark: 0xF2B8CE, lightIncreased: 0x6F364C, darkIncreased: 0xF9D3E1)
    static let roseWash = Color(light: 0xF7E8EE, dark: 0x3B2A31)
    static let roseDeepWash = Color(light: 0xEFD6E0, dark: 0x4A3440)
    /// Small text on the deeper rose washes and counts that need more weight than a link.
    static let roseDeepText = Color(light: 0x7A3B53, dark: 0xF8CBDB, lightIncreased: 0x5E2C40, darkIncreased: 0xFDE3EC)

    // MARK: Sage

    /// Sage icon/accent: confirmed and success text, icons.
    static let sageText = Color(light: 0x4F6B4D, dark: 0xBDDAAA, lightIncreased: 0x3C5638, darkIncreased: 0xD3E8C4)
    static let sageWash = Color(light: 0xE8EFE2, dark: 0x2A372A)
    static let sageDeepWash = Color(light: 0xD9E5D0, dark: 0x34472F)

    // MARK: Peach

    static let peach = Color(hex: 0xE8B49E)
    /// Peach icon/accent.
    static let peachText = Color(light: 0x8F5235, dark: 0xFFD1AF, lightIncreased: 0x70402A, darkIncreased: 0xFFE2CC)
    static let peachWash = Color(light: 0xFBECE1, dark: 0x3D2C22)

    // MARK: Amber and coral (status, never decorative)

    static let amberText = Color(light: 0x7A5C16, dark: 0xE8CD85, lightIncreased: 0x5C450F, darkIncreased: 0xF3DCA0)
    static let amberBg = Color(light: 0xF6ECD6, dark: 0x3B3118)
    /// Needs attention: allergies, reactions, safety notices, destructive actions.
    static let coralText = Color(light: 0x9A4535, dark: 0xF2A99B, lightIncreased: 0x7A3225, darkIncreased: 0xF7C0B5)
    static let coralBg = Color(light: 0xF8E1DC, dark: 0x40231F)

    // MARK: Neutral

    static let neutralWash = Color(light: 0xEADFD2, dark: 0x3A3630)
    static let neutralText = Color(light: 0x4A4036, dark: 0xE2D6C8, lightIncreased: 0x2F2822, darkIncreased: 0xF0E6DA)

    // MARK: Semantic aliases

    /// Tint for interactive text and links. System controls that need a fill use `sage` or `action`.
    static let accent = roseText
    /// Only where the operating system expects a link.
    static let systemBlue = Color(light: 0x0062CC, dark: 0x6EB1FF)
}
