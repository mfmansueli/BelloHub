//
//  ServiceEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// 6.2 ServiceEdit: "New service" or an existing one (change it, switch it off, delete it). Opens as a native sheet
/// with its own navigation stack, because the contraindication picker is pushed inside it. The form is a `ServiceDraft`
/// that is checked while she types by the same rule that decides on save (`ServiceRules`), so a name that is taken or
/// a price that is not a number says so under the field instead of failing after the tap.
struct ServiceEditorSheet: View {
    let mode: ServiceEditorMode
    let viewModel: ServicesViewModel
    let formatters: Formatters

    @State private var draft: ServiceDraft
    @State private var categories: [String]
    @State private var isSaving = false
    @State private var pendingDeletion: Service?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(mode: ServiceEditorMode, viewModel: ServicesViewModel, formatters: Formatters) {
        self.mode = mode
        self.viewModel = viewModel
        self.formatters = formatters
        let start = mode.service.map(viewModel.draft(for:)) ?? viewModel.newDraft()
        _draft = State(initialValue: start)
        _categories = State(initialValue: viewModel.categories(including: start.category))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage {
                        ErrorNotice(message: message).accessibilityIdentifier("serviceEditor.saveError")
                    }
                    ServiceBasicsSection(draft: $draft, formatters: formatters, nameError: nameError)
                    ServiceTimingSection(draft: $draft, formatters: formatters)
                    ServiceCategorySection(draft: $draft, categories: categories)
                    priceVisibility
                    followUp
                    ServiceContraindicationsSection(draft: $draft, groups: viewModel.contraindicationGroups)
                    ServiceRemindersSection(draft: $draft, formatters: formatters)
                    offered
                    if let service = mode.service { deleteButton(for: service) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            // Immediately, unlike the short sheets: the form is three screens long and its price field has a number
            // pad with no return key, so scrolling to the settings below must put the keyboard away.
            .scrollDismissesKeyboard(.immediately)
            .background(Palette.bg)
            .navigationTitle(Text(mode.service == nil ? "services.editor.addTitle" : "services.editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("serviceEditor.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .task { viewModel.loadContraindicationOptions() }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .deletionDialog(
            $pendingDeletion,
            title: { service in
                Text(LocalizedStringResource(
                    "services.delete.title", defaultValue: "Delete “\(service.name)”?"
                ).localized(in: locale))
            },
            message: { _ in Text("services.delete.message") },
            confirm: DeletionConfirm(title: "services.delete.confirm", identifier: "serviceEditor.deleteConfirmButton"),
            onConfirm: delete
        )
    }

    // MARK: - Parts

    private var priceVisibility: some View {
        ChoiceChips(
            title: "services.editor.priceVisibility",
            options: PriceDisplay.allCases,
            isSelected: { $0 == draft.priceDisplay },
            label: { text($0.label) },
            identifier: { "serviceEditor.priceMode.\($0.rawValue)" },
            onSelect: { draft.priceDisplay = $0 }
        )
    }

    private var followUp: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ChoiceChips(
                title: "onb.service.followUp",
                options: ServiceRules.followUpOptions(including: draft.followUpWeeks),
                isSelected: { $0 == draft.followUpWeeks },
                label: { formatters.weeks($0) },
                identifier: { "serviceEditor.followUp.\($0)" },
                onSelect: { draft.followUpWeeks = draft.followUpWeeks == $0 ? nil : $0 }
            )
            Text("onb.service.followUpHint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var offered: some View {
        ListCard(dividerInset: Spacing.md) {
            ToggleRow(
                title: text("services.editor.offered"), subtitle: text("services.editor.offeredHint"),
                isOn: $draft.isActive, identifier: "serviceEditor.activeToggle"
            )
        }
    }

    private func deleteButton(for service: Service) -> some View {
        Button { pendingDeletion = service } label: { Text("services.editor.delete") }
            .buttonStyle(.belloDestructive)
            .accessibilityIdentifier("serviceEditor.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
            } else {
                Text("services.editor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!canSave || isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("serviceEditor.saveButton")
    }

    // MARK: - Rules

    private var issues: [ServiceFormIssue] { viewModel.issues(in: draft, editing: mode.service?.id) }

    private var canSave: Bool { issues.isEmpty }

    /// Shown only for a name that is wrong, not for an empty field she has not typed in yet.
    private var nameError: LocalizedStringKey? {
        if issues.contains(.nameTaken) { return "services.error.nameTaken" }
        if issues.contains(.nameTooLong) { return "services.error.nameTooLong" }
        return nil
    }

    // MARK: - Actions

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await viewModel.save(draft, editing: mode.service)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func delete(_ service: Service) {
        Task {
            if await viewModel.delete(service) { dismiss() }
        }
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }
}

#if DEBUG
#Preview {
    let repository = InMemoryClientRecordRepository()
    return ServiceEditorSheet(
        mode: .add, viewModel: ServicesViewModel(repository: repository),
        formatters: Formatters(locale: .current, timeZone: .current, currencyCode: "BRL")
    )
}
#endif
