//
//  TagColor.swift
//  BelloHub
//

import SwiftUI

/// The four colors a client tag can have. A tag stores one of these as a semantic token string (`rose`, `sage`,
/// `peach`, `sand`), never a hex value, so a palette change reaches every tag and a tag saved by a newer version with
/// a token this one does not know still draws (`init(token:)` falls back to `sand`).
///
/// Each color has the same four parts, all from `Palette`: a `dot` fill, an `outline` that keeps the dot visible on
/// any surface (the pastel fills alone are about 2:1 on `surface`, below the 3:1 of WCAG 1.4.11; the outline is the
/// text tone of the family and is measured at 3:1 or more), and a `wash` with its `washText` for a chip, which is
/// measured at 4.5:1. `TagColorContrastTests` holds every pair in all four appearances.
enum TagColor: String, CaseIterable, Identifiable, Sendable {
    case rose
    case sage
    case peach
    case sand

    var id: String { rawValue }

    /// The token stored on a `Tag`.
    var token: String { rawValue }

    /// The color for a stored token. An unknown or empty token reads as `sand`, the quietest one.
    init(token: String) {
        self = TagColor(rawValue: token) ?? .sand
    }

    /// Pastel fill of the dot next to a tag name and of a swatch.
    var dot: Color {
        switch self {
        case .rose: Palette.rose
        case .sage: Palette.sage
        case .peach: Palette.peach
        case .sand: AvatarPalette.sand.end
        }
    }

    /// The ring around the dot. At least 3:1 on `surface` and `bg`, so the shape is always perceivable.
    var outline: Color {
        switch self {
        case .rose: Palette.roseText
        case .sage: Palette.sageText
        case .peach: Palette.peachText
        case .sand: Palette.neutralText
        }
    }

    /// Background of a chip in this color.
    var wash: Color {
        switch self {
        case .rose: Palette.roseWash
        case .sage: Palette.sageWash
        case .peach: Palette.peachWash
        case .sand: Palette.neutralWash
        }
    }

    /// Text on `wash`: 4.5:1 or more.
    var washText: Color {
        switch self {
        case .rose: Palette.roseDeepText
        case .sage: Palette.sageText
        case .peach: Palette.peachText
        case .sand: Palette.neutralText
        }
    }

    /// The name VoiceOver and the color choice read ("Rose"). The color is never the only way to tell tags apart: a
    /// tag always has its name next to the dot.
    var name: LocalizedStringResource {
        switch self {
        case .rose: "tag.color.rose"
        case .sage: "tag.color.sage"
        case .peach: "tag.color.peach"
        case .sand: "tag.color.sand"
        }
    }
}
