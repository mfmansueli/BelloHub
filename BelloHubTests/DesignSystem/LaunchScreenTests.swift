//
//  LaunchScreenTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing
import UIKit

/// The launch screen is a plain colour, the page colour of the app (S12), so launch goes from it to the first screen
/// without a white or black flash. The colour set is a copy of `Palette.bg`; this keeps the two equal.
@MainActor
@Suite("Launch screen")
struct LaunchScreenTests {
    @Test("The Info.plist launch screen names the LaunchBackground colour")
    func infoPlist() throws {
        let launch = try #require(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any])
        #expect(launch["UIColorName"] as? String == "LaunchBackground")
    }

    @Test("LaunchBackground equals Palette.bg in light and dark", arguments: [UIUserInterfaceStyle.light, .dark])
    func matchesPalette(style: UIUserInterfaceStyle) throws {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let asset = try #require(UIColor(named: "LaunchBackground", in: .main, compatibleWith: traits))
        let token = UIColor(Palette.bg).resolvedColor(with: traits)
        #expect(Self.rgb(asset.resolvedColor(with: traits)) == Self.rgb(token))
    }

    private static func rgb(_ color: UIColor) -> [Int] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].map { Int(($0 * 255).rounded()) }
    }
}
