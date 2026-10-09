//
//  AddOnEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet for one add-on: "New add-on" (name, extra time, optional price) or an existing one (change it or delete
/// it). The name and the price are checked while she types by the same rule that decides on save (`AddOnRules`).
struct AddOnEditorSheet: View {
    let mode: AddOnEditorMode
    let viewModel: AddOnsViewModel
    let formatters: Formatters

    @State private var draft: AddOnDraft
    @State private var isSaving = false
    @State private var pendingDeletion: AddOn?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    init(mode: AddOnEditorMode, viewModel: AddOnsViewModel, formatters: Formatters) {
        self.mode = mode
        self.viewModel = viewModel
        self.formatters = formatters
        _draft = State(initialValue: viewModel.draft(for: mode.addOn))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage {
                        ErrorNotice(message: message).accessibilityIdentifier("addOnEditor.saveError")
                    }
                    fields
                    Text("addOns.editor.nameHint").font(Typography.footnote).foregroundStyle(Palette.ink2)
                    if let addOn = mode.addOn { deleteButton(for: addOn) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(mode.addOn == nil ? "addOns.editor.addTitle" : "addOns.editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("addOnEditor.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onSubmit { if canSave { save() } }
            .onAppear { isFocused = mode.addOn == nil }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .deletionDialog(
            $pendingDeletion,
            title: { addOn in
                Text(LocalizedStringResource(
                    "addOns.delete.title", defaultValue: "Delete “\(addOn.name)”?"
                ).localized(in: locale))
            },
            message: { _ in Text("addOns.delete.message") },
            confirm: DeletionConfirm(title: "addOns.delete.confirm", identifier: "addOnEditor.deleteConfirmButton"),
            onConfirm: delete
        )
    }

    // MARK: - Parts

    private var fields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ListCard(dividerInset: Spacing.md) {
                LabeledFieldRow(label: "onb.service.name") {
                    TextField(text: $draft.name, prompt: .prompt("addOns.editor.namePrompt")) {
                        Text("onb.service.name")
                    }
                    .focused($isFocused)
                    .accessibilityIdentifier("addOnEditor.nameField")
                }
                LabeledFieldRow(label: "onb.service.price") {
                    TextField(text: $draft.priceText, prompt: .prompt("onb.service.pricePrompt")) {
                        Text("onb.service.price")
                    }
                    .keyboardType(.decimalPad)
                    .foregroundStyle(isPriceInvalid ? Palette.coralText : Palette.ink)
                    .accessibilityIdentifier("addOnEditor.priceField")
                }
                LabeledFieldRow(label: "addOns.editor.extraTime") {
                    Picker(selection: $draft.minutes) {
                        ForEach(AddOnRules.minuteOptions(including: draft.minutes), id: \.self) { minutes in
                            Text(verbatim: extra(minutes)).tag(minutes)
                        }
                    } label: { Text("addOns.editor.extraTime") }
                    .pickerStyle(.menu)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("addOnEditor.minutesMenu")
                }
            }
            if let nameError {
                Text(nameError).font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("addOnEditor.nameError")
            }
            if isPriceInvalid {
                Text("services.editor.priceInvalid").font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("addOnEditor.priceError")
            }
        }
    }

    private func deleteButton(for addOn: AddOn) -> some View {
        Button { pendingDeletion = addOn } label: { Text("addOns.editor.delete") }
            .buttonStyle(.belloDestructive)
            .accessibilityIdentifier("addOnEditor.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
            } else {
                Text(mode.addOn == nil ? "addOns.editor.add" : "addOns.editor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!canSave || isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("addOnEditor.saveButton")
    }

    // MARK: - Rules

    private var issues: [AddOnFormIssue] { viewModel.issues(in: draft, editing: mode.addOn?.id) }

    private var canSave: Bool { issues.isEmpty }

    private var isPriceInvalid: Bool { issues.contains(.priceInvalid) }

    /// Shown only for a name that is wrong, not for an empty field she has not typed in yet.
    private var nameError: LocalizedStringKey? {
        if issues.contains(.nameTaken) { return "addOns.error.nameTaken" }
        if issues.contains(.nameTooLong) { return "services.error.nameTooLong" }
        return nil
    }

    private func extra(_ minutes: Int) -> String {
        String(localized: LocalizedStringResource(
            "addOns.row.extra", defaultValue: "+\(formatters.minutes(minutes))"
        ).localized(in: locale))
    }

    // MARK: - Actions

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await viewModel.save(draft, editing: mode.addOn)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func delete(_ addOn: AddOn) {
        Task {
            if await viewModel.delete(addOn) { dismiss() }
        }
    }
}
