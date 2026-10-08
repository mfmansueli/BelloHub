//
//  NewClientView.swift
//  BelloHub
//

import SwiftUI

/// 4.2 NewClient, as a sheet: name, WhatsApp, email, tags and the private note, with the free-registration counter and
/// a way to import many people at once. Saving goes through the registration gate: it can open the new client's
/// profile, point at a client who already has the number, or show the paywall. "Send my booking link" and "Save and
/// book appointment" arrive with the booking link (S8) and the calendar (S6) and are not drawn until then.
struct NewClientView: View {
    let onFinish: (ClientFormViewModel.Finish) -> Void
    let onOpenExisting: (UUID) -> Void
    /// "View clients" at the end of an import: closes this sheet too.
    let onViewClients: () -> Void

    @State private var viewModel: ClientFormViewModel
    @State private var showsImport = false
    @State private var confirmsDiscard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(ProfileService.self) private var profile

    init(
        vault: VaultService, profile: ProfileService, registrar: any ClientRegistering, regions: RegionCatalog,
        onFinish: @escaping (ClientFormViewModel.Finish) -> Void, onOpenExisting: @escaping (UUID) -> Void,
        onViewClients: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: ClientFormViewModel(
            mode: .new, registrar: registrar, vault: vault, profile: profile, regions: regions
        ))
        self.onFinish = onFinish
        self.onOpenExisting = onOpenExisting
        self.onViewClients = onViewClients
    }

    var body: some View {
        @Bindable var model = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ActionRow(
                        icon: .download, title: "clientForm.import.title",
                        subtitle: Text("clientForm.import.subtitle"), tone: .peach,
                        identifier: "newClient.importRow", action: { showsImport = true }
                    )
                    ClientFormFields(viewModel: viewModel, idPrefix: "newClient", onOpenExisting: onOpenExisting)
                    ClientTagPicker(
                        tags: viewModel.tags, selected: viewModel.draft.tagIDs, idPrefix: "newClient",
                        onToggle: viewModel.toggleTag, onCreate: createTag
                    )
                    ClientNoteField(text: $model.draft.importantNote, identifier: "newClient.noteField")
                    RegistrationLimitNote(usage: viewModel.usage)
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
                    Button(action: cancel) { Text("common.cancel") }
                        .accessibilityIdentifier("newClient.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isDirty)
        .sheet(isPresented: $model.showsPaywall) { PaywallSheet() }
        .sheet(isPresented: $showsImport) {
            ImportClientsView(onViewClients: {
                showsImport = false
                onViewClients()
            })
        }
        .confirmationDialog(
            Text("clientForm.discard.title"), isPresented: $confirmsDiscard, titleVisibility: .visible
        ) {
            Button(role: .destructive) { dismiss() } label: { Text("clientForm.discard.confirm") }
                .accessibilityIdentifier("newClient.discardButton")
            Button(role: .cancel) {} label: { Text("clientForm.discard.keep") }
        }
        .alert(Text("clientForm.error.title"), isPresented: errorShown) {
            Button(role: .cancel) { viewModel.dismissError() } label: { Text("common.close") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.finish) { _, finish in
            if let finish { onFinish(finish) }
        }
        .task { await viewModel.refreshUsage() }
    }

    // MARK: - Parts

    /// "Add client", with the word she chose for the people she serves.
    private var title: LocalizedStringResource {
        let term = BidiIsolate.wrap(profile.clientTerm.singularText(in: locale))
        return LocalizedStringResource("clientForm.new.title", defaultValue: "Add \(term)").localized(in: locale)
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.dismissError() } })
    }

    private var saveBar: some View {
        Button { viewModel.save() } label: { Text("clientForm.save") }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
            .background(Palette.bg)
            .accessibilityIdentifier("newClient.saveButton")
    }

    // MARK: - Actions

    /// Asks before throwing away what she typed; closes at once when there is nothing to lose.
    private func cancel() {
        if viewModel.isDirty { confirmsDiscard = true } else { dismiss() }
    }

    private func createTag(_ name: String) {
        Task { await viewModel.addTag(named: name) }
    }
}

#if DEBUG
#Preview {
    ClientsPreviewHost { world in
        NewClientView(
            vault: world.vault, profile: world.profile, registrar: world.registration, regions: world.regions,
            onFinish: { _ in }, onOpenExisting: { _ in }, onViewClients: {}
        )
    }
}
#endif
