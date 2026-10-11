//
//  RecordContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// The text pairs the record screens (4.7, 4.9, 4.10) and the AI settings (7.5) draw, in every appearance.
@Suite("Record screens contrast")
struct RecordContrastTests {
    private static func pair(
        _ name: String, _ foreground: Color, _ background: Color, minimum: Double = 4.5
    ) -> ContrastPair {
        ContrastPair(name: name, foreground: foreground, background: background, minimum: minimum)
    }

    private static let pairs: [ContrastPair] = [
        pair("titles: ink on the screen", Palette.ink, Palette.bg),
        pair("hints and dates: ink2 on the screen", Palette.ink2, Palette.bg),
        pair("trail text: ink on the card", Palette.ink, Palette.surface),
        pair("trail detail and dates: ink2 on the card", Palette.ink2, Palette.surface),
        pair("locks in: amberText on the card", Palette.amberText, Palette.surface),
        pair("locked chip: sageText on the chip", Palette.sageText, Palette.sageWash),
        pair("open chip: amberText on the chip", Palette.amberText, Palette.amberBg),
        pair("lock notice: sageText on sageWash", Palette.sageText, Palette.sageWash),
        pair("correction current value: ink on sunken", Palette.ink, Palette.sunken),
        pair("correction placeholder: ink2 on sunken", Palette.ink2, Palette.sunken),
        pair("validation: coralText on the screen", Palette.coralText, Palette.bg),
        pair("severity moderate: amberText on its chip", Palette.amberText, Palette.amberBg),
        pair("What it never does bullets: coralText on the card", Palette.coralText, Palette.surface),
        pair("What it does bullets: sageText on the card", Palette.sageText, Palette.surface),
        pair("export row title: ink on the card", Palette.ink, Palette.surface),
        pair("export row detail: ink2 on the card", Palette.ink2, Palette.surface),
        pair("slider labels: ink on the card", Palette.ink, Palette.surface),
        pair("photo placeholder icon: ink2 on sunken", Palette.ink2, Palette.sunken, minimum: 3)
    ]

    @Test("Every pair the record screens draw is readable in every appearance", arguments: Appearance.all)
    @MainActor
    func pairsAreReadable(appearance: Appearance) {
        for pair in Self.pairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
