//
//  CatalogRepository.swift
//  BelloHub
//

import Foundation

/// What she offers beyond the services themselves: add-ons, products and credentials (S5). Services stay in
/// `AgendaRepository` because appointments point at them; only the bulk write that a reorder needs is here.
/// Non-clinical, stored in the clear (docs/05-DATA-MODEL.md section 1).
protocol CatalogRepository: Sendable {
    /// Stores several services **together**: a reorder changes the `position` of many, and a crash must never leave
    /// half of them renumbered. (`AgendaRepository.save(_:)` writes one.)
    func save(_ services: [Service]) async throws

    func addOns() async throws -> [AddOn]
    func save(_ addOn: AddOn) async throws
    func save(_ addOns: [AddOn]) async throws
    func deleteAddOn(id: UUID) async throws

    func products() async throws -> [Product]
    func save(_ product: Product) async throws
    func save(_ products: [Product]) async throws
    func deleteProduct(id: UUID) async throws

    func credentials() async throws -> [Credential]
    func save(_ credential: Credential) async throws
    /// Stores several credentials together: the master "show on my booking page" switch changes all of them at once.
    func save(_ credentials: [Credential]) async throws
    func deleteCredential(id: UUID) async throws
}
