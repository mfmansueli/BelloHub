//
//  HeroContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing
import UIKit

/// Text on the hero is measured at the lightest point of the glow, not the average
/// (CLAUDE.md section 5): the glow at its peak opacity over the start of the gradient.
@Suite("Hero contrast")
struct HeroContrastTests {
    private struct RGB {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
    }

    private static func components(of color: UIColor) -> RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.resolvedColor(with: UITraitCollection()).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGB(red: red, green: green, blue: blue)
    }

    private static func worstCase(glow: Color, opacity: Double) -> UIColor {
        let base = components(of: UIColor(HeroPalette.gradientStart))
        let overlay = components(of: UIColor(glow))
        let mix = { (over: CGFloat, under: CGFloat) in over * opacity + under * (1 - opacity) }
        return UIColor(
            red: mix(overlay.red, base.red), green: mix(overlay.green, base.green), blue: mix(overlay.blue, base.blue),
            alpha: 1
        )
    }

    private static let worstPoints: [(name: String, color: UIColor)] = [
        ("rose glow peak", worstCase(glow: HeroPalette.glowRose, opacity: HeroPalette.glowRoseOpacity)),
        ("sage glow peak", worstCase(glow: HeroPalette.glowSage, opacity: HeroPalette.glowSageOpacity)),
        ("gradient start", UIColor(HeroPalette.gradientStart)),
        ("gradient end", UIColor(HeroPalette.gradientEnd))
    ]

    @Test("Primary hero text reaches 4.5:1 at every point of the surface")
    func heroInkMeetsAA() {
        for point in Self.worstPoints {
            let ratio = ContrastRatio.between(UIColor(HeroPalette.ink), point.color)
            #expect(ratio >= 4.5, "hero ink on \(point.name) is \(ratio):1")
        }
    }

    @Test("Secondary hero text reaches 4.5:1 at every point of the surface")
    func heroInk2MeetsAA() {
        for point in Self.worstPoints {
            let ratio = ContrastRatio.between(UIColor(HeroPalette.ink2), point.color)
            #expect(ratio >= 4.5, "hero ink2 on \(point.name) is \(ratio):1")
        }
    }

    @Test("The next-up dot (the logo rose) reaches 3:1 on both ends of the hero gradient")
    func nextUpDotIsVisible() {
        for point in Self.worstPoints where point.name.hasPrefix("gradient") {
            let ratio = ContrastRatio.between(UIColor(HeroPalette.glowRose), point.color)
            #expect(ratio >= 3, "next-up dot on \(point.name) is \(ratio):1")
        }
    }

    @Test("Quiet hero chips and buttons keep their label at 4.5:1")
    func raisedSurfaceKeepsLabelsReadable() {
        let ratio = ContrastRatio.between(UIColor(HeroPalette.ink), UIColor(HeroPalette.raised))

        #expect(ratio >= 4.5, "hero ink on raised is \(ratio):1")
    }
}
