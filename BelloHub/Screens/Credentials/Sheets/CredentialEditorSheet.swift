//
//  CredentialEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet for one credential: "Add credential" (name, institution, year) or an existing one (change it or delete
/// it). The year is checked while she types by the same rule that decides on save (`CredentialRules`). The certificate
/// photo of the prototype waits for the photo pipeline (S7).
struct CredentialEditorSheet: View {
    let mode: CredentialEditorMode
    let viewModel: CredentialsViewModel

    @State private var draft: CredentialDraft
    @State private var isSaving = false
    @State private var pendingDeletion: Credential?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    init(mode: CredentialEditorMode, viewModel: CredentialsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.draft(for: mode.credential))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage {
                        ErrorNotice(message: message).accessibilityIdentifier("credentialEditor.saveError")
                    }
                    fields
                    if let credential = mode.credential { deleteButton(for: credential) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("credentialEditor.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onAppear { isFocused = mode.credential == nil }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .deletionDialog(
            $pendingDeletion,
            title: { credential in
                Text(LocalizedStringResource(
                    "credentials.delete.title", defaultValue: "Delete “\(credential.title)”?"
                ).localized(in: locale))
            },
            message: { _ in Text("credentials.delete.message") },
            confirm: DeletionConfirm(
                title: "credentials.delete.confirm", identifier: "credentialEditor.deleteConfirmButton"
            ),
            onConfirm: delete
        )
    }

    // MARK: - Parts

    private var fields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ListCard(dividerInset: Spacing.md) {
                LabeledFieldRow(label: "onb.service.name") {
                    TextField(text: $draft.title, prompt: .prompt("credentials.editor.titlePrompt")) {
                        Text("onb.service.name")
                    }
                    .focused($isFocused)
                    .accessibilityIdentifier("credentialEditor.titleField")
                }
                LabeledFieldRow(label: "credentials.editor.institution") {
                    TextField(text: $draft.institution, prompt: .prompt("onb.service.pricePrompt")) {
                        Text("credentials.editor.institution")
                    }
                    .accessibilityIdentifier("credentialEditor.institutionField")
                }
                LabeledFieldRow(label: "credentials.editor.year") {
                    TextField(text: $draft.yearText, prompt: .prompt("onb.service.pricePrompt")) {
                        Text("credentials.editor.year")
                    }
                    .keyboardType(.numberPad)
                    .foregroundStyle(issues.contains(.yearInvalid) ? Palette.coralText : Palette.ink)
                    .accessibilityIdentifier("credentialEditor.yearField")
                }
            }
            if issues.contains(.yearInvalid) {
                Text("credentials.editor.yearInvalid").font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("credentialEditor.yearError")
            }
            if issues.contains(.titleTooLong) || issues.contains(.institutionTooLong) {
                Text("services.error.nameTooLong").font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private func deleteButton(for credential: Credential) -> some View {
        Button { pendingDeletion = credential } label: { Text("credentials.editor.delete") }
            .buttonStyle(.belloDestructive)
            .accessibilityIdentifier("credentialEditor.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
            } else {
                Text("credentials.editor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!canSave || isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("credentialEditor.saveButton")
    }

    private var title: LocalizedStringKey {
        mode.credential == nil ? "credentials.editor.addTitle" : "credentials.editor.editTitle"
    }

    // MARK: - Rules

    private var issues: [CredentialFormIssue] { viewModel.issues(in: draft) }

    private var canSave: Bool { issues.isEmpty }

    // MARK: - Actions

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await viewModel.save(draft, editing: mode.credential)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func delete(_ credential: Credential) {
        Task {
            if await viewModel.delete(credential) { dismiss() }
        }
    }
}
