//
//  BrandMark.swift
//  BelloHub
//

import SwiftUI

/// The Bello Hub mark as the app icon draws it (routine-a item 2): the icon's tile, the "b" silhouette and its two
/// curved edges, from the icon's own SVG paths and colors (`BrandPalette`), in the rounded square of the home-screen
/// mask. Drawn, not an image, so it is sharp at every size and takes the icon's dark tile in dark mode. It replaced a
/// provisional mark (a typed "b" with a dot) that did not match the icon. Decorative: callers that need a name add
/// their own label.
struct BrandMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * BrandIconGeometry.cornerRatio, style: .continuous)
                .fill(BrandPalette.tile)
            BrandLetterShape().fill(BrandPalette.letter, style: FillStyle(eoFill: true))
            BrandEdgesShape().fill(BrandPalette.edges)
        }
        .frame(width: size, height: size)
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
