//
//  VisitFormStepView.swift
//  BelloHub
//

import SwiftUI

/// The visit form, the root of the flow: everything about one visit on one screen, in the order the visit needs. Who
/// and when, photos at any moment (before writing anything), a quick note, her profession's fields, the result and the
/// reaction, the aftercare and what comes next. Every change is saved as a draft a moment later; "Finalize record" is
/// her decision and starts the 24-hour lock. Nothing is required to save a draft.
struct VisitFormStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onCancel: () -> Void

    @Environment(\.locale) private var locale
    @State private var showsMore = false
    @State private var showsResult = true
    @State private var showsGuidance = true
    @State private var showsProfession = true

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("treatmentFlow.form.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) { Text("common.close") }
                        .accessibilityIdentifier("treatmentFlow.register.cancelButton")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.loadState == .ready {
            form
        } else {
            TreatmentFlowStateView(state: viewModel.loadState, onRetry: viewModel.reload, onClose: onCancel)
        }
    }

    // MARK: - Form

    private var form: some View {
        let sections = viewModel.sections
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VisitDetailsCard(viewModel: viewModel)
                VisitAutosaveStatus(state: viewModel.autosave, isFinalized: viewModel.isFinalized,
                                    formatters: viewModel.formatters, onRetry: viewModel.retryAutosave)
                if viewModel.isLocked {
                    InlineNotice(style: .info, title: "visitForm.locked.title", message: "visitForm.locked.message")
                        .accessibilityIdentifier("visitForm.lockedNotice")
                }
                if let failure = viewModel.failure {
                    // Only a failed save is retried; the autosave line retries it too.
                    TreatmentFailureNotice(
                        failure: failure, onRetry: failure == .save ? viewModel.retryAutosave : nil,
                        onDismiss: { viewModel.failure = nil }
                    )
                }
                if viewModel.heardNothing {
                    InlineNotice(
                        style: .info, title: "treatmentFlow.register.heardNothing.title",
                        message: "treatmentFlow.register.heardNothing.message"
                    )
                    .accessibilityIdentifier("treatmentFlow.register.heardNothing")
                }
                VisitPhotosSection(viewModel: viewModel)
                if viewModel.registerOffer == .voiceAndManual, !viewModel.isLocked { dictate }
                if let note = sections.quickNote { quickNote(note) }
                professionSection(sections)
                resultSection(sections.result)
                guidanceSection(sections.guidance)
                if viewModel.showsValidation, viewModel.issues.contains(.nothingToSave) {
                    Text("treatmentFlow.form.error.empty").font(Typography.meta).foregroundStyle(Palette.coralText)
                        .accessibilityIdentifier("treatmentFlow.form.emptyError")
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("treatmentFlow.form")
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private var dictate: some View {
        Button { viewModel.startListening() } label: {
            Label { Text("visitForm.dictate") } icon: { Image(icon: .mic) }
        }
        .buttonStyle(.belloChip(selected: false))
        .accessibilityIdentifier("treatmentFlow.register.voiceButton")
    }

    private func quickNote(_ field: TreatmentFormField) -> some View {
        BelloNoteField(
            title: Text("visitForm.quickNote"), text: binding(for: field.key),
            prompt: "visitForm.quickNote.prompt", isSensitive: true,
            identifier: "treatmentFlow.form.field.\(field.key)"
        )
        .disabled(viewModel.isLocked)
    }

    private func professionSection(_ sections: VisitFormSections) -> some View {
        DisclosureGroup(isExpanded: $showsProfession) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !viewModel.lastVisitValues.isEmpty, !viewModel.isLocked { sameAsLastVisit }
                ForEach(sections.profession) { field in input(field) }
                if !sections.moreProfession.isEmpty { moreFields(sections.moreProfession) }
            }
            .padding(.top, Spacing.md)
        } label: {
            sectionLabel("visitForm.section.profession", identifier: "visitForm.section.profession")
        }
        .tint(Palette.ink)
    }

    private func resultSection(_ fields: [TreatmentFormField]) -> some View {
        DisclosureGroup(isExpanded: $showsResult) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TreatmentResultPicker(result: Binding(get: { viewModel.draft.result },
                                                      set: { viewModel.setResult($0) }))
                    .disabled(viewModel.isLocked)
                ForEach(fields) { field in input(field) }
            }
            .padding(.top, Spacing.md)
        } label: {
            sectionLabel("visitForm.section.result", identifier: "visitForm.section.result")
        }
        .tint(Palette.ink)
    }

    private func guidanceSection(_ fields: [TreatmentFormField]) -> some View {
        DisclosureGroup(isExpanded: $showsGuidance) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(fields) { field in input(field) }
                VisitNextSessionPicker(viewModel: viewModel)
            }
            .padding(.top, Spacing.md)
        } label: {
            sectionLabel("visitForm.section.guidance", identifier: "visitForm.section.guidance")
        }
        .tint(Palette.ink)
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
        let day = viewModel.lastVisit.map { viewModel.formatters.shortDate($0.performedAt ?? $0.createdAt) } ?? ""
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

    private func sectionLabel(_ title: LocalizedStringKey, identifier: String) -> some View {
        Text(title)
            .font(Typography.section)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(identifier)
    }

    private func input(_ field: TreatmentFormField) -> some View {
        TreatmentFieldInput(
            field: field, value: binding(for: field.key), suggestions: viewModel.productNames,
            hasError: viewModel.showsValidation && viewModel.issue(forNumberField: field.key),
            choices: viewModel.choices(for: field),
            textSuggestions: field.role == .technique ? viewModel.techniqueSuggestions : [],
            onAddOption: addOption(for: field)
        )
        .disabled(viewModel.isLocked)
    }

    /// "+ Add" for the lists that take new options: techniques, products and her fields' choices. Fixed answers
    /// (yes or no, the result) and free notes get none.
    private func addOption(for field: TreatmentFormField) -> ((String, Bool) -> Void)? {
        guard !viewModel.isLocked else { return nil }
        switch (field.role, field.input) {
        case (.technique, _): return { viewModel.addTechnique($0, save: $1, fieldKey: field.key) }
        case (_, .products): return { viewModel.addProduct($0, save: $1, fieldKey: field.key) }
        case (_, .choice), (_, .multiChoice): return { viewModel.addChoice($0, save: $1, field: field) }
        default: return nil
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if viewModel.isLocked {
            FlowBottomBar {
                Button(action: onCancel) { Text("treatmentFlow.saved.done") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("treatmentFlow.form.doneButton")
            }
        } else {
            FlowBottomBar {
                Button { viewModel.finalizeTapped() } label: {
                    if viewModel.isSaving && viewModel.autosave != .saving {
                        ProgressView()
                    } else {
                        Text(viewModel.isFinalized ? "visitForm.saveChanges" : "visitForm.finalize")
                    }
                }
                .buttonStyle(.belloPrimary)
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("treatmentFlow.form.saveButton")
                Text("visitForm.finalize.hint")
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { viewModel.draft.value(for: key) }, set: { viewModel.set($0, for: key) })
    }
}
