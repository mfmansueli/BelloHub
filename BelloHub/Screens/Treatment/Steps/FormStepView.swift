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
    @State private var showsMore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TreatmentVisitCard(
                    name: viewModel.client?.name ?? "", id: viewModel.clientID, subtitle: viewModel.visitSubtitle
                )
                header
                if !viewModel.lastVisitValues.isEmpty { sameAsLastVisit }
                let layout = viewModel.formLayout
                ForEach(layout.main) { field in input(field) }
                if !layout.more.isEmpty { moreFields(layout.more) }
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
        .accessibilityIdentifier("treatmentFlow.form")
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button { viewModel.saveFormTapped() } label: { saveLabel }
                    .buttonStyle(.belloPrimary)
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("treatmentFlow.form.saveButton")
            }
        }
    }

    // MARK: - Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("treatmentFlow.form.heading").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("treatmentFlow.form.hint").font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    /// Her own answers of the client's last visit for this service, one tap away; only empty fields are filled.
    private var sameAsLastVisit: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button(action: viewModel.applyLastVisit) {
                Label { Text(lastVisitTitle) } icon: { Image(icon: .repeatArrows) }
            }
            .buttonStyle(.belloChip(selected: false))
            .accessibilityIdentifier("treatmentFlow.form.sameAsLastButton")
            Text("treatmentFlow.form.sameAsLast.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var lastVisitTitle: String {
        let day = viewModel.lastVisit.map { viewModel.formatters.shortDate($0.createdAt) } ?? ""
        return LocalizedStringResource("treatmentFlow.form.sameAsLast", defaultValue: "Same as last visit, \(day)")
            .resolved(in: locale)
    }

    /// The rest of her template, folded: few questions at once, all of them reachable.
    private func moreFields(_ fields: [TreatmentFormField]) -> some View {
        DisclosureGroup(isExpanded: $showsMore) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(fields) { field in input(field) }
            }
            .padding(.top, Spacing.md)
        } label: {
            HStack(spacing: Spacing.xs) {
                Text("treatmentFlow.form.moreFields").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: viewModel.formatters.number(fields.count))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            // On the label: an identifier on the group would replace the fields' own.
            .accessibilityIdentifier("treatmentFlow.form.moreFields")
        }
        .tint(Palette.ink)
    }

    private func input(_ field: TreatmentFormField) -> some View {
        TreatmentFieldInput(
            field: field, value: binding(for: field.key), suggestions: viewModel.productNames,
            hasError: viewModel.showsValidation && viewModel.issue(forNumberField: field.key)
        )
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
