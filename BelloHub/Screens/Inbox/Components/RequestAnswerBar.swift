//
//  RequestAnswerBar.swift
//  BelloHub
//

import SwiftUI

/// The bottom bar of a request: Decline (secondary) and the one primary answer. Side by side at the default sizes,
/// stacked at the accessibility sizes so neither label is cut.
struct RequestAnswerBar: View {
    let primaryTitle: Text
    let identifierPrefix: String
    var canAccept = true
    let onDecline: () -> Void
    let onAccept: () -> Void

    var body: some View {
        FittingRow(fillsWidth: true) {
            Button(action: onDecline) { Text("inbox.decline") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("\(identifierPrefix).declineButton")
            if canAccept {
                Button(action: onAccept) { primaryTitle }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("\(identifierPrefix).acceptButton")
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }
}
