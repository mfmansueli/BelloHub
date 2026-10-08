//
//  StaggeredStack.swift
//  BelloHub
//

import SwiftUI

/// A vertical stack whose children arrive one after another. It assigns the stagger index to each
/// top-level child so no screen edits its blocks by hand.
struct StaggeredStack<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = Spacing.section
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                    subview.motionArrival(index: index)
                }
            }
        }
    }
}
