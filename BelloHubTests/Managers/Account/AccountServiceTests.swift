//
//  AccountServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The deletion cascade (7.1): server first, then the vault, the seed and the account's settings; never before the
/// explicit confirmation, never when the server refused.
@MainActor
@Suite("AccountService")
struct AccountServiceTests {
    private struct World {
        let repository: any ClientRecordRepository
        let keyStore: InMemoryKeyStore
        let keyManager: KeyManager
        let defaults: UserDefaults
        let suite: String
        let service: AccountService
    }

    private func makeWorld(deleter: any AccountDeleting) async throws -> World {
        let suite = "account-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository()
        let keyStore = InMemoryKeyStore()
        let keyManager = KeyManager(store: keyStore)
        try keyManager.prepare(createIfMissing: true)
        _ = try await repository.save(makeClient(name: "Ana Costa"))
        defaults.set("dev-1", forKey: DefaultsKey.setupCompletedUserID)
        defaults.set(Date(), forKey: DefaultsKey.recoveryKeySavedAt)
        defaults.set(60, forKey: DefaultsKey.lockGraceSeconds)
        let service = AccountService(
            vault: VaultService(repository: repository), keyManager: keyManager, keyStore: keyStore,
            deleter: deleter, defaults: defaults
        )
        return World(
            repository: repository, keyStore: keyStore, keyManager: keyManager, defaults: defaults, suite: suite,
            service: service
        )
    }

    @Test("Without the confirmation nothing happens, not even the server call")
    func needsConfirmation() async throws {
        let deleter = FakeAccountDeleter()
        let world = try await makeWorld(deleter: deleter)
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        let outcome = await world.service.deleteAccount(AccountDeletionRequest(userID: "u1"), confirmed: false)

        #expect(outcome == nil)
        #expect(deleter.requests.isEmpty)
        #expect(try await world.repository.allClients().count == 1)
        #expect(try world.keyStore.loadSeed() != nil)
    }

    @Test("After the confirmation the server is asked with the Apple code, then the vault, seed and settings go")
    func cascade() async throws {
        let deleter = FakeAccountDeleter(outcome: .deleted)
        let world = try await makeWorld(deleter: deleter)
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        let request = AccountDeletionRequest(userID: "u1", appleAuthorizationCode: "c_fresh")
        let outcome = await world.service.deleteAccount(request, confirmed: true)

        #expect(outcome == .deleted)
        #expect(deleter.requests == [request], "the fresh code travels with the request")
        #expect(try await world.repository.allClients().isEmpty)
        #expect(try await world.repository.registrationLedger().isEmpty, "the ledger goes with the account")
        #expect(try world.keyStore.loadSeed() == nil)
        #expect(world.keyManager.status != .unlocked)
        #expect(world.defaults.object(forKey: DefaultsKey.setupCompletedUserID) == nil)
        #expect(world.defaults.object(forKey: DefaultsKey.recoveryKeySavedAt) == nil)
        #expect(world.defaults.integer(forKey: DefaultsKey.lockGraceSeconds) == 60, "device settings stay")
        #expect(world.service.errorMessage == nil)
    }

    @Test("A server refusal leaves the iPhone untouched and explains")
    func serverRefused() async throws {
        let world = try await makeWorld(deleter: FakeAccountDeleter(error: FakeServerError()))
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        let outcome = await world.service.deleteAccount(AccountDeletionRequest(userID: "u1"), confirmed: true)

        #expect(outcome == nil)
        #expect(world.service.errorMessage != nil)
        #expect(try await world.repository.allClients().count == 1)
        #expect(try world.keyStore.loadSeed() != nil)
        #expect(world.defaults.string(forKey: DefaultsKey.setupCompletedUserID) == "dev-1")
    }

    @Test("A DEBUG launch with no server (UI tests) says only this iPhone was cleared")
    func offlineDefault() async throws {
        let world = try await makeWorld(deleter: OfflineAccountDeleter())
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        let outcome = await world.service.deleteAccount(AccountDeletionRequest(userID: "u1"), confirmed: true)

        #expect(outcome == .deviceOnly)
        #expect(try await world.repository.allClients().isEmpty)
    }
}
