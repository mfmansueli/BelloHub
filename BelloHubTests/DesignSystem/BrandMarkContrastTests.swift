//
//  BrandMarkContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// The mark on the lock screen and the privacy cover is the app icon itself (routine-a item 2): its colors are the
/// icon's, measured here so a palette change can never make it unreadable. The "b" on the tile is a graphic and needs
/// 3:1; the tile against the page is measured in light, where it is the outline of the logo. In dark the tile is the
/// near-black iOS gives the icon and the "b" carries the logo.
@Suite("Brand mark contrast")
struct BrandMarkContrastTests {
    @Test("The b reads on the tile in every appearance", arguments: Appearance.all)
    @MainActor
    func letterOnTile(appearance: Appearance) {
        let pair = ContrastPair(
            name: "letter on tile", foreground: BrandPalette.letter, background: BrandPalette.tile, minimum: 3
        )
        let ratio = pair.ratio(in: appearance)
        #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
    }

    @Test("The tile stands out from the page in light", arguments: [false, true])
    @MainActor
    func tileOnPageInLight(isIncreasedContrast: Bool) {
        let appearance = Appearance(isDark: false, isIncreasedContrast: isIncreasedContrast)
        let pair = ContrastPair(name: "tile on bg", foreground: BrandPalette.tile, background: Palette.bg, minimum: 3)
        #expect(pair.ratio(in: appearance) >= pair.minimum)
    }

    @Test("The b stands out from the page in dark", arguments: [false, true])
    @MainActor
    func letterOnPageInDark(isIncreasedContrast: Bool) {
        let appearance = Appearance(isDark: true, isIncreasedContrast: isIncreasedContrast)
        let pair = ContrastPair(name: "letter on bg", foreground: BrandPalette.letter, background: Palette.bg,
                                minimum: 4.5)
        #expect(pair.ratio(in: appearance) >= pair.minimum)
    }

    @Test("The mark's two layers are in the app and share one square canvas")
    @MainActor
    func layers() throws {
        let relief = try #require(UIImage(named: "BrandMarkRelief"))
        let front = try #require(UIImage(named: "BrandMarkFront"))
        #expect(relief.size == front.size, "the layers must line up without an offset")
        #expect(relief.size.width == relief.size.height)
    }
}
