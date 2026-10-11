//
//  OrganizingStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.3 Tx-3-Organizing: the transcript is being turned into the fields of her record. The progress is honest (a
/// spinner, not a made-up percentage), she can cancel at any time and her words are kept as notes, and nothing is saved
/// from here: the review step comes next. If the technology fails or returns nothing usable she goes to the form with
/// her words as notes.
struct OrganizingStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(icon: .sparkle)
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(Palette.roseDeepText)
                    .frame(width: 96, height: 96)
                    .background(Palette.roseDeepWash, in: Circle())
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.sm) {
                    Text("treatmentFlow.organizing.title").font(Typography.title).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("treatmentFlow.organizing.message").font(Typography.body).foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                }
                if let failure = viewModel.failure {
                    TreatmentFailureNotice(failure: failure)
                } else {
                    progress
                }
                FooterNote(text: "treatmentFlow.organizing.promise", icon: .shield)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { viewModel.cancelOrganizing() } label: { Text("common.cancel") }
                    .accessibilityIdentifier("treatmentFlow.organizing.cancelButton")
            }
        }
        .accessibilityIdentifier("treatmentFlow.organizing")
        .safeAreaInset(edge: .bottom) { actions }
    }

    // MARK: - Parts

    private var progress: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.row) {
                Image(icon: .check).foregroundStyle(Palette.sageText).accessibilityHidden(true)
                Text("treatmentFlow.organizing.transcribed").font(Typography.body).foregroundStyle(Palette.ink)
            }
            HStack(spacing: Spacing.row) {
                ProgressView().accessibilityHidden(true)
                Text("treatmentFlow.organizing.working").font(Typography.body).foregroundStyle(Palette.ink)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("treatmentFlow.organizing.progress")
    }

    @ViewBuilder
    private var actions: some View {
        if viewModel.failure != nil {
            FlowBottomBar {
                Button { viewModel.cancelOrganizing() } label: { Text("treatmentFlow.register.manual") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("treatmentFlow.organizing.manualButton")
                Button { viewModel.organize() } label: { Text("treatmentFlow.retry") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("treatmentFlow.organizing.retryButton")
            }
        } else {
            FlowBottomBar {
                Button { viewModel.cancelOrganizing() } label: { Text("treatmentFlow.organizing.keepAsNotes") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("treatmentFlow.organizing.keepButton")
            }
        }
    }
}
