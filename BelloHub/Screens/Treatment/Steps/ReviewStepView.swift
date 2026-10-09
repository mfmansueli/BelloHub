//
//  ReviewStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.4 Tx-4-Review: what the technology understood, one card per field. She keeps, edits or drops every one; Save stays
/// off until she has decided on all of them, so nothing she did not look at is saved (docs/12 section 4). The fields that
/// were not mentioned are listed as empty: they are not guessed.
struct ReviewStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onCancel: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                if viewModel.rejectedCount > 0 {
                    InlineNotice(style: .info, title: "treatmentFlow.review.rejected")
                        .accessibilityIdentifier("treatmentFlow.review.rejected")
                }
                ForEach(viewModel.proposals) { proposal in
                    ReviewCard(
                        proposal: proposal, suggestions: viewModel.productNames,
                        onKeep: { viewModel.accept(proposal.field.key) },
                        onEdit: { viewModel.edit(proposal.field.key, to: $0) },
                        onDrop: { viewModel.drop(proposal.field.key) },
                        onReopen: { viewModel.reopen(proposal.field.key) }
                    )
                }
                if viewModel.pendingCount > 1 {
                    Button { viewModel.acceptAll() } label: { Text("treatmentFlow.review.keepAll") }
                        .buttonStyle(.belloSecondary)
                        .accessibilityIdentifier("treatmentFlow.review.keepAllButton")
                }
                TreatmentResultPicker(result: $viewModel.draft.result, idPrefix: "treatmentFlow.review")
                notMentioned
                if viewModel.reviewIsEmptyAfterDecisions {
                    InlineNotice(style: .warning, title: "treatmentFlow.review.nothingKept")
                        .accessibilityIdentifier("treatmentFlow.review.nothingKept")
                }
                InlineNotice(style: .info, title: "treatmentFlow.lock.title", message: "treatmentFlow.lock.message")
                if let failure = viewModel.failure {
                    TreatmentFailureNotice(failure: failure) { viewModel.saveReviewTapped() }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onCancel) { Text("common.cancel") }
                    .accessibilityIdentifier("treatmentFlow.review.cancelButton")
            }
        }
        .safeAreaInset(edge: .bottom) { saveBar }
        .accessibilityIdentifier("treatmentFlow.review")
    }

    // MARK: - Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label { Text("treatmentFlow.review.badge") } icon: { Image(icon: .sparkle) }
                .font(Typography.footnoteStrong)
                .foregroundStyle(Palette.roseDeepText)
                .padding(.horizontal, Spacing.row)
                .frame(minHeight: 28)
                .background(Palette.roseDeepWash, in: Capsule())
            Text("treatmentFlow.review.title").font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: viewModel.visitSubtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
            Text("treatmentFlow.review.hint").font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    @ViewBuilder
    private var notMentioned: some View {
        let names = viewModel.notMentioned.filter { $0.role != .nextSession }.map(\.name)
        if !names.isEmpty {
            let list = names.formatted(.list(type: .and, width: .narrow).locale(locale))
            Text(LocalizedStringResource(
                "treatmentFlow.review.notMentioned",
                defaultValue: "Not mentioned, so they stay empty instead of guessed: \(list)."
            ).localized(in: locale))
            .font(Typography.footnote).foregroundStyle(Palette.ink2)
            .accessibilityIdentifier("treatmentFlow.review.notMentioned")
        }
    }

    private var saveBar: some View {
        FlowBottomBar {
            if viewModel.pendingCount > 0 {
                Text(LocalizedStringResource(
                    "treatmentFlow.review.pending",
                    defaultValue: "Decide on \(viewModel.pendingCount) more to save."
                ).localized(in: locale))
                .font(Typography.footnote).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("treatmentFlow.review.pending")
            }
            Button { viewModel.saveReviewTapped() } label: {
                Text(LocalizedStringResource(
                    "treatmentFlow.save",
                    defaultValue: "Save to \(BidiIsolate.wrap(viewModel.client?.firstName ?? ""))’s history"
                ).localized(in: locale))
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSaveReview)
            .accessibilityIdentifier("treatmentFlow.review.saveButton")
        }
    }
}
