//
//  SwiftDataClientRecordRepository+Catalog.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func save(_ services: [Service]) throws {
        // One context save at the end, so a reorder is a single transaction.
        try services.forEach { try upsert($0) }
        try commit()
    }

    // MARK: - Add-ons

    func addOns() throws -> [AddOn] {
        try values(AddOn.self, from: items(kind: .addOn)).sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ addOn: AddOn) throws {
        try upsert(addOn)
        try commit()
    }

    func save(_ addOns: [AddOn]) throws {
        try addOns.forEach { try upsert($0) }
        try commit()
    }

    func deleteAddOn(id: UUID) throws {
        if let found = try item(kind: .addOn, id: id) { delete([found]) }
        try commit()
    }

    // MARK: - Products

    func products() throws -> [Product] {
        try values(Product.self, from: items(kind: .product)).sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ product: Product) throws {
        try upsert(product)
        try commit()
    }

    func save(_ products: [Product]) throws {
        try products.forEach { try upsert($0) }
        try commit()
    }

    func deleteProduct(id: UUID) throws {
        if let found = try item(kind: .product, id: id) { delete([found]) }
        try commit()
    }

    // MARK: - Credentials

    func credentials() throws -> [Credential] {
        try values(Credential.self, from: items(kind: .credential))
            .sorted { ($0.position, $0.title) < ($1.position, $1.title) }
    }

    func save(_ credential: Credential) throws {
        try upsert(credential)
        try commit()
    }

    func save(_ credentials: [Credential]) throws {
        try credentials.forEach { try upsert($0) }
        try commit()
    }

    func deleteCredential(id: UUID) throws {
        if let found = try item(kind: .credential, id: id) { delete([found]) }
        try commit()
    }
}
