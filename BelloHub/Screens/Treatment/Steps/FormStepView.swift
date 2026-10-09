//
//  FormStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.5 Tx-Form: the manual record, built from the fields of her profession's template. It is a complete way to record,
/// not a fallback: every field kind works, the same save path applies, and what she leaves empty stays empty. The
/// 24-hour
/// lock is explained before she saves, not after.
struct FormStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TreatmentVisitCard(
                    name: viewModel.client?.name ?? "", id: viewModel.clientID, subtitle: viewModel.visitSubtitle
                )
                header
                ForEach(viewModel.fields) { field in
                    TreatmentFieldInput(
                        field: field, value: binding(for: field.key), suggestions: viewModel.productNames,
                        hasError: viewModel.showsValidation && viewModel.issue(forNumberField: field.key)
                    )
                }
                TreatmentResultPicker(result: $viewModel.draft.result)
                InlineNotice(
                    style: .info, title: "treatmentFlow.lock.title", message: "treatmentFlow.lock.message"
                )
                .accessibilityIdentifier("treatmentFlow.form.lockNotice")
                if viewModel.showsValidation, viewModel.issues.contains(.nothingToSave) {
                    Text("treatmentFlow.form.error.empty").font(Typography.meta).foregroundStyle(Palette.coralText)
                        .accessibilityIdentifier("treatmentFlow.form.emptyError")
                }
                if let failure = viewModel.failure {
                    TreatmentFailureNotice(failure: failure) { viewModel.saveFormTapped() }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .navigationTitle(Text("treatmentFlow.form.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button { viewModel.saveFormTapped() } label: { saveLabel }
                    .buttonStyle(.belloPrimary)
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("treatmentFlow.form.saveButton")
            }
        }
        .accessibilityIdentifier("treatmentFlow.form")
    }

    // MARK: - Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("treatmentFlow.form.heading").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("treatmentFlow.form.hint").font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    private var saveLabel: Text {
        Text(LocalizedStringResource(
            "treatmentFlow.save",
            defaultValue: "Save to \(BidiIsolate.wrap(viewModel.client?.firstName ?? ""))’s history"
        ).localized(in: locale))
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { viewModel.draft.value(for: key) }, set: { viewModel.draft.set($0, for: key) })
    }
}
