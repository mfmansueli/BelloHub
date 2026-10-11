//
//  ListLoadingView.swift
//  BelloHub
//

import SwiftUI

/// Skeleton cards standing where a list will be. One accessibility element that says "Loading", so VoiceOver does not
/// walk empty rectangles.
struct ListLoadingView: View {
    var rows = 3

    var body: some View {
        VStack(spacing: Spacing.row) {
            ForEach(0..<rows, id: \.self) { _ in
                Skeleton(height: 88, cornerRadius: Radius.card)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("scheduling.loading"))
    }
}

#Preview {
    ListLoadingView().padding()
}
