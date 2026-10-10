//
//  ClientsView.swift
//  BelloHub
//

import SwiftUI

/// 2.2 Clients. Everyone she serves, with search, filter chips, the "have not been back" strip and a count that uses
/// the word she chose for them. A native `List`, so it is lazy (2,000 clients stay smooth), refreshes by pulling and
/// gets swipe, search and Dynamic Type from the system. Loading, empty and error each have their own state.
struct ClientsView: View {
    let onAdd: () -> Void
    let onImport: () -> Void

    @State private var viewModel: ClientsViewModel
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init(vault: VaultService, profile: ProfileService, onAdd: @escaping () -> Void, onImport: @escaping () -> Void) {
        _viewModel = State(initialValue: ClientsViewModel(vault: vault, profile: profile))
        self.onAdd = onAdd
        self.onImport = onImport
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text(verbatim: profile.clientTerm.titlePlural(in: locale)))
            .toolbar { if showsToolbar { toolbar } }
            .task { viewModel.startListening() }
            .onChange(of: profile.tags) { viewModel.tagsChanged() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loading
        } else if viewModel.errorMessage != nil && viewModel.list.entries.isEmpty {
            errorState
        } else if viewModel.isEmpty {
            emptyState
        } else {
            list
        }
    }

    /// Add and Import are always one tap away once the list has loaded, empty or not.
    private var showsToolbar: Bool {
        !viewModel.isLoading
    }

    private var loading: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: Spacing.row) {
                    Skeleton(height: 48, cornerRadius: 24).frame(width: 48)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Skeleton(height: 16).frame(maxWidth: 180)
                        Skeleton(height: 13).frame(maxWidth: 120)
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("clients.loading"))
        .accessibilityIdentifier("clients.loading")
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                EmptyState(
                    icon: .clients,
                    title: Text(LocalizedStringResource(
                        "clients.empty.title", defaultValue: "No \(termPlural) yet"
                    ).localized(in: locale)),
                    message: Text("clients.empty.message"),
                    actionTitle: "clients.add", action: onAdd
                )
                Button(action: onImport) { Text("clients.import") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("clients.empty.importButton")
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("clients.empty")
    }

    private var errorState: some View {
        ScrollView {
            EmptyState(
                icon: .alert, title: Text("clients.error.title"), message: Text(viewModel.errorMessage ?? ""),
                actionTitle: "clients.error.retry", action: viewModel.refresh
            )
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("clients.error")
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                if viewModel.errorMessage != nil {
                    InlineNotice(style: .warning, title: "clients.error.refresh")
                        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.gutter, bottom: 0, trailing: Spacing.gutter))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ClientFilterChips(
                    chips: viewModel.chips, selected: viewModel.filter, tagsByID: viewModel.tagsByID,
                    onSelect: viewModel.select
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                if viewModel.winBackCount > 0 {
                    WinBackStrip(counted: profile.clientTerm.countText(viewModel.winBackCount, in: locale))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            Section {
                if viewModel.hasNoMatches {
                    noMatches
                } else {
                    ForEach(viewModel.visible) { entry in row(for: entry) }
                }
            } header: {
                countHeader
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refreshAsync() }
        .searchable(text: searchText, prompt: Text(searchPrompt))
        .accessibilityIdentifier("clients.list")
    }

    private func row(for entry: ClientListEntry) -> some View {
        NavigationLink(value: ClientsRoute.profile(clientID: entry.id)) {
            ClientRow(
                entry: entry, badge: .make(for: entry, tagsByID: viewModel.tagsByID), formatters: formatters,
                now: Date()
            )
        }
        .listRowBackground(Palette.surface)
        .accessibilityIdentifier("clients.row.\(entry.id.uuidString)")
    }

    private var countHeader: some View {
        Text(verbatim: profile.clientTerm.countText(viewModel.count, in: locale))
            .font(Typography.meta)
            .foregroundStyle(Palette.ink2)
            .textCase(nil)
            .accessibilityIdentifier("clients.count")
    }

    private var noMatches: some View {
        Text(viewModel.isSearching ? "clients.noMatches.search" : "clients.noMatches.filter")
            .font(Typography.meta)
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget * 2)
            .listRowBackground(Palette.surface)
            .accessibilityIdentifier("clients.noMatches")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onImport) {
                Label { Text("clients.import") } icon: { Image(icon: .download) }
            }
            .accessibilityIdentifier("clients.importButton")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onAdd) {
                Label { Text("clients.add") } icon: { Image(icon: .plus) }
            }
            .accessibilityIdentifier("clients.addButton")
        }
    }

    // MARK: - Helpers

    private var searchText: Binding<String> {
        Binding(get: { viewModel.searchText }, set: { viewModel.setSearchText($0) })
    }

    private var termPlural: String {
        BidiIsolate.wrap(profile.clientTerm.pluralText(in: locale))
    }

    private var searchPrompt: LocalizedStringResource {
        LocalizedStringResource("clients.search.prompt", defaultValue: "Search \(termPlural)").localized(in: locale)
    }

    private var formatters: Formatters {
        let timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: timeZone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }
}

#if DEBUG
#Preview {
    ClientsPreviewHost { world in
        NavigationStack {
            ClientsView(vault: world.vault, profile: world.profile, onAdd: {}, onImport: {})
        }
    }
}
#endif
