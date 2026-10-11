//
//  ProductsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Products screen (6.4): the list, add, edit, delete and the switch that shares a product
/// with clients. Every change is written to the vault first and shown after it confirms (CLAUDE.md section 2); a failed
/// write leaves the list as it was and says so.
@MainActor
@Observable
final class ProductsViewModel {
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The list could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it above the list and the list stays as it was.
    private(set) var saveErrorMessage: String?

    private let repository: (any CatalogRepository)?
    private let makeID: @Sendable () -> UUID

    init(repository: (any CatalogRepository)?, makeID: @escaping @Sendable () -> UUID = { UUID() }) {
        self.repository = repository
        self.makeID = makeID
    }

    // MARK: - Reading

    /// Whether the list is empty and nothing is wrong: the screen shows its empty state with the next action.
    var showsEmptyState: Bool { hasLoaded && errorMessage == nil && products.isEmpty }

    /// Whether to draw placeholder rows: the first read is running and there is nothing to show yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded && products.isEmpty }

    func draft(for product: Product?) -> ProductDraft {
        product.map(ProductDraft.init) ?? ProductDraft()
    }

    func issues(in draft: ProductDraft, editing id: UUID?) -> [ProductFormIssue] {
        ProductRules.issues(in: draft, among: products, editing: id)
    }

    // MARK: - Loading

    /// Entry point for appearing and retrying; `loadAsync()` is what `.refreshable` awaits.
    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        guard let repository else {
            errorMessage = Self.loadFailure
            return
        }
        do {
            products = ProductRules.ordered(try await repository.products())
        } catch {
            errorMessage = Self.loadFailure
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    /// Adds a product, or applies the draft to the one being edited. Returns whether it was saved; a draft with an
    /// issue returns false without touching anything (the form shows why while she types).
    @discardableResult
    func save(_ draft: ProductDraft, editing product: Product?) async -> Bool {
        guard let repository,
              let built = ProductRules.build(draft, among: products, editing: product, makeID: makeID)
        else { return false }
        saveErrorMessage = nil
        do {
            try await repository.save(built)
            products = ProductRules.ordered(products.filter { $0.id != built.id } + [built])
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Deletes a product. Treatment records that mention it keep their own words. Returns whether it was deleted.
    @discardableResult
    func delete(_ product: Product) async -> Bool {
        guard let repository else { return false }
        saveErrorMessage = nil
        do {
            try await repository.deleteProduct(id: product.id)
            products.removeAll { $0.id == product.id }
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Entry point for the Shared/Private chip; `setSharedAsync` is what tests await.
    func setShared(_ isShared: Bool, for product: Product) {
        Task { await setSharedAsync(isShared, for: product) }
    }

    func setSharedAsync(_ isShared: Bool, for product: Product) async {
        guard let repository, product.sharedWithClient != isShared else { return }
        let changed = ProductRules.setting(product, shared: isShared)
        saveErrorMessage = nil
        do {
            try await repository.save(changed)
            products = ProductRules.ordered(products.filter { $0.id != changed.id } + [changed])
        } catch {
            saveErrorMessage = Self.saveFailure
        }
    }

    // MARK: - Messages

    private static var loadFailure: String {
        String(interface: LocalizedStringResource(
            "products.error.load",
            defaultValue: "We could not read your products. Check that your iPhone is unlocked and try again."
        ))
    }

    private static var saveFailure: String {
        String(interface: LocalizedStringResource(
            "products.error.save",
            defaultValue: "We could not save this change. Check that your iPhone has space and try again."
        ))
    }
}
