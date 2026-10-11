//
//  BrandEdgesShape.swift
//  BelloHub
//

import SwiftUI

/// The two curved edges that sit on the "b" of the app icon (the stem and the bowl), point for point from
/// `BelloHub.icon/Assets/B-Rose.svg` (viewBox 1254 x 1254). Drawn on top of `BrandLetterShape`, as in the icon.
struct BrandEdgesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let point = BrandIconGeometry.mapper(for: rect)
        path.move(to: point(222, 254))
        path.addCurve(to: point(453, 134), control1: point(267, 189), control2: point(363, 126))
        path.addCurve(to: point(319, 260), control1: point(399, 155), control2: point(331, 210))
        path.addCurve(to: point(331, 355), control1: point(308, 289), control2: point(320, 317))
        path.addCurve(to: point(347, 730), control1: point(365, 461), control2: point(361, 606))
        path.addCurve(to: point(375, 1024), control1: point(333, 850), control2: point(326, 947))
        path.addCurve(to: point(312, 871), control1: point(332, 985), control2: point(312, 934))
        path.addLine(to: point(312, 387))
        path.addCurve(to: point(222, 254), control1: point(312, 296), control2: point(285, 254))
        path.closeSubpath()
        path.move(to: point(817, 451))
        path.addCurve(to: point(1048, 778), control1: point(953, 474), control2: point(1048, 590))
        path.addCurve(to: point(817, 1076), control1: point(1048, 932), control2: point(980, 1032))
        path.addCurve(to: point(974, 779), control1: point(925, 1003), control2: point(974, 910))
        path.addCurve(to: point(817, 451), control1: point(974, 628), control2: point(923, 507))
        path.closeSubpath()
        return path
    }
}
