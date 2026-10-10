//
//  RemoteAccountDeleterTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The server half of deleting her account (`deleteAccount`, API.md section 6.7): the request matches the server's
/// own schema, the Apple answer becomes the right last screen, and every failure is thrown so the iPhone stays as it
/// was.
@Suite("RemoteAccountDeleter")
struct RemoteAccountDeleterTests {
    private func make() -> (RemoteAccountDeleter, FakeCallableClient) {
        let client = FakeCallableClient()
        return (RemoteAccountDeleter(client: client), client)
    }

    @Test("A phone account sends only the confirmation, valid against the server contract")
    func phoneAccountRequest() async throws {
        let (deleter, client) = make()
        client.answer("deleteAccount", with: #"{"ok":true,"appleRevocation":"skipped"}"#)

        let outcome = try await deleter.deleteAccount(AccountDeletionRequest(userID: "u1"))

        #expect(outcome == .deleted, "nothing to revoke for a phone account")
        #expect(client.calls.map(\.function) == ["deleteAccount"])
        let body = try #require(client.calls.first)
        #expect(body.object["confirm"] as? Bool == true)
        #expect(body.object["appleAuthorizationCode"] == nil, "a missing code is left out, never sent as null")
        #expect(try ServerContract.violations(of: body.body, for: "deleteAccount").isEmpty)
    }

    @Test("An Apple account sends the fresh authorization code")
    func appleAccountRequest() async throws {
        let (deleter, client) = make()
        client.answer("deleteAccount", with: #"{"ok":true,"appleRevocation":"revoked"}"#)

        let outcome = try await deleter.deleteAccount(
            AccountDeletionRequest(userID: "u1", appleAuthorizationCode: "c0de-from-apple")
        )

        #expect(outcome == .deleted)
        let body = try #require(client.calls.first)
        #expect(body.object["appleAuthorizationCode"] as? String == "c0de-from-apple")
        #expect(try ServerContract.violations(of: body.body, for: "deleteAccount").isEmpty)
    }

    @Test("An empty Apple code is treated as no code")
    func emptyCode() async throws {
        let (deleter, client) = make()
        client.answer("deleteAccount", with: #"{"ok":true,"appleRevocation":"skipped"}"#)

        _ = try await deleter.deleteAccount(AccountDeletionRequest(userID: "u1", appleAuthorizationCode: ""))

        #expect(client.calls.first?.object["appleAuthorizationCode"] == nil)
    }

    @Test("The Apple revocation answer decides the last screen", arguments: [
        ("revoked", true, AccountDeletionOutcome.deleted),
        ("failed", true, .deletedWithoutAppleRevocation),
        ("skipped", true, .deletedWithoutAppleRevocation),
        ("skipped", false, .deleted),
        ("failed", false, .deletedWithoutAppleRevocation)
    ])
    func revocationOutcome(answer: String, sentCode: Bool, expected: AccountDeletionOutcome) {
        #expect(RemoteAccountDeleter.outcome(appleRevocation: answer, sentAppleCode: sentCode) == expected)
    }

    @Test("Offline, refused or unreadable answers are thrown, so nothing on the iPhone is touched", arguments: [
        ServerError.network, .unavailable, .unauthenticated, .rateLimited(retryAfterSeconds: 60)
    ])
    func failuresThrow(error: ServerError) async {
        let (deleter, client) = make()
        client.fail("deleteAccount", with: error)

        await #expect(throws: ServerError.self) {
            try await deleter.deleteAccount(AccountDeletionRequest(userID: "u1"))
        }
    }

    @Test("An answer that is not the contract's is an error, not a deletion")
    func unreadableAnswer() async {
        let (deleter, client) = make()
        client.answer("deleteAccount", with: #"{"done":true}"#)

        await #expect(throws: ServerError.unexpected(code: "DECODE")) {
            try await deleter.deleteAccount(AccountDeletionRequest(userID: "u1"))
        }
    }

    @Test("Through AccountService: a server failure leaves the vault and the seed in place")
    @MainActor
    func serviceKeepsDeviceOnFailure() async throws {
        let client = FakeCallableClient()
        client.fail("deleteAccount", with: .network)
        let repository = InMemoryClientRecordRepository()
        _ = try await repository.save(makeClient())
        let keyStore = InMemoryKeyStore()
        let keyManager = KeyManager(store: keyStore)
        try keyManager.prepare(createIfMissing: true)
        let suite = "remote-deleter-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = AccountService(
            vault: VaultService(repository: repository), keyManager: keyManager, keyStore: keyStore,
            deleter: RemoteAccountDeleter(client: client), defaults: defaults
        )

        let outcome = await service.deleteAccount(AccountDeletionRequest(userID: "u1"), confirmed: true)

        #expect(outcome == nil)
        #expect(service.errorMessage != nil)
        #expect(try await repository.allClients().count == 1)
        #expect(try keyStore.loadSeed() != nil)
    }
}
