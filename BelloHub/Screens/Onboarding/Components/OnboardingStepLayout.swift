//
//  OnboardingStepLayout.swift
//  BelloHub
//

import SwiftUI

/// The frame every setup step shares: a serif title, one line under it, the step's content and a Continue button that
/// stays at the bottom while the content scrolls.
struct OnboardingStepLayout<Content: View>: View {
    let title: Text
    var subtitle: Text?
    var continueTitle: LocalizedStringKey = "onb.continue"
    var canContinue = true
    var isWorking = false
    var identifier: String
    let onContinue: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    title
                        .font(Typography.screenTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboarding.\(identifier).title")
                    if let subtitle {
                        subtitle.font(Typography.body).foregroundStyle(Palette.ink2)
                    }
                }
                content
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                if isWorking { ProgressView() } else { Text(continueTitle) }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!canContinue || isWorking)
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
            .background(Palette.bg)
            .accessibilityIdentifier("onboarding.\(identifier).continueButton")
            .motionBar()
        }
    }
}
