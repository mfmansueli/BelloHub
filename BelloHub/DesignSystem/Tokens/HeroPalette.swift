//
//  HeroPalette.swift
//  BelloHub
//

import SwiftUI

/// The graphite hero surface is dark in both appearances, so its colors do not switch. Text on it is
/// measured at the lightest point of the glow, not the average (CLAUDE.md section 5).
enum HeroPalette {
    static let gradientStart = Color(hex: 0x2E2C2A)
    static let gradientEnd = Color(hex: 0x242321)
    static let glowRose = Color(hex: 0xC98F9F)
    static let glowSage = Color(hex: 0xA9B5A1)
    /// Peak opacity of each glow, which sets the worst-case background for text.
    static let glowRoseOpacity = 0.30
    static let glowSageOpacity = 0.22
    /// Primary text on the hero.
    static let ink = Color(hex: 0xFFFCF8)
    /// Secondary text on the hero. A solid color, so no `.opacity` is ever applied to text.
    static let ink2 = Color(hex: 0xE0D9D4)
    /// Quiet chips and secondary buttons on the hero (a lighter graphite).
    static let raised = Color(hex: 0x4A4745)
}
