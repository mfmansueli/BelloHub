//
//  Color+LightDark.swift
//  BelloHub
//

import SwiftUI
import UIKit

extension Color {
    /// SwiftUI has no light/dark initializer, so this is the one place a trait-based `UIColor`
    /// is needed. Tokens are declared as hex values and never built by hand in a screen.
    /// `lightIncreased` / `darkIncreased` are used when the user turns on Increase Contrast; they
    /// default to the normal value so a token only declares them when it needs to change.
    init(light: UInt32, dark: UInt32, lightIncreased: UInt32? = nil, darkIncreased: UInt32? = nil) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isIncreased = traits.accessibilityContrast == .high
            let hex: UInt32
            switch (isDark, isIncreased) {
            case (false, false): hex = light
            case (true, false): hex = dark
            case (false, true): hex = lightIncreased ?? light
            case (true, true): hex = darkIncreased ?? dark
            }
            return UIColor(hex: hex)
        })
    }

    /// One color for both appearances (the hero surface is always dark, for example).
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
