//
//  ProductEditorMode.swift
//  BelloHub
//

import Foundation

/// What the product sheet is for: a new product, or one she is changing or deleting. It is the `item` of the sheet, so
/// SwiftUI builds a fresh form for each product.
enum ProductEditorMode: Identifiable, Equatable, Sendable {
    case add
    case edit(Product)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let product): product.id.uuidString
        }
    }

    /// The product being edited, nil when adding.
    var product: Product? {
        if case .edit(let product) = self { return product }
        return nil
    }
}
