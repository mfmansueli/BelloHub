//
//  AccountViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("AccountViewModel")
struct AccountViewModelTests {
    private struct World {
        let repository: any ClientRecordRepository
        let keyStore: InMemoryKeyStore
        let deleter: FakeAccountDeleter
        let credentials: FakeAppleCredentialProvider
        let viewModel: AccountViewModel
        let defaults: UserDefaults
        let suite: String
        let signOuts: SignOutCounter
    }

    final class SignOutCounter {
        var count = 0
    }

    private func makeWorld(
        deleter: FakeAccountDeleter = FakeAccountDeleter(),
        method: SignInMethod = .phone,
        credentials: FakeAppleCredentialProvider = FakeAppleCredentialProvider()
    ) async throws -> World {
        let suite = "account-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository()
        try await repository.save(ProfessionalProfile(
            displayName: "Maria Silva", businessName: "Glow", regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", createdAt: TestClock.now
        ))
        _ = try await repository.save(makeClient())
        let profile = ProfileService(repository: repository)
        await profile.load()
        let keyStore = InMemoryKeyStore()
        let keyManager = KeyManager(store: keyStore)
        try keyManager.prepare(createIfMissing: true)
        let account = AccountService(
            vault: VaultService(repository: repository), keyManager: keyManager, keyStore: keyStore,
            deleter: deleter, defaults: defaults
        )
        let user = method == .phone
            ? AuthUser(id: "u1", phoneE164: "+5511987654321")
            : AuthUser(id: "u1", method: .apple, displayName: "Maria Silva")
        let session = SessionService(provider: FakeAuthProvider(user: user), defaults: defaults)
        await session.restore()
        let counter = SignOutCounter()
        let viewModel = AccountViewModel(
            profile: profile, account: account, session: session, credentials: credentials
        ) {
            counter.count += 1
        }
        return World(
            repository: repository, keyStore: keyStore, deleter: deleter, credentials: credentials,
            viewModel: viewModel, defaults: defaults, suite: suite, signOuts: counter
        )
    }

    @Test("The form starts from the stored profile and saves only a valid change")
    func save() async throws {
        let world = try await makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel

        #expect(viewModel.displayName == "Maria Silva")
        #expect(viewModel.phoneE164 == "+5511987654321")
        #expect(!viewModel.canSave, "nothing changed yet")

        viewModel.displayName = "  "
        #expect(viewModel.nameIssue == .empty)
        #expect(!viewModel.canSave)

        viewModel.displayName = " Maria S. "
        #expect(viewModel.canSave)
        await viewModel.saveAsync()

        #expect(viewModel.saved)
        #expect(viewModel.displayName == "Maria S.")
        #expect(try await world.repository.profile()?.displayName == "Maria S.")
        #expect(!viewModel.canSave, "saved means no pending change")
    }

    @Test("Deleting walks export, confirmation, server, wipe, and ends the session only when she leaves")
    func deletion() async throws {
        let world = try await makeWorld(deleter: FakeAccountDeleter(outcome: .deleted))
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel

        viewModel.send(.tappedDelete)
        #expect(viewModel.deletion == .offeringExport)
        #expect(try await world.repository.allClients().count == 1)
        viewModel.send(.proceeded)
        #expect(viewModel.deletion == .confirming)
        #expect(try await world.repository.allClients().count == 1, "the confirmation alone wipes nothing")

        await viewModel.deleteAccountAsync(appleAuthorizationCode: "c_fresh")

        #expect(viewModel.deletion == .done(.deleted))
        #expect(world.deleter.requests.first?.appleAuthorizationCode == "c_fresh")
        #expect(world.deleter.requests.first?.userID == "u1")
        #expect(try await world.repository.allClients().isEmpty)
        #expect(try world.keyStore.loadSeed() == nil)
        #expect(world.signOuts.count < 1, "she reads the done screen first")

        viewModel.leaveAfterDeletion()
        #expect(world.signOuts.count == 1)
    }

