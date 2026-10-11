//
//  BrandLetterShape.swift
//  BelloHub
//

import SwiftUI

/// The "b" of the app icon, point for point from `BelloHub.icon/Assets/B-Ivory.svg` (viewBox 1254 x 1254, even-odd
/// fill: the bowl is a hole). Scaled to the rect it is drawn in, which must be square.
struct BrandLetterShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let point = BrandIconGeometry.mapper(for: rect)
        path.move(to: point(222, 254))
        path.addCurve(to: point(453, 134), control1: point(267, 189), control2: point(363, 126))
        path.addCurve(to: point(539, 248), control1: point(511, 137), control2: point(539, 179))
        path.addLine(to: point(539, 567))
        path.addCurve(to: point(770, 446), control1: point(602, 494), control2: point(681, 446))
        path.addCurve(to: point(1048, 778), control1: point(937, 446), control2: point(1048, 566))
        path.addCurve(to: point(710, 1102), control1: point(1048, 984), control2: point(929, 1102))
        path.addLine(to: point(558, 1102))
        path.addCurve(to: point(312, 871), control1: point(393, 1102), control2: point(312, 1022))
        path.addLine(to: point(312, 387))
        path.addCurve(to: point(222, 254), control1: point(312, 296), control2: point(285, 254))
        path.closeSubpath()
        path.move(to: point(539, 638))
        path.addCurve(to: point(687, 548), control1: point(568, 578), control2: point(623, 548))
        path.addCurve(to: point(842, 790), control1: point(789, 548), control2: point(842, 650))
        path.addCurve(to: point(687, 1042), control1: point(842, 952), control2: point(785, 1042))
        path.addCurve(to: point(539, 852), control1: point(594, 1042), control2: point(539, 969))
        path.closeSubpath()
        return path
    }
}
