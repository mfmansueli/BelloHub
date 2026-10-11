//
//  CheckShape.swift
//  BelloHub
//

import SwiftUI

/// The check on a 24 pt grid: `M5 12.5 L9.5 17 L19 7.5`.
struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 24
        var path = Path()
        path.move(to: CGPoint(x: 5 * scale, y: 12.5 * scale))
        path.addLine(to: CGPoint(x: 9.5 * scale, y: 17 * scale))
        path.addLine(to: CGPoint(x: 19 * scale, y: 7.5 * scale))
        return path
    }
}
