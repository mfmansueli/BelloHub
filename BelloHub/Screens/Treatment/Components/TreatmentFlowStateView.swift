//
//  TreatmentFlowStateView.swift
//  BelloHub
//

import SwiftUI

/// What the visit flow shows before its form: loading, a load that failed (with a retry), or a client who is gone.
struct TreatmentFlowStateView: View {
    let state: TreatmentFlowViewModel.LoadState
    let onRetry: () -> Void
    let onClose: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        switch state {
        case .loading, .ready: loading
        case .failed: failed
        case .clientMissing: missing
        }
    }

    private var loading: some View {
        VStack(spacing: Spacing.md) {
            Skeleton(height: 120)
            Skeleton(height: 110)
            Skeleton(height: 160)
            Spacer(minLength: 0)
        }
        .padding(Spacing.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("treatmentFlow.loading"))
        .accessibilityIdentifier("treatmentFlow.loading")
    }

    private var failed: some View {
        VStack(spacing: Spacing.md) {
            ErrorNotice(
                message: LocalizedStringResource(
                    "treatmentFlow.error.load", defaultValue: "We could not open this record. Try again."
                ).resolved(in: locale),
                actionTitle: "treatmentFlow.retry", action: onRetry
            )
            Spacer(minLength: 0)
        }
        .padding(Spacing.gutter)
        .accessibilityIdentifier("treatmentFlow.error")
    }

    private var missing: some View {
        EmptyState(
            icon: .user, title: "treatmentFlow.missing.title", message: "treatmentFlow.missing.message",
            actionTitle: "treatmentFlow.missing.close", action: onClose
        )
        .accessibilityIdentifier("treatmentFlow.missing")
    }
}
