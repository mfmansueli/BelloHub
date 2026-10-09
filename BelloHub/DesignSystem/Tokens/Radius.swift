//
//  Radius.swift
//  BelloHub
//

import CoreGraphics

/// Radius by role. Concentric rule: a shape inside another has the outer radius minus the padding
/// between them (see `concentric(outer:inset:)`). Sheets use the system radius, so there is no token.
enum Radius {
    static let hero: CGFloat = 30
    static let card: CGFloat = 24
    static let tileSmall: CGFloat = 20
    static let tile: CGFloat = 18
    static let button: CGFloat = 18
    static let control: CGFloat = 14
    static let input: CGFloat = 14
    /// A visit block in the week grid, where a column is about 48 pt wide.
    static let block: CGFloat = 8

    static func concentric(outer: CGFloat, inset: CGFloat) -> CGFloat {
        max(outer - inset, 0)
    }
}
