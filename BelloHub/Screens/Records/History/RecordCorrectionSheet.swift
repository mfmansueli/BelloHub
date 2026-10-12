//
//  RecordCorrectionSheet.swift
//  BelloHub
//

import SwiftUI

/// "Add correction" (and, while a record is still open, "Edit"). Once a record is locked the original never
/// changes: the new text is saved as a correction with the reason, logged with date and time.
/// While it is open the text is replaced.
struct RecordCorrectionSheet<Model: RecordCorrecting>: View {
    let viewModel: Model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            Group {
                if let draft = viewModel.draft { form(draft) } else { Color.clear }
            }
            .background(Palette.bg)
            .navigationTitle(Text(isCorrection ? "recordHistory.correction.title" : "recordHistory.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { viewModel.cancelCorrection() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("recordHistory.correction.cancelButton")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isWorking)
    }

    private var isCorrection: Bool { viewModel.draftPath == .addCorrection }

    // MARK: - Form

    private func form(_ draft: RecordCorrectionDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(isCorrection ? "recordHistory.correction.intro" : "recordHistory.edit.intro")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                if let message = viewModel.actionErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "recordHistory.error.dismiss",
                        action: viewModel.dismissActionError
                    )
                    .accessibilityIdentifier("recordHistory.correction.saveError")
                }
                fieldPicker(draft)
                current
                BelloNoteField(
                    title: Text("recordHistory.correction.newValue"),
                    text: Binding(get: { draft.newValue }, set: { viewModel.draft?.newValue = $0 }),
                    isSensitive: true, identifier: "recordHistory.correction.newValueField"
                )
                if isCorrection {
                    BelloNoteField(
                        title: Text("recordHistory.correction.reason"),
                        text: Binding(get: { draft.reason }, set: { viewModel.draft?.reason = $0 }),
                        prompt: "recordHistory.correction.reasonPrompt", isSensitive: true,
                        identifier: "recordHistory.correction.reasonField"
                    )
                }
                problem
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("recordHistory.correction.form")
        .safeAreaInset(edge: .bottom) { saveBar }
    }

    private func fieldPicker(_ draft: RecordCorrectionDraft) -> some View {
        Picker(selection: Binding(get: { draft.field }, set: { viewModel.selectField($0) })) {
            ForEach(viewModel.editableFields) { field in
                Text(verbatim: field.title(in: locale)).tag(field)
            }
        } label: {
            Text("recordHistory.correction.field")
        }
        .pickerStyle(.menu)
        .tint(Palette.roseText)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier("recordHistory.correction.fieldPicker")
    }

    @ViewBuilder
    private var current: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("recordHistory.correction.current").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            if let value = viewModel.draftCurrentValue {
                Text(verbatim: value).font(Typography.body).foregroundStyle(Palette.ink)
            } else {
                Text("recordHistory.correction.empty").font(Typography.body).foregroundStyle(Palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recordHistory.correction.current")
    }

    @ViewBuilder
    private var problem: some View {
        switch viewModel.draftProblem {
        case .unchanged:
            Text("recordHistory.correction.unchanged").font(Typography.meta).foregroundStyle(Palette.coralText)
                .accessibilityIdentifier("recordHistory.correction.problem")
        case .reasonMissing:
            Text("recordHistory.correction.reasonMissing").font(Typography.meta).foregroundStyle(Palette.coralText)
                .accessibilityIdentifier("recordHistory.correction.problem")
        case nil:
            EmptyView()
        }
    }

    private var saveBar: some View {
        FlowBottomBar {
            Button { viewModel.saveCorrection() } label: {
                if viewModel.isWorking {
                    ProgressView()
                } else {
                    Text(isCorrection ? "recordHistory.correction.save" : "recordHistory.edit.save")
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("recordHistory.correction.saveButton")
        }
    }
}
