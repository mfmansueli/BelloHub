//
//  FakeCatalogRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The services and the catalog (add-ons, products, credentials) in memory, for tests of the ViewModels of the business
/// screens. Unlike the real repositories it can be told to fail reads or writes, which is how the error paths are
/// tested; the contract tests cover the real behavior against both vaults. It has no appointments.
actor FakeCatalogRepository: AgendaRepository, CatalogRepository {
    struct Failure: Error, Equatable {}

    private var servicesByID: [UUID: Service] = [:]
    private var addOnsByID: [UUID: AddOn] = [:]
    private var productsByID: [UUID: Product] = [:]
    private var credentialsByID: [UUID: Credential] = [:]
    private var failsReads = false
    private var failsWrites = false
    private(set) var writeCount = 0
    /// How many times a bulk write ran (a reorder or the page switch), to show a drag is one write.
    private(set) var bulkWriteCount = 0

    /// While true, every read throws `Failure`.
    func setFailsReads(_ value: Bool) { failsReads = value }

    /// While true, every write throws `Failure` and changes nothing.
    func setFailsWrites(_ value: Bool) { failsWrites = value }

    /// Puts values in as if they were already stored, without counting a write.
    func seed(
        services: [Service] = [], addOns: [AddOn] = [], products: [Product] = [], credentials: [Credential] = []
    ) {
        services.forEach { servicesByID[$0.id] = $0 }
        addOns.forEach { addOnsByID[$0.id] = $0 }
        products.forEach { productsByID[$0.id] = $0 }
        credentials.forEach { credentialsByID[$0.id] = $0 }
    }

    func storedServices() -> [Service] { servicesByID.values.sorted { $0.position < $1.position } }
    func storedAddOns() -> [AddOn] { addOnsByID.values.sorted { $0.position < $1.position } }
    func storedProducts() -> [Product] { productsByID.values.sorted { $0.position < $1.position } }
    func storedCredentials() -> [Credential] { credentialsByID.values.sorted { $0.position < $1.position } }

    private func readOrFail() throws {
        if failsReads { throw Failure() }
    }

    private func beginWrite(bulk: Bool = false) throws {
        if failsWrites { throw Failure() }
        writeCount += 1
        if bulk { bulkWriteCount += 1 }
    }

    // MARK: - AgendaRepository

    nonisolated func appointments(in range: DateInterval) -> AsyncStream<[Appointment]> {
        AsyncStream { $0.finish() }
    }

    func loadAppointments(in range: DateInterval) -> [Appointment] { [] }
    func appointments(for clientID: UUID) -> [Appointment] { [] }
    func appointment(id: UUID) -> Appointment? { nil }
    func save(_ appointment: Appointment) throws { try beginWrite() }
    func deleteAppointment(id: UUID) throws { try beginWrite() }

    func services() throws -> [Service] {
        try readOrFail()
        return storedServices()
    }

    func save(_ service: Service) throws {
        try beginWrite()
        servicesByID[service.id] = service
    }

    func deleteService(id: UUID) throws {
        try beginWrite()
        servicesByID[id] = nil
    }

    // MARK: - CatalogRepository

    func save(_ services: [Service]) throws {
        try beginWrite(bulk: true)
        services.forEach { servicesByID[$0.id] = $0 }
    }

    func addOns() throws -> [AddOn] {
        try readOrFail()
        return storedAddOns()
    }

    func save(_ addOn: AddOn) throws {
        try beginWrite()
        addOnsByID[addOn.id] = addOn
    }

    func save(_ addOns: [AddOn]) throws {
        try beginWrite(bulk: true)
        addOns.forEach { addOnsByID[$0.id] = $0 }
    }

    func deleteAddOn(id: UUID) throws {
        try beginWrite()
        addOnsByID[id] = nil
    }

    func products() throws -> [Product] {
        try readOrFail()
        return storedProducts()
    }

    func save(_ product: Product) throws {
        try beginWrite()
        productsByID[product.id] = product
    }

    func save(_ products: [Product]) throws {
        try beginWrite(bulk: true)
        products.forEach { productsByID[$0.id] = $0 }
    }

    func deleteProduct(id: UUID) throws {
        try beginWrite()
        productsByID[id] = nil
    }

    func credentials() throws -> [Credential] {
        try readOrFail()
        return storedCredentials()
    }

    func save(_ credential: Credential) throws {
        try beginWrite()
        credentialsByID[credential.id] = credential
    }

    func save(_ credentials: [Credential]) throws {
        try beginWrite(bulk: true)
        credentials.forEach { credentialsByID[$0.id] = $0 }
    }

    func deleteCredential(id: UUID) throws {
        try beginWrite()
        credentialsByID[id] = nil
    }
}
