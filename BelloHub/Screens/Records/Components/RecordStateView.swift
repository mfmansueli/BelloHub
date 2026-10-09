//
//  RecordStateView.swift
//  BelloHub
//

import SwiftUI

/// What the incident and export sheets show while their client loads, when she is gone and when loading failed. The
/// identifiers are `<prefix>.loading`, `<prefix>.missing` and `<prefix>.error`.
struct RecordStateView: View {
    let prefix: String
    let isMissing: Bool
    let errorMessage: String?
    let retry: () -> Void

    var body: some View {
        if isMissing {
            EmptyState(
                icon: .user, title: Text("recordHistory.missing.title"), message: Text("recordHistory.missing.message")
            )
            .accessibilityIdentifier("\(prefix).missing")
            .frame(maxHeight: .infinity)
        } else if let errorMessage {
            EmptyState(
                icon: .alert, title: Text("recordHistory.error.title"), message: Text(verbatim: errorMessage),
                actionTitle: "recordHistory.error.retry", action: retry
            )
            .accessibilityIdentifier("\(prefix).error")
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: Spacing.md) {
                Skeleton(height: 72, cornerRadius: Radius.card)
                Skeleton(height: 120, cornerRadius: Radius.card)
                Skeleton(height: 90, cornerRadius: Radius.card)
                Spacer(minLength: 0)
            }
            .padding(Spacing.gutter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("recordHistory.loading"))
            .accessibilityIdentifier("\(prefix).loading")
        }
    }
}
