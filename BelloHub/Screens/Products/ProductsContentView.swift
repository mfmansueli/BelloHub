//
//  ProductsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 6.4: a native `List`; tap a product to change it, tap its chip to share it with clients or keep it
/// private, swipe to delete. Under the list, one line says what each chip means.
struct ProductsContentView: View {
    @State private var viewModel: ProductsViewModel
    @State private var editor: ProductEditorMode?
    @State private var pendingDeletion: Product?
    @Environment(\.locale) private var locale

    init(repository: (any CatalogRepository)?) {
        _viewModel = State(initialValue: ProductsViewModel(repository: repository))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("products.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { editor = .add } label: { Image(icon: .plus) }
                        .accessibilityLabel(Text("products.new"))
                        .accessibilityIdentifier("products.addButton")
                }
            }
            .task { await viewModel.loadAsync() }
            .sheet(item: $editor) { mode in
                ProductEditorSheet(mode: mode, viewModel: viewModel)
            }
            .deletionDialog(
                $pendingDeletion,
                title: { product in
                    Text(LocalizedStringResource(
                        "products.delete.title", defaultValue: "Delete “\(product.name)”?"
                    ).localized(in: locale))
                },
                message: { _ in Text("products.delete.message") },
                confirm: DeletionConfirm(title: "products.delete.confirm", identifier: "products.deleteConfirmButton"),
                onConfirm: { product in Task { await viewModel.delete(product) } }
            )
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.showsEmptyState {
            EmptyState(
                icon: .box, title: "products.empty.title", message: "products.empty.message",
                actionTitle: "products.new", action: { editor = .add }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("products.empty")
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                Text("products.subtitle")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            }
            notices
            productsSection
            Section {
                FooterNote(text: "products.footer", icon: .info)
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
                ErrorNotice(message: message, actionTitle: "products.retry", action: viewModel.load)
                    .accessibilityIdentifier("products.error")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        if let message = viewModel.saveErrorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "products.dismiss", action: viewModel.dismissSaveError)
                    .accessibilityIdentifier("products.saveError")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    private var productsSection: some View {
        Section {
            if viewModel.showsSkeleton {
                ForEach(0..<3, id: \.self) { _ in Skeleton(height: 56).listRowBackground(Palette.surface) }
            }
            ForEach(viewModel.products) { product in
                ProductRow(
                    product: product, onEdit: { editor = .edit(product) },
                    onToggleShared: { viewModel.setShared($0, for: product) }
                )
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { pendingDeletion = product } label: { Text("products.delete.action") }
                        .accessibilityIdentifier("products.deleteAction.\(product.id.uuidString)")
                }
            }
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
                Text("products.new").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
        .accessibilityIdentifier("products.newButton")
    }
}
