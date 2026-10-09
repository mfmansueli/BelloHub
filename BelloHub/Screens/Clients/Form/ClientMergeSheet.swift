//
//  ClientMergeSheet.swift
//  BelloHub
//

import SwiftUI

/// "Merge with a duplicate" (4.3), a sheet: pick the other profile of the same person and confirm. Her records, photos
/// and notes move to the client being edited and the other profile disappears; it cannot be undone, so it asks first.
struct ClientMergeSheet: View {
    let onMerged: () -> Void

    @State private var viewModel: ClientMergeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(keptID: UUID, vault: VaultService, profile: ProfileService, onMerged: @escaping () -> Void) {
        _viewModel = State(initialValue: ClientMergeViewModel(keptID: keptID, vault: vault, profile: profile))
        self.onMerged = onMerged
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("clientMerge.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.cancel") }
                            .accessibilityIdentifier("clientMerge.cancelButton")
                    }
                }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .task { await viewModel.load() }
        .confirmationDialog(
            confirmTitle, isPresented: chosenShown, titleVisibility: .visible, presenting: viewModel.chosen
        ) { other in
            Button(role: .destructive) { viewModel.merge(other) } label: { Text("clientMerge.confirm") }
                .accessibilityIdentifier("clientMerge.confirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: { other in
            Text(confirmMessage(other))
        }
        .alert(Text("clientForm.error.title"), isPresented: errorShown) {
            Button(role: .cancel) { viewModel.dismissError() } label: { Text("common.close") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.didMerge) { _, merged in
            if merged { onMerged() }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("clientMerge.loading")
        } else if viewModel.hasNoCandidates {
            EmptyState(
                icon: .clients, title: Text("clientMerge.empty.title"), message: Text("clientMerge.empty.message")
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientMerge.empty")
        } else if viewModel.kept == nil {
            EmptyState(
                icon: .alert, title: Text("clientProfile.error.title"), message: Text(viewModel.errorMessage ?? ""),
                actionTitle: "clientProfile.error.retry", action: { Task { await viewModel.load() } }
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientMerge.error")
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(viewModel.results) { client in
                    Button { viewModel.chosen = client } label: { row(client) }
                        .listRowBackground(Palette.surface)
                        .accessibilityIdentifier("clientMerge.row.\(client.id.uuidString)")
                }
            } header: {
                Text(intro)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                    .textCase(nil)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $viewModel.searchText, prompt: Text("clientMerge.search"))
        .accessibilityIdentifier("clientMerge.list")
    }

    private func row(_ client: Client) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: client.name, id: client.id.uuidString, size: 44).fixedAvatarText()
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: client.name)
                    .font(Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                if client.isArchived {
                    Text("clientMerge.archived").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: Spacing.touchTarget)
        .contentShape(Rectangle())
    }

    // MARK: - Words

    private var intro: LocalizedStringResource {
        let kept = viewModel.kept
        let name = BidiIsolate.wrap(kept?.name ?? "")
        let first = BidiIsolate.wrap(kept?.name.split(separator: " ").first.map(String.init) ?? "")
        return LocalizedStringResource(
            "clientMerge.intro",
            defaultValue: "Choose the profile to combine into \(name). Records, photos and notes move to \(first)."
        ).localized(in: locale)
    }

    private var confirmTitle: Text {
        Text("clientMerge.confirmTitle")
    }

    private func confirmMessage(_ other: Client) -> LocalizedStringResource {
        let from = BidiIsolate.wrap(other.name)
        let into = BidiIsolate.wrap(viewModel.kept?.name ?? "")
        return LocalizedStringResource(
            "clientMerge.confirmMessage",
            defaultValue: """
            Records, photos and notes of \(from) move to \(into). The profile of \(from) is removed. \
            This cannot be undone.
            """
        ).localized(in: locale)
    }

    private var chosenShown: Binding<Bool> {
        Binding(get: { viewModel.chosen != nil }, set: { if !$0 { viewModel.chosen = nil } })
    }

    /// A merge that failed. A failed load has its own state, so only a loaded sheet raises the alert.
    private var errorShown: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.kept != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}

#if DEBUG
#Preview {
    ClientsPreviewHost { world in
        ClientMergeSheet(keptID: world.seeded.ana, vault: world.vault, profile: world.profile, onMerged: {})
    }
}
#endif
