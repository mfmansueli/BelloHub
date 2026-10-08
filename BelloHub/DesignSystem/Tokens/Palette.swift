//
//  Palette.swift
//  BelloHub
//

import SwiftUI

/// Semantic color tokens. Screens use these names and never hex values or `.opacity(x)` on text.
/// Values are provisional until the brand identity is decided (see DESIGN.md). Contrast is
/// enforced by `PaletteContrastTests`, so change a value and the tests tell you if it still passes.
enum Palette {
    static let bg = Color(light: 0xF7F7F9, dark: 0x0B0B0E)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1A20)
    static let ink = Color(light: 0x111114, dark: 0xF5F5F7)
    static let ink2 = Color(light: 0x595963, dark: 0xA6A6B2)
    static let accent = Color(light: 0x0A4FD6, dark: 0x7FA8FF)
}
