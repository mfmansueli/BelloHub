//
//  HeroPalette.swift
//  BelloHub
//

import SwiftUI

/// The hero surface is dark in both appearances, so its colors do not switch. Since the 2026-10-10 "graphite and
/// orange" palette it is a neutral graphite with an orange glow in one corner and a faint warm glow in the other. Text
/// on it is measured at the lightest point of the glow, not the average (CLAUDE.md section 5).
///
/// `glowRose` and `glowSage` keep their names from the earlier palette (the tests and `GlowBackdrop` refer to them);
/// they are now the orange glow and the faint warm one.
enum HeroPalette {
    static let gradientStart = Color(hex: 0x262626)
    static let gradientEnd = Color(hex: 0x141414)
    static let glowRose = Color(hex: 0xFF5A1F)
    static let glowSage = Color(hex: 0xFFB48A)
    /// Peak opacity of each glow, which sets the worst-case background for text.
    static let glowRoseOpacity = 0.34
    static let glowSageOpacity = 0.10
    /// Peak opacity of the "mist", a second orange cloud that wanders over an animated hero (`HeroSurface`). Where it
    /// overlaps the orange glow the two add up to `worstGlowOpacity`, which the contrast tests measure.
    static let mistOpacity = 0.16
    /// The strongest orange anywhere on an animated hero: the glow and the mist at their peaks, on top of each other.
    static var worstGlowOpacity: Double { 1 - (1 - glowRoseOpacity) * (1 - mistOpacity) }
    /// Primary text on the hero.
    static let ink = Color(hex: 0xFFFFFF)
    /// Secondary text on the hero. A solid color, so no `.opacity` is ever applied to text.
    static let ink2 = Color(hex: 0xD6D6D3)
    /// Quiet chips and secondary buttons on the hero (a lighter graphite).
    static let raised = Color(hex: 0x3A3A3A)
}
