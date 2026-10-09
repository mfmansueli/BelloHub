//
//  AddOnsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 6.3: a native `List`, where each add-on has its own switch, tapping it opens the form, swiping
/// deletes it and Edit reorders. Under it, the card that shows clients' side of the same list.
struct AddOnsContentView: View {
    @State private var viewModel: AddOnsViewModel
    @State private var editor: AddOnEditorMode?
    @State private var pendingDeletion: AddOn?
    @Environment(\.locale) private var locale
    private let profile: ProfileService

    init(repository: (any CatalogRepository)?, profile: ProfileService, locale: Locale) {
        self.profile = profile
        _viewModel = State(initialValue: AddOnsViewModel(repository: repository, locale: locale))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("addOns.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.addOns.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton().accessibilityIdentifier("addOns.editButton")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { editor = .add } label: { Image(icon: .plus) }
                        .accessibilityLabel(Text("addOns.new"))
                        .accessibilityIdentifier("addOns.addButton")
                }
            }
            .task { await viewModel.loadAsync() }
            .sheet(item: $editor) { mode in
                AddOnEditorSheet(mode: mode, viewModel: viewModel, formatters: formatters)
            }
            .deletionDialog(
                $pendingDeletion,
                title: { addOn in
                    Text(LocalizedStringResource(
                        "addOns.delete.title", defaultValue: "Delete “\(addOn.name)”?"
                    ).localized(in: locale))
                },
                message: { _ in Text("addOns.delete.message") },
                confirm: DeletionConfirm(title: "addOns.delete.confirm", identifier: "addOns.deleteConfirmButton"),
                onConfirm: { addOn in Task { await viewModel.delete(addOn) } }
            )
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.showsEmptyState {
            EmptyState(
                icon: .sparkle, title: "addOns.empty.title", message: "addOns.empty.message",
                actionTitle: "addOns.new", action: { editor = .add }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("addOns.empty")
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                Text("addOns.subtitle")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            }
            notices
            addOnsSection
            Section {
                FooterNote(text: "addOns.footer", icon: .info)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                AddOnsPreviewCard(offered: viewModel.offered, formatters: formatters)
                    .accessibilityIdentifier("addOns.preview")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.loadAsync() }
    }

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "addOns.retry", action: viewModel.load)
                    .accessibilityIdentifier("addOns.error")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        if let message = viewModel.saveErrorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "addOns.dismiss", action: viewModel.dismissSaveError)
                    .accessibilityIdentifier("addOns.saveError")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    private var addOnsSection: some View {
        Section {
            if viewModel.showsSkeleton {
                ForEach(0..<3, id: \.self) { _ in Skeleton(height: 56).listRowBackground(Palette.surface) }
            }
            ForEach(viewModel.addOns) { addOn in
                AddOnRow(
                    addOn: addOn, formatters: formatters, onEdit: { editor = .edit(addOn) },
                    onToggle: { viewModel.setOffered($0, for: addOn) }
                )
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { pendingDeletion = addOn } label: { Text("addOns.delete.action") }
                        .accessibilityIdentifier("addOns.deleteAction.\(addOn.id.uuidString)")
                }
            }
            .onMove { source, destination in viewModel.move(from: source, to: destination) }
            .onDelete { offsets in pendingDeletion = offsets.first.map { viewModel.addOns[$0] } }
            if viewModel.hasLoaded { newRow }
        }
    }

    private var newRow: some View {
        Button { editor = .add } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .plus)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("addOns.new").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
        .accessibilityIdentifier("addOns.newButton")
    }

    private var formatters: Formatters {
        let zone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: zone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }
}
