//
//  InMemoryClientRecordRepository+Catalog.swift
//  BelloHub
//

#if DEBUG
import Foundation

extension InMemoryClientRecordRepository {
    func save(_ services: [Service]) {
        services.forEach { servicesByID[$0.id] = $0 }
        changes.notify()
    }

    // MARK: - Add-ons

    func addOns() -> [AddOn] {
        addOnsByID.values.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ addOn: AddOn) {
        addOnsByID[addOn.id] = addOn
        changes.notify()
    }

    func save(_ addOns: [AddOn]) {
        addOns.forEach { addOnsByID[$0.id] = $0 }
        changes.notify()
    }

    func deleteAddOn(id: UUID) {
        addOnsByID[id] = nil
        changes.notify()
    }

    // MARK: - Products

    func products() -> [Product] {
        productsByID.values.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ product: Product) {
        productsByID[product.id] = product
        changes.notify()
    }

    func save(_ products: [Product]) {
        products.forEach { productsByID[$0.id] = $0 }
        changes.notify()
    }

    func deleteProduct(id: UUID) {
        productsByID[id] = nil
        changes.notify()
    }

    // MARK: - Credentials

    func credentials() -> [Credential] {
        credentialsByID.values.sorted { ($0.position, $0.title) < ($1.position, $1.title) }
    }

    func save(_ credential: Credential) {
        credentialsByID[credential.id] = credential
        changes.notify()
    }

    func save(_ credentials: [Credential]) {
        credentials.forEach { credentialsByID[$0.id] = $0 }
        changes.notify()
    }

    func deleteCredential(id: UUID) {
        credentialsByID[id] = nil
        changes.notify()
    }
}
#endif
