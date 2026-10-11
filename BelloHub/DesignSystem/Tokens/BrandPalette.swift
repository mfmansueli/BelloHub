//
//  BrandPalette.swift
//  BelloHub
//

import SwiftUI

/// The colors of the official app icon (`SupportFiles/BelloHub.icon/icon.json` and its two SVG layers), for the mark
/// drawn inside the app (`BrandMark`). They are the logo's own and never follow the interface palette: the mark on the
/// lock screen must be the icon she taps on the home screen. Change them only together with the icon.
enum BrandPalette {
    /// The icon's tile: `fill` in light, the `dark` fill specialization in dark.
    static let tile = Color(light: 0x6E8266, dark: 0x344B3C)
    /// The "b" silhouette (`B-Ivory.svg`).
    static let letter = Color(hex: 0xFAF5EB)
    /// The two curved edges on the "b" (`B-Rose.svg`).
    static let edges = Color(hex: 0xC98F9F)
}
