//
//  SessionServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("SessionService")
struct SessionServiceTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "test.session.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name) ?? .standard, name)
    }

    @Test("It starts unknown, and restore reads the provider's user")
    func restore() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let user = AuthUser(id: "u1", phoneE164: "+5511987654321")
        let session = SessionService(provider: FakeAuthProvider(user: user), defaults: defaults)
        #expect(session.state == .unknown)

        await session.restore()

        #expect(session.state == .signedIn(user))
        #expect(session.user == user)
    }

    @Test("With no saved user restore says signed out")
    func restoreSignedOut() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let session = SessionService(provider: FakeAuthProvider(), defaults: defaults)
        await session.restore()
        #expect(session.state == .signedOut)
        #expect(session.user == nil)
        #expect(!session.hasCompletedSetup)
    }

    @Test("A request goes to the provider and its error reaches the caller")
    func requestCode() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let provider = FakeAuthProvider()
        let session = SessionService(provider: provider, defaults: defaults)

        try await session.requestCode(phoneE164: "+5511987654321")
        #expect(provider.requestedPhones == ["+5511987654321"])

        provider.requestError = .tooManyAttempts
        await #expect(throws: AuthError.tooManyAttempts) { try await session.requestCode(phoneE164: "+5511987654321") }
    }

    @Test("A right code signs in, a wrong one leaves her signed out")
    func verify() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let provider = FakeAuthProvider()
        let session = SessionService(provider: provider, defaults: defaults)
        await session.restore()
        try await session.requestCode(phoneE164: "+5511987654321")

        provider.verifyError = .invalidCode
        await #expect(throws: AuthError.invalidCode) { try await session.verify(code: "000000") }
        #expect(session.state == .signedOut)

        provider.verifyError = nil
        try await session.verify(code: "123456")
        #expect(session.user?.phoneE164 == "+5511987654321")
    }

    @Test("Finishing the setup is remembered for that user only")
    func setupFlagPerUser() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let first = AuthUser(id: "u1", phoneE164: "+5511987654321")
        let session = SessionService(provider: FakeAuthProvider(user: first), defaults: defaults)
        await session.restore()
        #expect(!session.hasCompletedSetup)

        session.completeSetup()
        #expect(session.hasCompletedSetup)

        // A relaunch for the same user still knows it; another user on the same phone does not.
        let relaunched = SessionService(provider: FakeAuthProvider(user: first), defaults: defaults)
        await relaunched.restore()
        #expect(relaunched.hasCompletedSetup)
        let other = SessionService(
            provider: FakeAuthProvider(user: AuthUser(id: "u2", phoneE164: "+351912345678")), defaults: defaults
        )
        await other.restore()
        #expect(!other.hasCompletedSetup)
    }

    @Test("Sign-out clears the user and the setup flag from memory")
    func signOut() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let provider = FakeAuthProvider(user: AuthUser(id: "u1", phoneE164: "+5511987654321"))
        let session = SessionService(provider: provider, defaults: defaults)
        await session.restore()
        session.completeSetup()

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(!session.hasCompletedSetup)
        #expect(provider.didSignOut)
    }

    @Test("Completing the setup while signed out does nothing")
    func completeWhileSignedOut() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let session = SessionService(provider: FakeAuthProvider(), defaults: defaults)
        await session.restore()
        session.completeSetup()
        #expect(!session.hasCompletedSetup)
        #expect(defaults.string(forKey: DefaultsKey.setupCompletedUserID) == nil)
    }
}

@Suite("LocalDevAuthProvider")
struct LocalDevAuthProviderTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "test.localdev.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name) ?? .standard, name)
    }

    @Test("Only the fixed code signs in, and the user survives a relaunch")
    func signIn() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let provider = LocalDevAuthProvider(defaults: defaults)
        #expect(await provider.currentUser() == nil)

        try await provider.requestCode(phoneE164: "+5511987654321")
        await #expect(throws: AuthError.invalidCode) { try await provider.verify(code: "654321") }
        let user = try await provider.verify(code: LocalDevAuthProvider.fixedCode)

        #expect(user.phoneE164 == "+5511987654321")
        #expect(await LocalDevAuthProvider(defaults: defaults).currentUser() == user)
        try await provider.signOut()
        #expect(await LocalDevAuthProvider(defaults: defaults).currentUser() == nil)
    }

    @Test("A code with no request first, or a bad number, is refused")
    func refusals() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let provider = LocalDevAuthProvider(defaults: defaults)
        await #expect(throws: AuthError.invalidCode) { try await provider.verify(code: LocalDevAuthProvider.fixedCode) }
        await #expect(throws: AuthError.invalidPhone) { try await provider.requestCode(phoneE164: "123") }
    }
}
