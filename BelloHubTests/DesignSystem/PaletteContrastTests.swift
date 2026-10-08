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
    private static let textTokens: [(name: String, color: Color)] = [
        ("ink", Palette.ink),
        ("ink2", Palette.ink2),
        ("accent", Palette.accent)
    ]

    private static let surfaceTokens: [(name: String, color: Color)] = [
        ("bg", Palette.bg),
        ("surface", Palette.surface)
    ]

    @Test("Every text token reaches 4.5:1 on every surface", arguments: [UIUserInterfaceStyle.light, .dark])
    func textTokensMeetAA(style: UIUserInterfaceStyle) {
        let traits = UITraitCollection(userInterfaceStyle: style)

        for text in Self.textTokens {
            for surface in Self.surfaceTokens {
                let ratio = ContrastRatio.between(
                    UIColor(text.color).resolvedColor(with: traits),
                    UIColor(surface.color).resolvedColor(with: traits)
                )

                #expect(ratio >= 4.5, "\(text.name) on \(surface.name) is \(ratio):1 in style \(style.rawValue)")
            }
        }
    }
}
