//
//  FlowBottomBar.swift
//  BelloHub
//

import SwiftUI

/// The action area at the bottom of a step: the primary button (and a quiet one under it), on the screen's background
/// with a hairline above. Put it in `safeAreaInset(edge: .bottom)`.
struct FlowBottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: Spacing.xs) {
            content
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(Palette.bg)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1).accessibilityHidden(true) }
        .motionBar()
    }
}
