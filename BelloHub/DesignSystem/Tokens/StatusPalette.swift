//
//  StatusPalette.swift
//  BelloHub
//

import SwiftUI

/// Area-specific colors for appointment and client status, kept out of `Palette` so the core
/// tokens stay small.
enum StatusPalette {
    static let confirmed = StatusStyle(foreground: Palette.sageText, background: Palette.sageWash, dot: Palette.sage)
    static let pending = StatusStyle(foreground: Palette.amberText, background: Palette.amberBg, dot: Palette.amberText)
    static let nextUp = StatusStyle(foreground: Palette.roseDeepText, background: Palette.roseWash, dot: Palette.rose)
    static let completed = StatusStyle(
        foreground: Palette.neutralText, background: Palette.neutralWash, dot: Palette.ink3
    )
    static let attention = StatusStyle(
        foreground: Palette.coralText, background: Palette.coralBg, dot: Palette.coralText
    )
}
