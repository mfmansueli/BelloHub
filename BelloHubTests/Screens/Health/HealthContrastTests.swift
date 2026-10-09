//
//  HealthContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

/// The text and parts the health and consent screens draw, and where each pair is measured (CLAUDE.md section 5: every
/// text and background pair has a test). The screens use only `Palette` tokens, so the pairs are the ones
/// `PaletteContrastTests` already measures in light, dark and both with Increase Contrast; this suite pins which
/// pairs the screens rely on and measures them again, so a screen that starts to use a new pair fails here until the
/// pair is added to the palette tests.
@Suite("Health screens contrast")
struct HealthContrastTests {
    /// Text on the page, on cards and in fields: titles, answers, labels, notes, placeholders, the language menu,
    /// "Record patch test", the error line under a save button, the status chips and the primary button.
    private static let textPairNames = [
        "ink on bg", "ink on surface", "ink on sunken", "ink2 on bg", "ink2 on surface", "ink2 on sunken",
        "roseText on surface", "sageText on sageWash", "coralText on bg", "coralText on surface",
        "coralText on coralBg", "StatusPalette.confirmed", "StatusPalette.pending", "StatusPalette.attention",
        "inkOnFill on ink (primary button)"
    ]

    /// The field border, the chevrons and the icons beside text, and the switch of the agreement.
    private static let partPairNames = [
        "fieldBorder on sunken (input fill)", "fieldBorder on surface", "ink3 icon on surface",
        "sage on surface"
    ]

    @Test("Every pair the screens use is in the palette tests")
    func pairsAreMeasured() {
        let measuredText = Set(PaletteContrastTests.textPairs.map(\.name))
        let measuredParts = Set(PaletteContrastTests.partPairs.map(\.name))
        for name in Self.textPairNames { #expect(measuredText.contains(name), "\(name) is not measured") }
        for name in Self.partPairNames { #expect(measuredParts.contains(name), "\(name) is not measured") }
    }

    @Test("They reach 4.5:1 for text and 3:1 for parts in every appearance", arguments: Appearance.all)
    @MainActor
    func meetAA(appearance: Appearance) {
        let pairs = PaletteContrastTests.textPairs.filter { Self.textPairNames.contains($0.name) }
            + PaletteContrastTests.partPairs.filter { Self.partPairNames.contains($0.name) }
        #expect(pairs.count == Self.textPairNames.count + Self.partPairNames.count)
        for pair in pairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
