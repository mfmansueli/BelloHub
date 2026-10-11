//
//  ProductDraft.swift
//  BelloHub
//

import Foundation

/// The product form while she edits it. New products start private, as the data model says: nothing reaches a client
/// until she switches it on.
struct ProductDraft: Equatable, Sendable {
    var name = ""
    var brand = ""
    var category = ProductCategory.serum
    var note = ""
    var sharedWithClient = false

    init() {}

    init(_ product: Product) {
        name = product.name
        brand = product.brand
        category = product.category
        note = product.note
        sharedWithClient = product.sharedWithClient
    }
}
