//
//  TreatmentFailureNotice.swift
//  BelloHub
//

import SwiftUI

/// What went wrong in the flow, in her language and without technical words, with the way forward.
struct TreatmentFailureNotice: View {
    let failure: TreatmentFlowViewModel.Failure
    var onRetry: (() -> Void)?

    @Environment(\.locale) private var locale

    var body: some View {
        ErrorNotice(
            message: message, actionTitle: onRetry == nil ? nil : "treatmentFlow.retry", action: onRetry
        )
        .accessibilityIdentifier("treatmentFlow.failure")
    }

    private var message: String {
        switch failure {
        case .save:
            LocalizedStringResource(
                "treatmentFlow.error.save", defaultValue: "We could not save this record. Nothing was lost: try again."
            ).resolved(in: locale)
        case .photo:
            LocalizedStringResource(
                "treatmentFlow.error.photo", defaultValue: "That picture could not be used. Try another one."
            ).resolved(in: locale)
        case .organize:
            LocalizedStringResource(
                "treatmentFlow.error.organize",
                defaultValue: "Your words could not be organized. They are kept as notes you can edit."
            ).resolved(in: locale)
        }
    }
}
