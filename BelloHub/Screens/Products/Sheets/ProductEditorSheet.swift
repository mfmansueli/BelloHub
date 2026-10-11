//
//  ProductEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet for one product: "New product" (name, brand, kind, a note, whether clients see it) or an existing one
/// (change it or delete it). The name is checked while she types by the same rule that decides on save
/// (`ProductRules`).
struct ProductEditorSheet: View {
    let mode: ProductEditorMode
    let viewModel: ProductsViewModel

    @State private var draft: ProductDraft
    @State private var isSaving = false
    @State private var pendingDeletion: Product?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    init(mode: ProductEditorMode, viewModel: ProductsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.draft(for: mode.product))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage {
                        ErrorNotice(message: message).accessibilityIdentifier("productEditor.saveError")
                    }
                    fields
                    ChoiceChips(
                        title: "products.editor.category",
                        options: ProductCategory.allCases,
                        isSelected: { $0 == draft.category },
                        label: { String(localized: $0.label.localized(in: locale)) },
                        identifier: { "productEditor.category.\($0.rawValue)" },
                        onSelect: { draft.category = $0 }
                    )
                    BelloNoteField(
                        title: Text("products.editor.note"), text: $draft.note, prompt: "products.editor.notePrompt",
                        identifier: "productEditor.noteField"
                    )
                    ListCard(dividerInset: Spacing.md) {
                        ToggleRow(
                            title: text("products.editor.share"), subtitle: text("products.editor.shareHint"),
                            isOn: $draft.sharedWithClient, identifier: "productEditor.shareToggle"
                        )
                    }
                    if let product = mode.product { deleteButton(for: product) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(mode.product == nil ? "products.editor.addTitle" : "products.editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("productEditor.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onAppear { isFocused = mode.product == nil }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .deletionDialog(
            $pendingDeletion,
            title: { product in
                Text(LocalizedStringResource(
                    "products.delete.title", defaultValue: "Delete “\(product.name)”?"
                ).localized(in: locale))
            },
            message: { _ in Text("products.delete.message") },
            confirm: DeletionConfirm(title: "products.delete.confirm", identifier: "productEditor.deleteConfirmButton"),
            onConfirm: delete
        )
    }

    // MARK: - Parts

    private var fields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ListCard(dividerInset: Spacing.md) {
                LabeledFieldRow(label: "onb.service.name") {
                    TextField(text: $draft.name, prompt: .prompt("products.editor.namePrompt")) {
                        Text("onb.service.name")
                    }
                    .focused($isFocused)
                    .accessibilityIdentifier("productEditor.nameField")
                }
                LabeledFieldRow(label: "products.editor.brand") {
                    TextField(text: $draft.brand, prompt: .prompt("onb.service.pricePrompt")) {
                        Text("products.editor.brand")
                    }
                    .accessibilityIdentifier("productEditor.brandField")
                }
            }
            if let nameError {
                Text(nameError).font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("productEditor.nameError")
            }
        }
    }

    private func deleteButton(for product: Product) -> some View {
        Button { pendingDeletion = product } label: { Text("products.editor.delete") }
            .buttonStyle(.belloDestructive)
            .accessibilityIdentifier("productEditor.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
            } else {
                Text(mode.product == nil ? "products.editor.add" : "products.editor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!canSave || isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("productEditor.saveButton")
    }

    // MARK: - Rules

    private var issues: [ProductFormIssue] { viewModel.issues(in: draft, editing: mode.product?.id) }

    private var canSave: Bool { issues.isEmpty }

    /// Shown only for a name that is wrong, not for an empty field she has not typed in yet.
    private var nameError: LocalizedStringKey? {
        if issues.contains(.nameTaken) { return "products.error.nameTaken" }
        if issues.contains(.nameTooLong) { return "services.error.nameTooLong" }
        return nil
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }

    // MARK: - Actions

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await viewModel.save(draft, editing: mode.product)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func delete(_ product: Product) {
        Task {
            if await viewModel.delete(product) { dismiss() }
        }
    }
}
