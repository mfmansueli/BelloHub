//
//  ProductRules.swift
//  BelloHub
//

import Foundation

/// The rules of the product list and form that have no UI: which names are accepted, how a draft becomes a `Product`,
/// the order of the list and the share switch. One owner for each rule (CLAUDE.md section 2).
enum ProductRules {
    static let maximumBrandLength = 60
    static let maximumNoteLength = 200

    /// Whether `raw` can be the name of a product. Two products may share a name when their brands differ ("Calming
    /// serum" from two makers), so the name is compared among the products of the same brand. `id` is the product
    /// being edited, whose own name does not count as taken.
    static func nameCheck(
        _ raw: String, brand: String, among products: [Product], editing id: UUID? = nil
    ) -> CatalogNameCheck {
        let brandKey = OnboardingRules.comparisonKey(OnboardingRules.cleaned(brand))
        let sameBrand = products.filter {
            $0.id != id && OnboardingRules.comparisonKey(OnboardingRules.cleaned($0.brand)) == brandKey
        }
        return CatalogNameRules.check(raw, among: sameBrand.map(\.name))
    }

    /// Everything wrong with the draft, in the order the form shows it. Empty means it can be saved.
    static func issues(in draft: ProductDraft, among products: [Product], editing id: UUID? = nil)
        -> [ProductFormIssue] {
        var found: [ProductFormIssue] = []
        switch nameCheck(draft.name, brand: draft.brand, among: products, editing: id) {
        case .accepted: break
        case .empty: found.append(.nameEmpty)
        case .tooLong: found.append(.nameTooLong)
        case .duplicate: found.append(.nameTaken)
        }
        if OnboardingRules.cleaned(draft.brand).count > maximumBrandLength { found.append(.brandTooLong) }
        if draft.note.trimmingCharacters(in: .whitespacesAndNewlines).count > maximumNoteLength {
            found.append(.noteTooLong)
        }
        return found
    }

    /// The product the draft describes, or nil when it has an issue. `existing` keeps its id and place; a new one goes
    /// after the last.
    static func build(
        _ draft: ProductDraft, among products: [Product], editing existing: Product? = nil,
        makeID: () -> UUID = UUID.init
    ) -> Product? {
        guard issues(in: draft, among: products, editing: existing?.id).isEmpty,
              let name = nameCheck(draft.name, brand: draft.brand, among: products, editing: existing?.id).acceptedName
        else { return nil }
        return Product(
            id: existing?.id ?? makeID(), name: name, brand: OnboardingRules.cleaned(draft.brand),
            category: draft.category, note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            sharedWithClient: draft.sharedWithClient,
            position: existing?.position ?? PositionRules.next(after: products)
        )
    }

    /// The list in display order: by position, then by name so equal positions never swap between loads.
    static func ordered(_ products: [Product]) -> [Product] {
        products.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    /// `product` shared with clients or kept private. Nothing else changes.
    static func setting(_ product: Product, shared: Bool) -> Product {
        var changed = product
        changed.sharedWithClient = shared
        return changed
    }

    /// "Cleanser" under the name when there is no brand, "Acme · Cleanser" when there is. The category word comes from
    /// the caller because it is localized.
    static func details(brand: String, category: String) -> String {
        [OnboardingRules.cleaned(brand), category].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
