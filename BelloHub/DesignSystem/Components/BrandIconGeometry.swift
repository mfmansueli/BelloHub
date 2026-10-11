//
//  BrandIconGeometry.swift
//  BelloHub
//

import CoreGraphics

/// The geometry the app icon is drawn in: the SVG layers' viewBox and the corner of the home-screen icon mask. One
/// owner, so the mark and its two shapes always scale together.
enum BrandIconGeometry {
    /// Side of the square viewBox of `B-Ivory.svg` and `B-Rose.svg`.
    static let viewBox: CGFloat = 1254
    /// Corner radius of the iOS icon mask as a share of the side (a continuous rounded square).
    static let cornerRatio: CGFloat = 0.2237

    /// Maps a point of the viewBox into `rect`.
    static func mapper(for rect: CGRect) -> (CGFloat, CGFloat) -> CGPoint {
        let scale = min(rect.width, rect.height) / viewBox
        return { pointX, pointY in CGPoint(x: rect.minX + pointX * scale, y: rect.minY + pointY * scale) }
    }
}
