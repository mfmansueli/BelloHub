//
//  AppleSignInViewModelTests.swift
//  BelloHubTests
//

import AuthenticationServices
@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("AppleSignInViewModel")
struct AppleSignInViewModelTests {
    @MainActor
    final class Counter {
        var signedIn = 0
    }

    private struct Rig {
        let model: AppleSignInViewModel
        let provider: FakeAuthProvider
        let credentials: FakeAppleCredentialProvider
        let session: SessionService
        let counter: Counter
        let defaults: UserDefaults
        let suite: String
    }

    private func makeRig(credentials: FakeAppleCredentialProvider = FakeAppleCredentialProvider()) -> Rig {
        let suite = "test.apple.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let provider = FakeAuthProvider()
        let session = SessionService(provider: provider, defaults: defaults)
        let counter = Counter()
        let model = AppleSignInViewModel(
            session: session, credentials: credentials, onSignedIn: { counter.signedIn += 1 }
        )
        return Rig(
            model: model, provider: provider, credentials: credentials, session: session, counter: counter,
            defaults: defaults, suite: suite
        )
    }

    private let failure: Result<ASAuthorization, any Error> = .failure(ASAuthorizationError(.failed))

    @Test("Preparing the request clears the last message and reaches the provider")
    func prepare() async {
        let rig = makeRig(credentials: FakeAppleCredentialProvider(credential: nil, error: .appleFailed))
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        await rig.model.completeAsync(failure)
        #expect(rig.model.error == .appleFailed)

        rig.model.prepare(ASAuthorizationAppleIDProvider().createRequest())

        #expect(rig.model.error == nil)
        #expect(rig.credentials.preparedCount == 1)
    }

    @Test("Closing the Apple sheet shows no error and signs nobody in")
    func cancelIsSilent() async {
        let rig = makeRig(credentials: FakeAppleCredentialProvider(error: .cancelled))
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }

        await rig.model.completeAsync(failure)

        #expect(rig.model.error == nil)
        #expect(rig.counter.signedIn == 0)
        #expect(rig.provider.appleCredentials.isEmpty)
        #expect(rig.session.user == nil)
    }

    @Test("A refusal from the backend is shown and signs nobody in")
    func backendRefusal() async {
        let rig = makeRig(credentials: FakeAppleCredentialProvider(error: nil))
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.provider.appleError = .network

        await rig.model.signInAsync(with: FakeAppleCredentialProvider.sample)

        #expect(rig.model.error == .network)
        #expect(rig.counter.signedIn == 0)
        #expect(!rig.model.isWorking)
    }

    @Test("A good credential reaches the session with the name, and the screen is told")
    func goodCredential() async {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }

        await rig.model.signInAsync(with: FakeAppleCredentialProvider.sample)

        #expect(rig.model.error == nil)
        #expect(rig.counter.signedIn == 1)
        #expect(rig.session.user?.method == .apple)
        #expect(rig.session.user?.displayName == "Maria Silva")
        #expect(rig.provider.appleCredentials == [FakeAppleCredentialProvider.sample])
    }
}
