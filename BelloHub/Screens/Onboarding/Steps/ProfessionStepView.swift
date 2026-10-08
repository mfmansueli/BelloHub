//
//  ProfessionStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.3 Onb-2-Profession. She can choose more than one; the choice shapes the suggested services, tags and record
/// fields on the next steps.
struct ProfessionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Two columns normally, one at accessibility sizes: a word like "Wellness" does not fit a half-width card then.
    private var columns: [GridItem] {
        let column = GridItem(.flexible(), spacing: Spacing.row)
        return dynamicTypeSize.isAccessibilitySize ? [column] : [column, column]
    }

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.profession.title"), subtitle: Text("onb.profession.subtitle"),
            canContinue: viewModel.canContinue, identifier: "profession", onContinue: viewModel.goNext
        ) {
            LazyVGrid(columns: columns, spacing: Spacing.row) {
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
