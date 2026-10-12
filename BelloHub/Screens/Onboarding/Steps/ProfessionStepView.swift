//
//  ProfessionStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.3 Onb-2-Profession. She can choose more than one; the choice shapes the suggested services, tags and record
/// fields on the next steps.
struct ProfessionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.profession.title"), subtitle: Text("onb.profession.subtitle"),
            canContinue: viewModel.canContinue, identifier: "profession", onContinue: viewModel.goNext
        ) {
            // Two columns while every name fits a half-width card whole; one otherwise (a long German or Turkish name).
            FittingGrid(spacing: Spacing.row) {
                ForEach(viewModel.availableProfessions) { entry in
                    ChoiceCard(
                        title: entry.name, isSelected: viewModel.isSelected(entry.id),
                        identifier: "onboarding.profession.choice.\(entry.id.rawValue)"
                    ) { viewModel.toggle(entry.id) }
                }
            }
        }
    }
}
