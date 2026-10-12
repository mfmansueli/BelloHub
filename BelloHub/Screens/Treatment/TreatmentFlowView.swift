//
//  TreatmentFlowView.swift
//  BelloHub
//

import SwiftUI

/// The visit flow, shown full screen (`.treatmentFlow(item:)`) with its own navigation stack. It is a thin wrapper: it
/// reads the Services and the replaceable technologies from the environment and builds the host, which owns the
/// flow's ViewModel. The first screen is the visit form; the camera, the voice path and the confirmation are pushed on
/// top of it.
struct TreatmentFlowView: View {
    let request: TreatmentFlowRequest

    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.voiceCapture) private var voice
    @Environment(\.recordStructuring) private var structuring
    @Environment(\.photoProcessing) private var photoProcessing
    @Environment(\.locale) private var locale
    @Environment(FollowUpQueueService.self) private var closings: FollowUpQueueService?

    var body: some View {
        TreatmentFlowHost(
            viewModel: TreatmentFlowViewModel(
                request: request, repository: vault.repository, profile: profile, voice: voice,
                structuring: structuring, photoProcessing: photoProcessing, closings: closings,
                names: TreatmentFlowViewModel.FieldNames(
                    serviceFallback: text("treatmentFlow.serviceFallback", "Treatment"),
                    notes: text("treatmentFlow.field.notes", "Observations"),
                    recommendation: text("treatmentFlow.field.recommendation", "Recommendation"),
                    aftercare: text("record.field.aftercare", "Aftercare"),
                    reaction: text("record.field.reaction", "Reaction"),
                    reminder: text("record.field.nextVisitReminder", "Remember next time")
                )
            )
        )
    }

    private func text(_ key: StaticString, _ fallback: String.LocalizationValue) -> String {
        LocalizedStringResource(key, defaultValue: fallback).resolved(in: locale)
    }
}
