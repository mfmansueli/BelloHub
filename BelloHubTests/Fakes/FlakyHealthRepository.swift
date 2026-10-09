//
//  FlakyHealthRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A health repository that behaves like the in-memory vault until a test tells it to fail a kind of write, so the
/// error paths of the health ViewModels are tested without a broken store.
actor FlakyHealthRepository: HealthRepository {
    struct Failure: Error {}

    /// Which writes fail. Reads and everything else go to the vault.
    struct Failing: OptionSet, Sendable {
        let rawValue: Int
        static let consent = Failing(rawValue: 1)
        static let form = Failing(rawValue: 2)
        static let template = Failing(rawValue: 4)
        static let patchTest = Failing(rawValue: 8)
        static let reads = Failing(rawValue: 16)
    }

    let vault = InMemoryClientRecordRepository()
    private var failing: Failing = []
    private(set) var savedConsents = 0
    private(set) var savedForms = 0

    func fail(_ failing: Failing) {
        self.failing = failing
    }

    private func readOrFail() throws {
        if failing.contains(.reads) { throw Failure() }
    }

    // MARK: - ClientRepository

    nonisolated func clients() -> AsyncStream<[Client]> { vault.clients() }

    func allClients() async throws -> [Client] {
        try readOrFail()
        return await vault.allClients()
    }

    func client(id: UUID) async throws -> Client? {
        try readOrFail()
        return await vault.client(id: id)
    }

    @discardableResult
    func save(_ client: Client) async throws -> Bool { await vault.save(client) }

    func deleteClient(id: UUID) async throws { await vault.deleteClient(id: id) }

    func mergeClient(keeping keptID: UUID, merging mergedID: UUID) async throws -> Client {
        try await vault.mergeClient(keeping: keptID, merging: mergedID)
    }

    func registrationLedger() async throws -> [RegistrationLedgerEntry] { await vault.registrationLedger() }

    func healthForms(for clientID: UUID) async throws -> [HealthForm] {
        try readOrFail()
        return await vault.healthForms(for: clientID)
    }

    func save(_ form: HealthForm) async throws {
        if failing.contains(.form) { throw Failure() }
        savedForms += 1
        await vault.save(form)
    }

    func importHealthForm(_ form: HealthForm) async throws -> Bool { await vault.importHealthForm(form) }

    func consents(for clientID: UUID) async throws -> [Consent] {
        try readOrFail()
        return await vault.consents(for: clientID)
    }

    func save(_ consent: Consent) async throws {
        if failing.contains(.consent) { throw Failure() }
        savedConsents += 1
        await vault.save(consent)
    }

    func sessionPlans(for clientID: UUID) async throws -> [SessionPlan] { await vault.sessionPlans(for: clientID) }

    func save(_ plan: SessionPlan) async throws { await vault.save(plan) }

    // MARK: - FormTemplateRepository

    func healthFormTemplates() async throws -> [HealthFormTemplate] {
        try readOrFail()
        return await vault.healthFormTemplates()
    }

    func save(_ template: HealthFormTemplate) async throws {
        if failing.contains(.template) { throw Failure() }
        try await vault.save(template)
    }

    func patchTests(for clientID: UUID) async throws -> [PatchTest] {
        try readOrFail()
        return await vault.patchTests(for: clientID)
    }

    func save(_ patchTest: PatchTest) async throws {
        if failing.contains(.patchTest) { throw Failure() }
        await vault.save(patchTest)
    }
}
