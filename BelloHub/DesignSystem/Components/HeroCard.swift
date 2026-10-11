//
//  HeroCard.swift
//  BelloHub
//

import SwiftUI

/// The one memorable card of a key screen: radius 30, graphite surface, glow, elevation e2.
/// Content is the caller's; use `HeroPalette` colors for text on it. One per screen.
struct HeroCard<Content: View>: View {
    var isAnimated = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HeroSurface(isAnimated: isAnimated) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
            .belloElevation(.e2, cornerRadius: Radius.hero)
    }
}
