//
//  ListCard.swift
//  BelloHub
//

import SwiftUI

/// A card of rows with inset dividers that start at the text edge (72 pt after an avatar).
/// Rows are the caller's views; each row should be one combined accessibility element.
struct ListCard<Content: View>: View {
    /// Where the dividers start, measured from the leading edge. 72 pt aligns with the text after an avatar.
    var dividerInset: CGFloat = 72
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                    if index > 0 {
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                            .padding(.leading, dividerInset)
                            .accessibilityHidden(true)
                    }
                    subview
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .belloCard()
    }
}
