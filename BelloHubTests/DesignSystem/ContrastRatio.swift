//
//  ContrastRatio.swift
//  BelloHubTests
//

import UIKit

/// WCAG 2.2 contrast ratio between two colors. Test-only: it exists to prove the `Palette`
/// tokens meet AA, and nothing in the app needs it at runtime.
enum ContrastRatio {
    static func between(_ first: UIColor, _ second: UIColor) -> Double {
        let lighter = max(luminance(of: first), luminance(of: second))
        let darker = min(luminance(of: first), luminance(of: second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(of color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static func linear(_ channel: CGFloat) -> Double {
        let value = Double(channel)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
