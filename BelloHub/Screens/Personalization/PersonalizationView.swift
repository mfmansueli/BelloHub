//
//  PersonalizationView.swift
//  BelloHub
//

import SwiftUI

/// More → Personalization: the options she saved to reuse, list by list (techniques, preferences, sensitivities,
/// recurring requests). Rename, drag to reorder, archive and restore; nothing is deleted, and nothing already written
/// in a record or on a client changes. Products and her fields' choices keep their own screens, linked here.
struct PersonalizationView: View {
    @Environment(OptionCatalogService.self) private var options
    @State private var context = OptionContext.technique
    @State private var renaming: SavedOption?
    @State private var newName = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            Section {
                Picker(selection: $context) {
                    ForEach(OptionContext.allCases) { context in
                        Text(context.title.localized(in: locale)).tag(context)
                    }
                } label: {
                    Text("personalization.list")
                }
                .pickerStyle(.menu)
                .tint(Palette.roseText)
                .accessibilityIdentifier("personalization.context")
            } footer: {
                Text("personalization.intro").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            activeSection
            archivedSection
            Section {
                NavigationLink(value: MoreRoute.products) { Text("personalization.products") }
                    .accessibilityIdentifier("personalization.productsLink")
                NavigationLink(value: MoreRoute.recordTemplate) { Text("personalization.fields") }
                    .accessibilityIdentifier("personalization.fieldsLink")
            } header: {
                Text("personalization.elsewhere")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("personalization.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The system Edit button turns on the drag handles; swiping a row archives it.
            ToolbarItem(placement: .secondaryAction) { EditButton().accessibilityIdentifier("personalization.edit") }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: { Image(icon: .plus) }
                    .accessibilityLabel(Text("optionAdd.chip"))
                    .accessibilityIdentifier("personalization.addButton")
            }
        }
        .task { await options.loadIfNeeded() }
        .sheet(isPresented: $isAdding) {
            OptionAddSheet(title: Text(context.title.localized(in: locale)),
                           existing: options.names(in: context), canSave: false) { name, _ in
                perform { try await options.add(name, to: context) }
            }
        }
        .alert(Text("personalization.rename"), isPresented: isRenaming) {
            TextField(text: $newName) { Text("personalization.rename") }
            Button(role: .cancel) {} label: { Text("common.cancel") }
            Button { rename() } label: { Text("personalization.rename.save") }
        } message: {
            Text("personalization.rename.message")
        }
        .alert(Text("personalization.error.title"), isPresented: hasError) {
            Button(role: .cancel) {} label: { Text("common.close") }
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
        .accessibilityIdentifier("personalization.list")
    }

    // MARK: - Sections

    private var activeSection: some View {
        let active = options.options(in: context)
        return Section {
            if active.isEmpty {
                Text("personalization.empty").font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            ForEach(active) { option in
                row(option)
                    .swipeActions {
                        Button { perform { try await options.setArchived(option.id, true) } } label: {
                            Text("personalization.archive")
                        }
                        .tint(Palette.ink2)
                    }
            }
            .onMove { source, destination in
                perform { try await options.move(in: context, from: source, to: destination) }
            }
        } header: {
            Text(context.title.localized(in: locale))
        }
    }

    @ViewBuilder
    private var archivedSection: some View {
        let archived = options.options(in: context, includingArchived: true).filter(\.isArchived)
        if !archived.isEmpty {
            Section {
                ForEach(archived) { option in
                    HStack {
                        Text(verbatim: option.name).font(Typography.body).foregroundStyle(Palette.ink2)
                        Spacer(minLength: Spacing.sm)
                        Button { perform { try await options.setArchived(option.id, false) } } label: {
                            Text("personalization.restore").font(Typography.metaStrong)
                                .foregroundStyle(Palette.roseText)
                                .frame(minHeight: Spacing.touchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("personalization.restore.\(option.name)")
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("personalization.archived")
            } footer: {
                Text("personalization.archived.footer").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    private func row(_ option: SavedOption) -> some View {
        Button {
            newName = option.name
            renaming = option
        } label: {
            Text(verbatim: option.name)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        }
        .accessibilityHint(Text("personalization.rename.hint"))
        .accessibilityIdentifier("personalization.option.\(option.name)")
    }

    // MARK: - Actions

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var hasError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func rename() {
        guard let option = renaming else { return }
        let name = newName
        perform { try await options.rename(option.id, to: name) }
    }

    /// Runs a change and says plainly when it could not be saved (a duplicate name, an empty one, the vault).
    private func perform(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
            } catch OptionCatalogService.Problem.duplicate(let existing) {
                errorMessage = LocalizedStringResource(
                    "personalization.error.duplicate", defaultValue: "“\(existing)” is already in this list."
                ).resolved(in: locale)
            } catch {
                errorMessage = LocalizedStringResource("personalization.error.save").resolved(in: locale)
            }
        }
    }
}
