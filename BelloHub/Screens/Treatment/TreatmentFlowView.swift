//
//  TreatmentFlowView.swift
//  BelloHub
//

import SwiftUI

/// 5.1 to 5.9, the treatment flow, shown full screen (`.treatmentFlow(item:)`) with its own navigation stack. It is a
/// thin wrapper: it reads the Services and the replaceable technologies from the environment and builds the host, which
/// owns the flow's ViewModel. The first screen is "how do you want to record"; the rest are pushed on top of it.
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
                fallbackServiceName: text("treatmentFlow.serviceFallback", "Treatment"),
                notesName: text("treatmentFlow.field.notes", "Observations"),
                recommendationName: text("treatmentFlow.field.recommendation", "Recommendation")
            )
        )
    }

    private func text(_ key: StaticString, _ fallback: String.LocalizationValue) -> String {
        LocalizedStringResource(key, defaultValue: fallback).resolved(in: locale)
    }
}
