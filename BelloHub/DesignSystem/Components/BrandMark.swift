//
//  BrandMark.swift
//  BelloHub
//

import SwiftUI

/// The Bello Hub mark: a graphite rounded square with a white "b" and a rose dot. Drawn, not an image, so it is
/// sharp at every size and follows the appearance. Decorative: callers that need a name add their own label.
struct BrandMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color(hex: 0x242321))
            Text(verbatim: "b")
                .font(.custom(FontRegistry.sansFamily, size: size * 0.62, relativeTo: .largeTitle).weight(.bold))
                .foregroundStyle(HeroPalette.ink)
                .offset(y: -size * 0.02)
            Circle()
                .fill(Palette.rose)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: -size * 0.17, y: -size * 0.2)
        }
        .frame(width: size, height: size)
        .dynamicTypeSize(.large)
        .accessibilityHidden(true)
    }
}
