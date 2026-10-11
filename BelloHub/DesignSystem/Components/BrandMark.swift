//
//  BrandMark.swift
//  BelloHub
//

import SwiftUI

/// The Bello Hub mark as the app icon draws it (routine-a item 2): the icon's background, its sage relief and the
/// ivory "b", from the icon's own two layers (`BrandMarkRelief` and `BrandMarkFront`, copies of
/// `BelloHub.icon/Assets`), in the rounded square of the home-screen mask. The layers share one canvas, so they are
/// stacked at the same size without any offset. Decorative: callers that need a name add their own label.
struct BrandMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            BrandPalette.tile
            Image("BrandMarkRelief").resizable().scaledToFit()
            Image("BrandMarkFront").resizable().scaledToFit()
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * BrandIconGeometry.cornerRatio, style: .continuous))
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        BrandMark(size: 64)
        BrandMark(size: 120)
    }
    .padding()
}
