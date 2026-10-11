//
//  OnboardingView.swift
//  BelloHub
//

import SwiftUI

/// The workspace setup: a back button and a progress bar on top, the current step below. The steps are separate
/// views (`Steps/`); this one only moves between them.
struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.motionPolicy) private var policy
    let onExit: () -> Void

    init(viewModel: OnboardingViewModel, onExit: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onExit = onExit
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.step.progressPosition != nil { header }
            stepView
                .id(viewModel.step)
                .transition(transition)
        }
        .background(Palette.bg)
        .animation(policy.allowsFade ? Motion.ease(Motion.Duration.fade) : nil, value: viewModel.step)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: back) {
                Image(icon: .back)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .accessibilityLabel(Text("common.back"))
            .accessibilityIdentifier("onboarding.backButton")
            StepProgressBar(current: viewModel.step.progressPosition ?? 0, total: OnboardingStep.counted.count)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.trailing, Spacing.gutter - Spacing.sm)
        .padding(.top, Spacing.xs)
    }

    private func back() {
        if viewModel.step == .about { onExit() } else { viewModel.goBack() }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepView: some View {
        switch viewModel.step {
        case .about: AboutStepView(viewModel: viewModel)
        case .profession: ProfessionStepView(viewModel: viewModel)
        case .services: ServicesStepView(viewModel: viewModel)
        case .ready: ReadyStepView(viewModel: viewModel)
        }
    }

    /// The next screen slides in from the trailing edge, and from the leading one when she goes back; with Reduce
    /// Motion it only fades.
    private var transition: AnyTransition {
        guard policy.allowsMovement else { return .opacity }
        let enter: Edge = viewModel.isMovingForward ? .trailing : .leading
        let leave: Edge = viewModel.isMovingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: enter).combined(with: .opacity),
            removal: .move(edge: leave).combined(with: .opacity)
        )
    }
}
