//
//  HealthFormSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet where the professional fills the health form with the client: the questions of the current template,
/// then the consent text and a typed signature. The answers are sealed in the vault when she saves.
struct HealthFormSheet: View {
    @Bindable var viewModel: HealthFormViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "healthForm.title", subtitle: "healthForm.subtitle", closeLabel: "common.close",
                closeIdentifier: "healthForm.closeButton", onClose: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    minorSection
                    ForEach(viewModel.questions) { question in
                        HealthQuestionView(viewModel: viewModel, question: question)
                    }
                    HealthConsentSection(viewModel: viewModel)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { saveBar }
        .background(Palette.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }

    // MARK: - Parts

    /// "Is this visit for someone under 18?": a yes switches the consent to the guardian's text and asks for the
    /// young person's name (D17).
    private var minorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("healthForm.minor.question")
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink)
            YesNoChips(isYes: viewModel.draft.isForMinor, identifier: "healthForm.minor") {
                viewModel.setForMinor($0)
            }
            if viewModel.draft.isForMinor {
                Text("healthForm.minor.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
                BelloTextField(
                    title: "health.minor.name", text: $viewModel.draft.minorName,
                    prompt: "healthForm.fullName.prompt", isSensitive: true, identifier: "healthForm.minorNameField"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.errorMessage {
                Text(verbatim: message)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("healthForm.error")
            } else if !viewModel.canSave && !viewModel.isSaving {
                Text("healthForm.incomplete")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            Button { viewModel.save() } label: {
                if viewModel.isSaving { ProgressView() } else { Text("healthForm.save") }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("healthForm.saveButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }
}
