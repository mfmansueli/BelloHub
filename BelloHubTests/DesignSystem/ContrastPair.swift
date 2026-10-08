//
//  ContrastPair.swift
//  BelloHubTests
//

import SwiftUI
import Testing
import UIKit

/// One text-on-background or part-on-background pair, resolved in a given appearance.
struct ContrastPair: Sendable {
    let name: String
    let foreground: Color
    let background: Color
    /// 4.5 for text, 3 for large text, informative icons and field borders.
    let minimum: Double

    func ratio(in appearance: Appearance) -> Double {
        ContrastRatio.between(
            UIColor(foreground).resolvedColor(with: appearance.traits),
            UIColor(background).resolvedColor(with: appearance.traits)
        )
    }
}

/// The four combinations every token is measured in.
struct Appearance: Sendable, CustomTestStringConvertible {
    let isDark: Bool
    let isIncreasedContrast: Bool

    static let all = [
        Appearance(isDark: false, isIncreasedContrast: false),
        Appearance(isDark: true, isIncreasedContrast: false),
        Appearance(isDark: false, isIncreasedContrast: true),
        Appearance(isDark: true, isIncreasedContrast: true)
    ]

    var traits: UITraitCollection {
        UITraitCollection { traits in
            traits.userInterfaceStyle = isDark ? .dark : .light
            traits.accessibilityContrast = isIncreasedContrast ? .high : .normal
        }
    }

    var testDescription: String {
        "\(isDark ? "dark" : "light")\(isIncreasedContrast ? " + Increase Contrast" : "")"
    }
}
