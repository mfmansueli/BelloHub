//
//  BrandLockup.swift
//  BelloHub
//

import SwiftUI

/// The mark with the two-line wordmark ("bello" over "hub"). The wordmark is the brand name, the same in every
/// language, so it is never localized.
struct BrandLockup: View {
    var markSize: CGFloat = 56

    var body: some View {
        HStack(spacing: Spacing.row) {
            BrandMark(size: markSize)
            VStack(alignment: .leading, spacing: -markSize * 0.08) {
                Text(verbatim: "bello").foregroundStyle(Palette.ink)
                // `roseText`, not the logo's pale `rose`: the pale one is 2.4:1 on the page color.
                Text(verbatim: "hub").foregroundStyle(Palette.roseText)
            }
            .font(.custom(FontRegistry.sansFamily, size: markSize * 0.5, relativeTo: .title).weight(.bold))
            .dynamicTypeSize(.large)
            .environment(\.layoutDirection, .leftToRight)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Bello Hub"))
    }
}
