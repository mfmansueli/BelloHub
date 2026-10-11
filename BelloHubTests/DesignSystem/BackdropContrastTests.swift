//
//  BackdropContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing
import UIKit

/// Text in the top area of the entry screens sits on `GlowBackdrop`: the page color with a faint rose glow and a
/// faint sage glow. The worst point is where a glow is strongest, so the test mixes each glow at its peak opacity
/// over the page color and measures the text tokens allowed there (CLAUDE.md section 5: the worst point, not the
/// average). `roseText` is not allowed on a glow: it only reaches 4.0:1 there, so links sit on the plain page color.
@MainActor
@Suite("GlowBackdrop contrast")
struct BackdropContrastTests {
    private static let roseGlowPeak = GlowBackdrop.rosePeak
    private static let sageGlowPeak = GlowBackdrop.sagePeak

    /// `color` painted at `opacity` over `base`, in the given appearance, as one solid color.
    private func blended(_ color: Color, opacity: Double, over base: Color, in appearance: Appearance) -> Color {
        let top = UIColor(color).resolvedColor(with: appearance.traits)
        let bottom = UIColor(base).resolvedColor(with: appearance.traits)
        var (tr, tg, tb, ta) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        var (br, bg, bb, ba) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let mix = { (foreground: CGFloat, background: CGFloat) in foreground * opacity + background * (1 - opacity) }
        return Color(red: mix(tr, br), green: mix(tg, bg), blue: mix(tb, bb))
    }

    @Test("Text allowed on a glow keeps 4.5:1 on its strongest point", arguments: Appearance.all)
    func text(appearance: Appearance) {
        let worstBackgrounds = [
            ("rose glow", blended(Palette.rose, opacity: Self.roseGlowPeak, over: Palette.bg, in: appearance)),
            ("sage glow", blended(HeroPalette.glowSage, opacity: Self.sageGlowPeak, over: Palette.bg, in: appearance))
        ]
        let tokens: [(String, Color)] = [
            ("ink", Palette.ink), ("ink2", Palette.ink2), ("coralText", Palette.coralText)
        ]
        for (backgroundName, background) in worstBackgrounds {
            for (name, foreground) in tokens {
                let pair = ContrastPair(name: "\(name) on \(backgroundName)", foreground: foreground,
                                        background: background, minimum: 4.5)
                #expect(pair.ratio(in: appearance) >= pair.minimum, "\(pair.name) in \(appearance)")
            }
        }
    }
}
