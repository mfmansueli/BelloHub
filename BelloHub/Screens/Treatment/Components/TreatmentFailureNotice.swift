//
//  TreatmentFailureNotice.swift
//  BelloHub
//

import SwiftUI

/// What went wrong in the flow, in her language and without technical words, with the way forward.
struct TreatmentFailureNotice: View {
    let failure: TreatmentFlowViewModel.Failure
    var onRetry: (() -> Void)?
    /// For a failure a retry cannot fix (a picture that could not be used): she reads it and puts it away.
    var onDismiss: (() -> Void)?

    @Environment(\.locale) private var locale

    var body: some View {
        ErrorNotice(message: message, actionTitle: actionTitle, action: onRetry ?? onDismiss)
            .accessibilityIdentifier("treatmentFlow.failure")
    }

    private var actionTitle: LocalizedStringKey? {
        if onRetry != nil { return "treatmentFlow.retry" }
        return onDismiss == nil ? nil : "recordHistory.error.dismiss"
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
        case .delete:
            LocalizedStringResource(
                "treatmentFlow.error.delete", defaultValue: "The draft could not be deleted. It is still saved."
            ).resolved(in: locale)
        case .organize:
            LocalizedStringResource(
                "treatmentFlow.error.organize",
                defaultValue: "Your words could not be organized. They are kept as notes you can edit."
            ).resolved(in: locale)
        }
    }
}
