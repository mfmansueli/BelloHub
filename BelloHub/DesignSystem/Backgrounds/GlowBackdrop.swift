//
//  GlowBackdrop.swift
//  BelloHub
//

import SwiftUI

/// The soft background of the entry screens: the page color with a faint rose glow from the top leading corner and
/// a sage one from the top trailing corner. Static, so Reduce Motion needs nothing from it.
///
/// Contrast: the glows end 300 and 240 pt from their corners, so everything lower on the screen sits on the plain page
/// color. In the glow area only `ink`, `ink2` and `coralText` may be used; `roseText` links are 4.0:1 on a glow's
/// strongest point, so they live lower down (`BackdropContrastTests` measures it).
struct GlowBackdrop: View {
    /// Opacity of each glow at its corner, the worst case for text on it.
    static let rosePeak = 0.16
    static let sagePeak = 0.16

    var body: some View {
        ZStack {
            Palette.bg
            RadialGradient(
                colors: [Palette.rose.opacity(Self.rosePeak), .clear], center: .topLeading, startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [HeroPalette.glowSage.opacity(Self.sagePeak), .clear], center: .topTrailing, startRadius: 0,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