    @Test("A failed deletion returns to the confirmation with the message, nothing wiped")
    func deletionFails() async throws {
        let world = try await makeWorld(deleter: FakeAccountDeleter(error: FakeServerError()))
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel

        viewModel.send(.tappedDelete)
        viewModel.send(.proceeded)
        await viewModel.deleteAccountAsync()

        #expect(viewModel.deletion == .confirming)
        #expect(viewModel.deletionErrorMessage != nil)
        #expect(try await world.repository.allClients().count == 1)
        #expect(try world.keyStore.loadSeed() != nil)
    }

    @Test("A phone account deletes with the plain button and never asks Apple")
    func phoneAccountNeedsNoApple() async throws {
        let world = try await makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        #expect(!world.viewModel.requiresAppleReauthorization)
        world.viewModel.send(.tappedDelete)
        world.viewModel.send(.proceeded)
        await world.viewModel.deleteAccountAsync()

        #expect(world.viewModel.deletion == .done(.deleted))
        #expect(world.deleter.requests.first?.appleAuthorizationCode == nil)
        #expect(world.credentials.preparedCount == 0)
    }

    @Test("An Apple account sends the fresh authorization code and is deleted")
    func appleAccountSendsTheFreshCode() async throws {
        let world = try await makeWorld(method: .apple)
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel

        #expect(viewModel.requiresAppleReauthorization)
        viewModel.send(.tappedDelete)
        viewModel.send(.proceeded)
        await viewModel.deleteAfterAppleReauthorization(with: FakeAppleCredentialProvider.sample)

        #expect(viewModel.deletion == .done(.deleted))
        #expect(viewModel.appleErrorMessage == nil)
        #expect(world.deleter.requests.count == 1)
        #expect(world.deleter.requests.first?.appleAuthorizationCode == "code")
        #expect(try await world.repository.allClients().isEmpty)
        #expect(try world.keyStore.loadSeed() == nil)
    }

    @Test("An Apple account without a fresh code never reaches the server and nothing is wiped")
    func appleAccountWithoutCodeIsRefused() async throws {
        let world = try await makeWorld(method: .apple)
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        viewModel.send(.tappedDelete)
        viewModel.send(.proceeded)

        await viewModel.deleteAccountAsync()
        #expect(viewModel.deletion == .confirming)
        #expect(viewModel.appleErrorMessage != nil)

        let noCode = AppleCredential(
            userID: "001.apple", identityToken: "token", rawNonce: "nonce", authorizationCode: nil,
            givenName: nil, familyName: nil, email: nil
        )
        await viewModel.deleteAfterAppleReauthorization(with: noCode)

        #expect(viewModel.deletion == .confirming)
        #expect(viewModel.appleErrorMessage != nil)
        #expect(world.deleter.requests.isEmpty)
        #expect(try await world.repository.allClients().count == 1)
        #expect(try world.keyStore.loadSeed() != nil)
    }

    @Test("Closing the Apple sheet shows nothing; a failure shows the message; a retry clears it")
    func appleSheetCancelledOrFailed() async throws {
        let credentials = FakeAppleCredentialProvider(credential: nil, error: .cancelled)
        let world = try await makeWorld(method: .apple, credentials: credentials)
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        viewModel.send(.tappedDelete)
        viewModel.send(.proceeded)

        await viewModel.completeAppleReauthorizationAsync(.failure(AuthError.cancelled))
        #expect(viewModel.appleErrorMessage == nil)
        #expect(viewModel.deletion == .confirming)

        credentials.error = .appleFailed
        await viewModel.completeAppleReauthorizationAsync(.failure(AuthError.appleFailed))
        #expect(viewModel.appleErrorMessage != nil)
        #expect(world.deleter.requests.isEmpty)

        // The retry: Apple answers with a credential this time (a test cannot build the system's `ASAuthorization`,
        // so the seam below is what `completeAppleReauthorizationAsync` calls after reading one).
        await viewModel.deleteAfterAppleReauthorization(with: FakeAppleCredentialProvider.sample)
        #expect(viewModel.appleErrorMessage == nil, "the message leaves with the retry")
        #expect(viewModel.deletion == .done(.deleted))
        #expect(world.deleter.requests.first?.appleAuthorizationCode == "code")
    }

    @Test("Sign out calls the root's sign-out once")
    func signOut() async throws {
        let world = try await makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        world.viewModel.confirmSignOut()

        #expect(world.signOuts.count == 1)
    }
}
