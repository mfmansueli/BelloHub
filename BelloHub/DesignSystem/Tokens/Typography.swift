//
//  Typography.swift
//  BelloHub
//

import SwiftUI

/// One scale, nothing outside it (docs/08-DESIGN-SYSTEM.md section 3). Everything goes through
/// `Font.custom(_:size:relativeTo:)`, so Dynamic Type scales it. Fraunces (500) carries headlines and
/// big numerals; DM Sans (400 and 600) carries the interface. No light weights, nothing under 11 pt,
/// no all-caps eyebrows.
///
/// Fraunces and DM Sans have no Arabic or Devanagari glyphs: iOS falls back per glyph to the system
/// fonts, which are taller, so `lineSpacing(forSize:language:)` adds the 1.15 multiplier for `ar` and `hi`.
enum Typography {
    // MARK: Fraunces (headings, hero times, numerals)

    static let moment = serif(40, relativeTo: .largeTitle)
    static let screenTitle = serif(34, relativeTo: .largeTitle)
    static let title = serif(28, relativeTo: .title)
    static let subtitle = serif(24, relativeTo: .title2)
    static let numeral = serif(24, relativeTo: .title2)

    // MARK: DM Sans (interface)

    static let section = sans(20, relativeTo: .title3, weight: .semibold)
    static let body = sans(17, relativeTo: .body)
    static let bodyStrong = sans(17, relativeTo: .body, weight: .semibold)
    static let callout = sans(16, relativeTo: .callout)
    static let calloutStrong = sans(16, relativeTo: .callout, weight: .semibold)
    static let meta = sans(15, relativeTo: .subheadline)
    static let metaStrong = sans(15, relativeTo: .subheadline, weight: .semibold)
    static let footnote = sans(13, relativeTo: .footnote)
    static let footnoteStrong = sans(13, relativeTo: .footnote, weight: .semibold)
    static let caption = sans(12, relativeTo: .caption, weight: .semibold)
    /// The system tab bar draws its own label; this is for custom uses of the same size.
    static let tabLabel = sans(11, relativeTo: .caption2, weight: .semibold)

    /// Tracking for Fraunces at display sizes, as a fraction of the font size (-0.015 em).
    static let displayTracking: CGFloat = -0.015

    // MARK: Scripts without bundled glyphs

    /// Languages whose system fallback fonts need more line height than the Latin fonts.
    static let tallScriptLanguages: Set<String> = ["ar", "hi"]
    static let tallScriptMultiplier: CGFloat = 1.15

    /// Line height multiplier for a language. Pure, so it is tested without a view.
    static func lineHeightMultiplier(for language: Locale.Language = Locale.current.language) -> CGFloat {
        guard let code = language.languageCode?.identifier else { return 1 }
        return tallScriptLanguages.contains(code) ? tallScriptMultiplier : 1
    }

    /// Extra points between lines for text of `size`, to add through `.lineSpacing(_:)`.
    /// A natural line is about 1.2 times the size, which is what the multiplier scales.
    static func lineSpacing(forSize size: CGFloat, language: Locale.Language = Locale.current.language) -> CGFloat {
        (lineHeightMultiplier(for: language) - 1) * size * 1.2
    }

    // MARK: Builders

    private static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(FontRegistry.serifFamily, size: size, relativeTo: style).weight(.medium)
    }

    private static func sans(
        _ size: CGFloat, relativeTo style: Font.TextStyle, weight: Font.Weight = .regular
    ) -> Font {
        .custom(FontRegistry.sansFamily, size: size, relativeTo: style).weight(weight)
    }
}
