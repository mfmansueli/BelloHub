//
//  Product.swift
//  BelloHub
//

import Foundation

/// Something she uses or recommends. She picks it in treatment records and chooses whether the client sees it in her
/// own view (`sharedWithClient`, private by default). There is no stock, no sale price and no sale anywhere in the
/// product (docs/05-DATA-MODEL.md, D4).
struct Product: Identifiable, Hashable, Codable, Sendable, Positioned {
    let id: UUID
    var name: String
    var brand: String
    var category: ProductCategory
    /// A line of her own about it ("fragrance-free"); empty when she wrote nothing.
    var note: String
    var sharedWithClient: Bool
    var position: Int

    init(
        id: UUID = UUID(), name: String, brand: String = "", category: ProductCategory = .other, note: String = "",
        sharedWithClient: Bool = false, position: Int = 0
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.note = note
        self.sharedWithClient = sharedWithClient
        self.position = position
    }
}
