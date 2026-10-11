//
//  AftercareStepView.swift
//  BelloHub
//

import SwiftUI

/// Step 3 of a visit's closing (routine-a item 7): the aftercare of this visit. While the record can still be edited,
/// the aftercare text is written into it (starting from the record's own or the service's template); once it is locked
/// the text is read-only and a change is a correction from the record's history. The message to the client is the
/// general aftercare text of her quick replies (never the record's words: docs/06 section 8), opened in the usual
/// message sheet. Skippable.
struct AftercareStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onMessage: (AgendaSheet) -> Void
    let onFinishLater: () -> Void

    @State private var text = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ClosingProgress(step: .aftercare)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("treatmentFlow.aftercare.title").font(Typography.title).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: viewModel.visitSubtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                if viewModel.isRecordEditable {
                    BelloNoteField(
                        title: Text("treatmentFlow.aftercare.field"), text: $text,
                        prompt: "treatmentFlow.aftercare.prompt", isSensitive: true,
                        identifier: "treatmentFlow.aftercare.field"
                    )
                    FooterNote(text: "treatmentFlow.aftercare.inRecord", icon: .lock)
                } else {
                    lockedText
                }
                messageCard
                if let failure = viewModel.failure { TreatmentFailureNotice(failure: failure) }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onFinishLater) { Text("treatmentFlow.closing.later") }
                    .accessibilityIdentifier("treatmentFlow.aftercare.laterButton")
            }
        }
        .accessibilityIdentifier("treatmentFlow.aftercare")
        .onAppear { text = viewModel.aftercareText }
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button { Task { await next() } } label: { Text("treatmentFlow.closing.next") }
                    .buttonStyle(.belloPrimary)
                    .disabled(isSaving)
                    .accessibilityIdentifier("treatmentFlow.aftercare.nextButton")
                Button { if !viewModel.advance(from: .aftercare) { onFinishLater() } } label: {
                    Text("treatmentFlow.next.skip")
                }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("treatmentFlow.aftercare.skipButton")
            }
        }
    }

    // MARK: - Parts

    /// The record is locked: what it says, and where a change goes.
    private var lockedText: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !viewModel.aftercareText.isEmpty {
                Text(verbatim: viewModel.aftercareText).font(Typography.body).foregroundStyle(Palette.ink)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .belloCard()
            }
            InlineNotice(
                style: .info, title: "treatmentFlow.aftercare.locked.title",
                message: "treatmentFlow.aftercare.locked.message"
            )
            .accessibilityIdentifier("treatmentFlow.aftercare.locked")
            Button { viewModel.path.append(.history) } label: { Text("treatmentFlow.saved.fullRecord") }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("treatmentFlow.aftercare.historyButton")
        }
    }

    /// The general aftercare message, through the usual sheet (a visit is needed to address it).
    @ViewBuilder
    private var messageCard: some View {
        if let appointmentID = viewModel.appointment?.id ?? viewModel.request.appointmentID {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button { onMessage(.message(appointmentID: appointmentID)) } label: {
                    Label { Text("treatmentFlow.aftercare.message") } icon: { Image(icon: .chat) }
                }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("treatmentFlow.aftercare.messageButton")
                FooterNote(text: "treatmentFlow.aftercare.messageNote", icon: .shield)
            }
        }
    }

    private func next() async {
        isSaving = true
        defer { isSaving = false }
        if viewModel.isRecordEditable {
            guard await viewModel.saveAftercare(text) else { return }
        }
        if !viewModel.advance(from: .aftercare) { onFinishLater() }
    }
}
