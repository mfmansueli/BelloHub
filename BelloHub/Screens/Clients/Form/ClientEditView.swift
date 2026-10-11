//
//  ClientEditView.swift
//  BelloHub
//

import SwiftUI

/// 4.3 ClientEdit. Name, WhatsApp, email, birthday and tags; stopping online booking with a private reason; turning
/// reminders off; archiving (the client leaves the lists, the record stays, and she can be restored) and merging a
/// duplicate profile into this one; exporting her record (4.10) and deleting her data when she asks
/// (`ClientDeleteDataRow`, D30): the two answers to a data-subject request sit together, export first.
///
/// It is pushed on the Clients stack, so the back button is replaced by Cancel: leaving with unsaved changes asks
/// first.
struct ClientEditView: View {
    let onFinish: (ClientFormViewModel.Finish) -> Void
    let onOpenExisting: (UUID) -> Void
    /// The duplicate was merged into this client: the screen has nothing left to edit.
    let onMerged: () -> Void
    /// Her data was deleted: there is no profile to go back to.
    let onDeleted: () -> Void

    @State private var viewModel: ClientFormViewModel
    @State private var confirmsArchive = false
    @State private var confirmsDiscard = false
    @State private var showsMerge = false
    @State private var recordSheet: RecordSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(ProfileService.self) private var profile
    private let vault: VaultService
    private let clientID: UUID

