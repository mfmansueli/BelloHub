//
//  PaletteContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing
import UIKit

@Suite("Palette contrast")
struct PaletteContrastTests {
    private static func text(_ name: String, _ foreground: Color, on background: Color, minimum: Double = 4.5)
        -> ContrastPair {
        ContrastPair(name: name, foreground: foreground, background: background, minimum: minimum)
    }

    /// Every text token on every surface it is allowed on. `roseText` is deliberately absent from
    /// `roseWash` (4.49:1 in light): small text on a rose wash uses `roseDeepText`.
    static let textPairs: [ContrastPair] = [
        text("ink on bg", Palette.ink, on: Palette.bg),
        text("ink on surface", Palette.ink, on: Palette.surface),
        text("ink on sunken", Palette.ink, on: Palette.sunken),
        text("ink2 on bg", Palette.ink2, on: Palette.bg),
        text("ink2 on surface", Palette.ink2, on: Palette.surface),
        text("ink2 on sunken", Palette.ink2, on: Palette.sunken),
        text("inkOnFill on ink (primary button)", Palette.inkOnFill, on: Palette.ink),
        text("roseText on bg", Palette.roseText, on: Palette.bg),
        text("roseText on surface", Palette.roseText, on: Palette.surface),
        text("accent on bg", Palette.accent, on: Palette.bg),
        text("accent on surface", Palette.accent, on: Palette.surface),
        text("roseDeepText on roseWash", Palette.roseDeepText, on: Palette.roseWash),
        text("roseDeepText on roseDeepWash", Palette.roseDeepText, on: Palette.roseDeepWash),
        text("sageText on bg", Palette.sageText, on: Palette.bg),
        text("sageText on surface", Palette.sageText, on: Palette.surface),
        text("sageText on sageWash", Palette.sageText, on: Palette.sageWash),
        text("sageText on sageDeepWash", Palette.sageText, on: Palette.sageDeepWash),
        text("peachText on peachWash", Palette.peachText, on: Palette.peachWash),
        text("amberText on amberBg", Palette.amberText, on: Palette.amberBg),
        text("coralText on bg", Palette.coralText, on: Palette.bg),
        text("coralText on surface", Palette.coralText, on: Palette.surface),
        text("coralText on coralBg", Palette.coralText, on: Palette.coralBg),
        text("neutralText on neutralWash", Palette.neutralText, on: Palette.neutralWash),
        text("StatusPalette.confirmed", StatusPalette.confirmed.foreground, on: StatusPalette.confirmed.background),
        text("StatusPalette.pending", StatusPalette.pending.foreground, on: StatusPalette.pending.background),
        text("StatusPalette.nextUp", StatusPalette.nextUp.foreground, on: StatusPalette.nextUp.background),
        text("StatusPalette.completed", StatusPalette.completed.foreground, on: StatusPalette.completed.background),
        text("StatusPalette.attention", StatusPalette.attention.foreground, on: StatusPalette.attention.background)
    ]

    /// Parts of the interface and informative icons need 3:1 (WCAG 1.4.11). `ink3` is icons only.
    static let partPairs: [ContrastPair] = [
        text("ink3 icon on bg", Palette.ink3, on: Palette.bg, minimum: 3),
        text("ink3 icon on surface", Palette.ink3, on: Palette.surface, minimum: 3),
        text("fieldBorder on bg", Palette.fieldBorder, on: Palette.bg, minimum: 3),
        text("fieldBorder on surface", Palette.fieldBorder, on: Palette.surface, minimum: 3),
        text("fieldBorder on sunken (input fill)", Palette.fieldBorder, on: Palette.sunken, minimum: 3),
        text("sage (switch track, success) on bg", Palette.sage, on: Palette.bg, minimum: 3),
        text("sage on surface", Palette.sage, on: Palette.surface, minimum: 3)
    ]

    @Test("Every text pair reaches 4.5:1 in every appearance", arguments: Appearance.all)
    func textPairsMeetAA(appearance: Appearance) {
        for pair in Self.textPairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }

    @Test("Every UI part and informative icon reaches 3:1 in every appearance", arguments: Appearance.all)
    func partPairsMeetNonTextContrast(appearance: Appearance) {
        for pair in Self.partPairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }

    @Test("Increase Contrast never lowers a ratio", arguments: [false, true])
    func increasedContrastIsNeverWorse(isDark: Bool) {
        let normal = Appearance(isDark: isDark, isIncreasedContrast: false)
        let increased = Appearance(isDark: isDark, isIncreasedContrast: true)

        for pair in Self.textPairs + Self.partPairs {
            #expect(
                pair.ratio(in: increased) >= pair.ratio(in: normal) - 0.001,
                "\(pair.name) got worse with Increase Contrast (\(isDark ? "dark" : "light"))"
            )
        }
    }

    @Test("The documented quirk holds: roseText on roseWash is below AA in light, so it is not used")
    func roseTextOnRoseWashIsBelowAAInLight() {
        let light = Appearance(isDark: false, isIncreasedContrast: false)
        let pair = Self.text("roseText on roseWash", Palette.roseText, on: Palette.roseWash)

        #expect(pair.ratio(in: light) < 4.5)
    }
}
