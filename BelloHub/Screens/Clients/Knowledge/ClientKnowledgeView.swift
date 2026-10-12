//
//  ClientKnowledgeView.swift
//  BelloHub
//

import SwiftUI

/// 4.4 ClientKnowledge. What she wants to remember about a client, in her own words: the private "important to know"
/// note and three lists (sensitivities, preferences, recurring requests). A native `List` held in edit mode, so
/// removing and reordering entries are the system's own controls, always on screen and spoken by VoiceOver.
/// Nothing is saved until Done.
///
/// Pushed on the Clients stack with its back button replaced by Cancel, which asks before throwing changes away.
struct ClientKnowledgeView: View {
    let onFinish: () -> Void

    @State private var viewModel: ClientKnowledgeViewModel
    @State private var confirmsDiscard = false
    /// The list whose "+ Add" sheet is open.
    @State private var addingTo: KnowledgeSection?
    @Environment(OptionCatalogService.self) private var options: OptionCatalogService?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(clientID: UUID, vault: VaultService, registrar: any ClientRegistering, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: ClientKnowledgeViewModel(
            clientID: clientID, registrar: registrar, vault: vault
        ))
        self.onFinish = onFinish
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("clientKnowledge.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            // Why: a form that ends with Cancel or Save is a task of its own; the tab bar would cover its last rows.
            .toolbarVisibility(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: cancel) { Text("common.cancel") }
                        .accessibilityIdentifier("clientKnowledge.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { viewModel.done() } label: { Text("clientKnowledge.done") }
                        .disabled(viewModel.original == nil || viewModel.isSaving)
                        .accessibilityIdentifier("clientKnowledge.doneButton")
                }
            }
            .task { await viewModel.load() }
            .task { await options?.loadIfNeeded() }
            .sheet(item: $addingTo) { section in
                OptionAddSheet(title: Text(section.title), existing: options?.names(in: section.optionContext) ?? [],
                               canSave: options != nil) { name, save in
                    viewModel.add(name, to: section)
                    if save { Task { _ = try? await options?.add(name, to: section.optionContext) } }
                }
            }
            .confirmationDialog(
                Text("clientForm.discard.title"), isPresented: $confirmsDiscard, titleVisibility: .visible
            ) {
                Button(role: .destructive) { dismiss() } label: { Text("clientForm.discard.confirm") }
                    .accessibilityIdentifier("clientKnowledge.discardButton")
                Button(role: .cancel) {} label: { Text("clientForm.discard.keep") }
            }
            .alert(Text("clientForm.error.title"), isPresented: saveErrorShown) {
                Button(role: .cancel) { viewModel.dismissError() } label: { Text("common.close") }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.isFinished) { _, finished in
                if finished { onFinish() }
            }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.original != nil {
            lists
        } else if viewModel.isMissing {
            EmptyState(
                icon: .user, title: Text("clientProfile.missing.title"), message: Text("clientProfile.missing.message")
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientKnowledge.missing")
        } else if viewModel.errorMessage != nil {
            EmptyState(
                icon: .alert, title: Text("clientProfile.error.title"), message: Text(viewModel.errorMessage ?? ""),
                actionTitle: "clientProfile.error.retry", action: viewModel.retry
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientKnowledge.error")
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("clientKnowledge.loading")
        }
    }

    // MARK: - Lists

    private var lists: some View {
        @Bindable var model = viewModel
        return List {
            Section {
                Text(intro)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .moveDisabled(true)
            }
            Section {
                TextField(text: $model.note, prompt: .prompt("clientForm.note.prompt"), axis: .vertical) {
                    Text("clientForm.note")
                }
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(2...8)
                .autocorrectionDisabled()
                .listRowBackground(Palette.surface)
                .moveDisabled(true)
                .accessibilityIdentifier("clientKnowledge.noteField")
            } header: {
                header("clientForm.note")
            }
            ForEach(KnowledgeSection.allCases) { section in
                Section {
                    entries(of: section)
                    addRow(for: section)
                } header: {
                    header(section.title)
                } footer: {
                    if section == .recurringRequests {
                        Text(footer).font(Typography.footnote).foregroundStyle(Palette.ink2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // Why: always in edit mode, so the delete and reorder handles are on screen without a separate Edit step.
        .environment(\.editMode, .constant(.active))
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("clientKnowledge.lists")
    }

    private func entries(of section: KnowledgeSection) -> some View {
        ForEach(Array(viewModel.entries(in: section).enumerated()), id: \.offset) { _, entry in
            Text(verbatim: entry)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .frame(minHeight: Spacing.touchTarget)
                .listRowBackground(Palette.surface)
        }
        .onDelete { viewModel.remove(at: $0, from: section) }
        .onMove { viewModel.move(from: $0, to: $1, in: section) }
    }

    private func addRow(for section: KnowledgeSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                TextField(text: pending(for: section), prompt: .prompt("clientKnowledge.add.prompt")) {
                    Text(section.title)
                }
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .submitLabel(.done)
                .onSubmit { viewModel.add(to: section) }
                .autocorrectionDisabled()
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityIdentifier("clientKnowledge.addField.\(section.rawValue)")
                Button { viewModel.add(to: section) } label: { Text("clients.add") }
                    .buttonStyle(.belloChip(selected: true))
                    .accessibilityIdentifier("clientKnowledge.addButton.\(section.rawValue)")
            }
            savedOptions(for: section)
            if viewModel.duplicateIn == section {
                Text("clientKnowledge.duplicate").font(Typography.footnote).foregroundStyle(Palette.coralText)
            }
        }
        .frame(minHeight: Spacing.touchTarget)
        .listRowBackground(Palette.surface)
        .deleteDisabled(true)
        .moveDisabled(true)
    }

    /// Her saved words for this list that the client does not have yet, one tap away, and "+ Add".
    private func savedOptions(for section: KnowledgeSection) -> some View {
        let saved = (options?.names(in: section.optionContext) ?? []).filter { viewModel.offers($0, in: section) }
        return FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(saved, id: \.self) { name in
                Button { viewModel.add(name, to: section) } label: { Text(verbatim: name) }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("clientKnowledge.option.\(section.rawValue).\(name)")
            }
            AddOptionChip(identifier: "clientKnowledge.addOption.\(section.rawValue)") { addingTo = section }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func header(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.metaStrong)
            .foregroundStyle(Palette.ink2)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Helpers

    private func pending(for section: KnowledgeSection) -> Binding<String> {
        Binding(get: { viewModel.pending[section] ?? "" }, set: { viewModel.pending[section] = $0 })
    }

    private var saveErrorShown: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.original != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }

    private var intro: LocalizedStringResource {
        LocalizedStringResource(
            "clientKnowledge.intro",
            defaultValue: """
            What you want to remember about \(BidiIsolate.wrap(viewModel.firstName)), in your own words. \
            Only you see this.
            """
        ).localized(in: locale)
    }

    private var footer: LocalizedStringResource {
        LocalizedStringResource(
            "clientKnowledge.footer",
            defaultValue: """
            Shown to you before every appointment. Never shared with \(BidiIsolate.wrap(viewModel.firstName)).
            """
        ).localized(in: locale)
    }

    private func cancel() {
        if viewModel.isDirty { confirmsDiscard = true } else { dismiss() }
    }
}

#if DEBUG
#Preview {
    ClientsPreviewHost { world in
        NavigationStack {
            ClientKnowledgeView(
                clientID: world.seeded.ana, vault: world.vault, registrar: world.registration, onFinish: {}
            )
        }
    }
}
#endif
