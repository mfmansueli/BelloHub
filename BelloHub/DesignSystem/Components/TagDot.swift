//
//  TagDot.swift
//  BelloHub
//

import SwiftUI

/// The colored dot next to a tag name: the pastel fill of its `TagColor` inside a ring in the text tone of the same
/// family, so the shape stays visible (3:1) on any surface. Decorative: the tag's name is always next to it, so
/// VoiceOver skips it and color is never the only way to tell tags apart.
struct TagDot: View {
    let color: TagColor
    var size: CGFloat = 16

    var body: some View {
        Circle()
            .fill(color.dot)
            .overlay { Circle().strokeBorder(color.outline, lineWidth: 1.5) }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        ForEach(TagColor.allCases) { TagDot(color: $0, size: 24) }
    }
    .padding()
    .background(Palette.surface)
}
