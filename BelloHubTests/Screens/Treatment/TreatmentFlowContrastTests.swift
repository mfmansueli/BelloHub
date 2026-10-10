//
//  TreatmentFlowContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// The text pairs the treatment flow draws, in every appearance (light, dark, with and without Increase Contrast).
@Suite("Treatment flow contrast")
struct TreatmentFlowContrastTests {
    private static func pair(
        _ name: String, _ foreground: Color, _ background: Color, minimum: Double = 4.5
    ) -> ContrastPair {
        ContrastPair(name: name, foreground: foreground, background: background, minimum: minimum)
    }

    private static let pairs: [ContrastPair] = [
        pair("titles: ink on the screen", Palette.ink, Palette.bg),
        pair("hints and visit details: ink2 on the screen", Palette.ink2, Palette.bg),
        pair("summary rows: ink on the card", Palette.ink, Palette.surface),
        pair("summary labels: ink2 on the card", Palette.ink2, Palette.surface),
        pair("summary title: roseText on the card", Palette.roseText, Palette.surface),
        pair("example card: ink on sunken", Palette.ink, Palette.sunken),
        pair("example card title: ink2 on sunken", Palette.ink2, Palette.sunken),
        pair("saved badge: sageText on sageWash", Palette.sageText, Palette.sageWash),
        pair("review badge: roseDeepText on roseDeepWash", Palette.roseDeepText, Palette.roseDeepWash),
        pair("pending status: amberText on the card", Palette.amberText, Palette.surface),
        pair("kept status: sageText on the card", Palette.sageText, Palette.surface),
        pair("form error: coralText on the screen", Palette.coralText, Palette.bg),
        pair("photo slot icon: ink2 on sunken", Palette.ink2, Palette.sunken, minimum: 3),
        pair("microphone glyph: onAction on the rose disc", Palette.onAction, Palette.rose, minimum: 3)
    ]

    @Test("Every pair the treatment flow draws is readable in every appearance", arguments: Appearance.all)
    @MainActor
    func pairsAreReadable(appearance: Appearance) {
        for pair in Self.pairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
