//
//  HealthFormSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet where the professional fills the health form with the client: the questions of the current template.
/// No consent text and no signature (D55). The answers are sealed in the vault when she saves.
struct HealthFormSheet: View {
    @Bindable var viewModel: HealthFormViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // The header scrolls with the form: at large text sizes a pinned header and a pinned Save bar would leave
        // almost no room for the questions (the same layout as the onboarding steps).
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(
                    title: "healthForm.title", subtitle: "healthForm.subtitle", closeLabel: "common.close",
                    closeIdentifier: "healthForm.closeButton", onClose: { dismiss() }
                )
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    minorSection
                    ForEach(viewModel.questions) { question in
                        HealthQuestionView(viewModel: viewModel, question: question)
                    }
                    incompleteHint
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { saveBar }
        .background(Palette.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }

    // MARK: - Parts

    /// "Is this visit for someone under 18?": a yes asks for the young person's name (D17). The guardian's consent
    /// is hers to collect in person and note as a consent record.
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

    /// Why Save is off, under the last field. It is part of the form, not of the Save bar: at the largest text sizes a
    /// four-line hint in the bar would take a third of the screen away from the questions.
    @ViewBuilder
    private var incompleteHint: some View {
        if !viewModel.canSave && !viewModel.isSaving {
            Text("healthForm.incomplete")
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("healthForm.incomplete")
        }
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.errorMessage {
                Text(verbatim: message)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("healthForm.error")
            }
            Button { viewModel.save() } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    // Two lines at most, shrunk before broken: at AX5 in German a long verb was split mid-word and
                    // the bar grew to a quarter of the screen, covering the last question.
                    Text("healthForm.save").lineLimit(2).minimumScaleFactor(0.6)
                }
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
