//
//  ProductCategory.swift
//  BelloHub
//

import Foundation

/// What kind of product it is, as the prototype's chips offer them. Stored by raw value; a kind written by a newer
/// version reads as `other` instead of failing (`PersistedEnum`).
enum ProductCategory: String, PersistedEnum, Identifiable {
    case cleanser
    case serum
    case moisturizer
    case sunCare
    case other

    var id: String { rawValue }

    static let fallback = ProductCategory.other

    /// The label on the chip and under the product's name.
    var label: LocalizedStringResource {
        switch self {
        case .cleanser: "products.category.cleanser"
        case .serum: "products.category.serum"
        case .moisturizer: "products.category.moisturizer"
        case .sunCare: "products.category.sunCare"
        case .other: "products.category.other"
        }
    }
}
