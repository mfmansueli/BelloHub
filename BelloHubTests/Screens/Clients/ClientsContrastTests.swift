//
//  ClientsContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// The text pairs the Clients screens draw that the shared palette tests do not already measure. The others (ink and
/// ink2 on surface and on bg, roseText on surface for "New", coralText on surface for "Cancels often", roseDeepText on
/// roseWash for the important note and the sensitivity chips, sageText on sageWash for the plan, peachText on peachWash
/// for the strip, amberText on amberBg for the pending chip) are in `PaletteContrastTests`.
@Suite("Clients contrast")
struct ClientsContrastTests {
    private static let pairs: [ContrastPair] = [
        ContrastPair(name: "hero ink on a hero chip", foreground: HeroPalette.ink, background: HeroPalette.raised,
                     minimum: 4.5),
        ContrastPair(name: "hero ink2 on a hero chip", foreground: HeroPalette.ink2, background: HeroPalette.raised,
                     minimum: 4.5)
    ]

    @Test("Every pair the Clients screens add is readable in every appearance", arguments: Appearance.all)
    @MainActor
    func pairsAreReadable(appearance: Appearance) {
        for pair in Self.pairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
