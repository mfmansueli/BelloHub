//
//  VisitStateView.swift
//  BelloHub
//

import SwiftUI

/// What a screen of the visit's flow shows until it has the visit: skeletons while it loads, an explanation when the
/// visit or its client is gone, and the error with a retry. `prefix` is the screen's identifier prefix.
struct VisitStateView: View {
    let prefix: String
    let isMissing: Bool
    let errorMessage: String?
    let retry: () -> Void

    var body: some View {
        if isMissing {
            EmptyState(
                icon: .calendar, title: Text("appointment.missing.title"), message: Text("appointment.missing.message")
            )
            .accessibilityIdentifier("\(prefix).missing")
            .frame(maxHeight: .infinity)
        } else if let errorMessage {
            EmptyState(
                icon: .alert, title: Text("appointment.error.title"), message: Text(verbatim: errorMessage),
                actionTitle: "appointment.error.retry", action: retry
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
            .accessibilityLabel(Text("appointment.loading"))
            .accessibilityIdentifier("\(prefix).loading")
        }
    }
}