    init(
        clientID: UUID, vault: VaultService, profile: ProfileService, registrar: any ClientRegistering,
        regions: RegionCatalog, onFinish: @escaping (ClientFormViewModel.Finish) -> Void,
        onOpenExisting: @escaping (UUID) -> Void, onMerged: @escaping () -> Void,
        onDeleted: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: ClientFormViewModel(
            mode: .edit(clientID: clientID), registrar: registrar, vault: vault, profile: profile, regions: regions
        ))
        self.vault = vault
        self.clientID = clientID
        self.onFinish = onFinish
        self.onOpenExisting = onOpenExisting
        self.onMerged = onMerged
        self.onDeleted = onDeleted
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            // Why: a form that ends with Cancel or Save is a task of its own; the tab bar would cover its last rows.
            .toolbarVisibility(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: cancel) { Text("common.cancel") }
                        .accessibilityIdentifier("clientEdit.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { viewModel.save() } label: { Text("clientForm.save") }
                        .disabled(!viewModel.canSave)
                        .accessibilityIdentifier("clientEdit.saveButton")
                }
            }
            .task { await viewModel.load() }
            .sensoryFeedback(.success, trigger: viewModel.finish) { _, new in
                if case .updated = new { true } else { false }
            }
            .sheet(isPresented: $showsMerge) {
                ClientMergeSheet(keptID: clientID, vault: vault, profile: profile, onMerged: {
                    showsMerge = false
                    onMerged()
                })
            }
            .recordSheet(item: $recordSheet)
            .confirmationDialog(archiveTitle, isPresented: $confirmsArchive, titleVisibility: .visible) {
                Button { viewModel.setArchived(true) } label: { Text("clientEdit.archive.confirm") }
                    .accessibilityIdentifier("clientEdit.archiveConfirmButton")
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text(archiveMessage)
            }
            .confirmationDialog(
                Text("clientForm.discard.title"), isPresented: $confirmsDiscard, titleVisibility: .visible
            ) {
                Button(role: .destructive) { dismiss() } label: { Text("clientForm.discard.confirm") }
                    .accessibilityIdentifier("clientEdit.discardButton")
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
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.original != nil {
            form
        } else if viewModel.isMissing {
            EmptyState(
                icon: .user, title: Text("clientProfile.missing.title"), message: Text("clientProfile.missing.message")
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientEdit.missing")
        } else if viewModel.errorMessage != nil {
            EmptyState(
                icon: .alert, title: Text("clientProfile.error.title"), message: Text(viewModel.errorMessage ?? ""),
                actionTitle: "clientProfile.error.retry", action: { Task { await viewModel.load() } }
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientEdit.error")
        } else {
            VStack(spacing: Spacing.md) {
                Skeleton(height: 52)
                Skeleton(height: 52)
                Skeleton(height: 52)
                Spacer(minLength: 0)
            }
            .padding(Spacing.gutter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("clientProfile.loading"))
            .accessibilityIdentifier("clientEdit.loading")
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Avatar(name: viewModel.draft.name, id: clientID.uuidString, size: 80).fixedAvatarText()
                    .frame(maxWidth: .infinity)
                ClientFormFields(viewModel: viewModel, idPrefix: "clientEdit", onOpenExisting: onOpenExisting)
                BirthdayField(
                    birthday: Binding(get: { viewModel.draft.birthday }, set: { viewModel.draft.birthday = $0 }),
                    problem: viewModel.birthdayProblem, currentYear: viewModel.currentYear
                )
                ClientTagPicker(
                    tags: viewModel.tags, selected: viewModel.draft.tagIDs, idPrefix: "clientEdit",
                    onToggle: viewModel.toggleTag, onCreate: createTag
                )
                ClientEditBookingSection(viewModel: viewModel, professionalName: profile.profile?.firstName ?? "")
                actions
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("clientEdit.form")
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if viewModel.original?.isArchived == true {
                ActionRow(
                    icon: .box, title: Text(restoreTitle), subtitle: Text("clientEdit.restore.subtitle"),
                    tone: .sage, showsChevron: false, identifier: "clientEdit.restoreRow",
                    action: { viewModel.setArchived(false) }
                )
            } else {
                ActionRow(
                    icon: .box, title: Text(archiveRowTitle), subtitle: Text("clientEdit.archive.subtitle"),
                    tone: .peach, showsChevron: false, identifier: "clientEdit.archiveRow",
                    action: { confirmsArchive = true }
                )
            }
            ActionRow(
                icon: .clients, title: "clientEdit.merge.title", subtitle: Text("clientEdit.merge.subtitle"),
                tone: .rose, identifier: "clientEdit.mergeRow", action: { showsMerge = true }
            )
            ActionRow(
                icon: .share, title: "clientEdit.exportData.title", subtitle: Text("clientEdit.exportData.subtitle"),
                tone: .peach, identifier: "clientEdit.exportDataRow",
                action: { recordSheet = .exportRecord(clientID: clientID) }
            )
            ClientDeleteDataRow(clientID: clientID, firstName: viewModel.firstName, onDeleted: onDeleted)
        }
    }

    // MARK: - Words

    private var term: String {
        BidiIsolate.wrap(profile.clientTerm.singularText(in: locale))
    }

    /// "Edit client", with the word she chose for the people she serves.
    private var title: LocalizedStringResource {
        LocalizedStringResource("clientEdit.title", defaultValue: "Edit \(term)").localized(in: locale)
    }

    private var archiveRowTitle: LocalizedStringResource {
        LocalizedStringResource("clientEdit.archive.title", defaultValue: "Archive \(term)").localized(in: locale)
    }

    private var restoreTitle: LocalizedStringResource {
        LocalizedStringResource("clientEdit.restore.title", defaultValue: "Restore \(term)").localized(in: locale)
    }

    /// "Archive Ana?": her first name, so it is clear who disappears from the lists.
    private var archiveTitle: Text {
        Text(LocalizedStringResource(
            "clientEdit.archive.dialogTitle", defaultValue: "Archive \(BidiIsolate.wrap(viewModel.firstName))?"
        ).localized(in: locale))
    }

    private var archiveMessage: LocalizedStringResource {
        LocalizedStringResource(
            "clientEdit.archive.dialogMessage",
            defaultValue: """
            \(BidiIsolate.wrap(viewModel.firstName)) disappears from your lists and from booking suggestions. \
            The record is kept and you can restore it any time.
            """
        ).localized(in: locale)
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.dismissError() } })
    }

    // MARK: - Actions

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
        NavigationStack {
            ClientEditView(
                clientID: world.seeded.ana, vault: world.vault, profile: world.profile, registrar: world.registration,
                regions: world.regions, onFinish: { _ in }, onOpenExisting: { _ in }, onMerged: {}
            )
        }
    }
}
#endif
