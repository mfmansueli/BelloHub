//
//  HeroPalette.swift
//  BelloHub
//

import SwiftUI

/// The hero surface is dark in both appearances, so its colors do not switch. Since the 2026-10-10 color refinement it
/// is a green-graphite from the dark neutral family (not the old warm graphite), so it sits with the sage brand. Text
/// on it is measured at the lightest point of the glow, not the average (CLAUDE.md section 5).
enum HeroPalette {
    static let gradientStart = Color(hex: 0x2F362E)
    static let gradientEnd = Color(hex: 0x232823)
    static let glowRose = Color(hex: 0xC98F9F)
    static let glowSage = Color(hex: 0xA9B5A1)
    /// Peak opacity of each glow, which sets the worst-case background for text.
    static let glowRoseOpacity = 0.30
    static let glowSageOpacity = 0.22
    /// Primary text on the hero: the brand ivory.
    static let ink = Color(hex: 0xFAF5EB)
    /// Secondary text on the hero. A solid color, so no `.opacity` is ever applied to text.
    static let ink2 = Color(hex: 0xDAD8CE)
    /// Quiet chips and secondary buttons on the hero (a lighter green-graphite).
    static let raised = Color(hex: 0x48524A)
}
