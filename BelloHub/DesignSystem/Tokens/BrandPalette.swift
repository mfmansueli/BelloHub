//
//  BrandPalette.swift
//  BelloHub
//

import SwiftUI

/// The colors of the official app icon (`SupportFiles/BelloHub.icon`: an orange background with the ivory "b" and its
/// sage relief), for the mark drawn inside the app (`BrandMark`). They are the logo's own and never follow the
/// interface palette: the mark on the lock screen must be the icon she taps on the home screen. Change them only
/// together with the icon.
enum BrandPalette {
    /// The icon's background: the brand orange in light, the near-black iOS gives the icon in dark.
    static let tile = Color(light: 0xE84A10, dark: 0x181717)
    /// The ivory "b" (`Front.png`), measured against the tile in `BrandMarkContrastTests`.
    static let letter = Color(hex: 0xFAF5EB)
}
