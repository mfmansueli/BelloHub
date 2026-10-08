//
//  Color+LightDark.swift
//  BelloHub
//

import SwiftUI
import UIKit

extension Color {
    /// SwiftUI has no light/dark initializer, so this is the one place a trait-based `UIColor`
    /// is needed. Tokens are declared as hex pairs and never built by hand in a screen.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
