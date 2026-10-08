//
//  Palette.swift
//  BelloHub
//

import SwiftUI

/// Semantic color tokens (docs/08-DESIGN-SYSTEM.md section 2). Screens use these names and never
/// hex values or `.opacity(x)` on text. Every token is a light/dark pair, and the ones that carry
/// text or UI parts also declare an Increase Contrast pair. `PaletteContrastTests` measures every
/// text/background pair in all four combinations, so change a value and the tests say if it still passes.
///
/// Ink-on-surface rules the tests encode: `ink3` is for icons only (never text); on a rose wash use
/// `roseDeepText` for small text (`roseText` on `roseWash` is 4.49:1 in light); `sage` and `rose`
/// fills never sit behind small text.
enum Palette {
    // MARK: Surfaces and ink

    static let bg = Color(light: 0xF8F6F2, dark: 0x161412)
    static let surface = Color(light: 0xFFFCF8, dark: 0x1F1C1A)
    static let sunken = Color(light: 0xEFEBE4, dark: 0x272320)
    /// Card borders and dividers. Decorative, so it may stay below 3:1.
    static let hairline = Color(light: 0xECE7DF, dark: 0x34302C, lightIncreased: 0xBDB6AB, darkIncreased: 0x5A544E)
    static let ink = Color(light: 0x242321, dark: 0xF5F1EA)
    /// Text on the primary button, whose fill is `ink` (it inverts in dark).
    static let inkOnFill = Color(light: 0xFFFCF8, dark: 0x161412)
    static let ink2 = Color(light: 0x65625D, dark: 0xB5AEA5, lightIncreased: 0x4A4743, darkIncreased: 0xD3CDC5)
    /// Tertiary icons only, never text.
    static let ink3 = Color(light: 0x8C8984, dark: 0x8C857D)
    /// Input and secondary-button borders. Darker than the prototype's soft border so it reaches
    /// the 3:1 that WCAG 1.4.11 asks of a field boundary (the prototype's is 1.4:1).
    static let fieldBorder = Color(light: 0x86817A, dark: 0x7A736B, lightIncreased: 0x5F5B56, darkIncreased: 0xA39C93)

    // MARK: Rose

    /// Dots, ring accents and glows. Never behind small text.
    static let rose = Color(hex: 0xC98F9F)
    /// Links and action text on `bg` and `surface`.
    static let roseText = Color(light: 0x9A5A6C, dark: 0xE3A8B7, lightIncreased: 0x7E4757, darkIncreased: 0xF2C4D0)
    static let roseWash = Color(light: 0xF7ECEE, dark: 0x3A2A2F)
    static let roseDeepWash = Color(light: 0xF0DCE1, dark: 0x4A343A)
    static let roseDeepText = Color(light: 0x7E4757, dark: 0xF2C4D0, lightIncreased: 0x5E3342, darkIncreased: 0xFADDE5)

    // MARK: Sage

    /// Switch on-track and success graphics.
    static let sage = Color(light: 0x6E8266, dark: 0x8FA585)
    static let sageText = Color(light: 0x56684F, dark: 0xB9CBAE, lightIncreased: 0x3F4F39, darkIncreased: 0xD0DEC6)
    static let sageWash = Color(light: 0xEEF2EA, dark: 0x263023)
    static let sageDeepWash = Color(light: 0xDFE6D9, dark: 0x30402C)

    // MARK: Peach

    static let peach = Color(hex: 0xE8B49E)
    static let peachText = Color(light: 0x8A5238, dark: 0xEBBFA9, lightIncreased: 0x6B3F29, darkIncreased: 0xF3D0BC)
    static let peachWash = Color(light: 0xFBEFE7, dark: 0x36281F)

    // MARK: Amber and coral (status)

    static let amberText = Color(light: 0x7A5C16, dark: 0xE8CD85, lightIncreased: 0x5C450F, darkIncreased: 0xF3DCA0)
    static let amberBg = Color(light: 0xF6ECD6, dark: 0x3B3118)
    /// Needs attention: allergies, reactions, safety notices.
    static let coralText = Color(light: 0x9A4535, dark: 0xF2A99B, lightIncreased: 0x7A3225, darkIncreased: 0xF7C0B5)
    static let coralBg = Color(light: 0xF8E1DC, dark: 0x40231F)

    // MARK: Neutral

    static let neutralWash = Color(light: 0xEADFD2, dark: 0x2F2923)
    static let neutralText = Color(light: 0x4A4036, dark: 0xE2D6C8, lightIncreased: 0x2F2822, darkIncreased: 0xF0E6DA)

    // MARK: Semantic aliases

    /// Tint for interactive text and links. System controls that need a fill use `sage` or `ink`.
    static let accent = roseText
    /// Only where the operating system expects a link.
    static let systemBlue = Color(light: 0x0062CC, dark: 0x6EB1FF)
}
