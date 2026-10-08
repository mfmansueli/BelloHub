//
//  RootGateTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("RootGate")
struct RootGateTests {
    private let user = AuthUser(id: "u1", phoneE164: "+5511987654321")

    private func stage(
        _ state: SessionService.State, setup: Bool = false, locked: Bool = false, mode: SignInMode? = nil
    ) -> RootStage {
        RootGate.stage(sessionState: state, hasCompletedSetup: setup, isLocked: locked, signInMode: mode)
    }

    @Test("Before the saved session is read the app is loading")
    func loading() {
        #expect(stage(.unknown, setup: true, locked: true) == .loading)
    }

    @Test("Signed out shows the welcome, or the sign-in she chose")
    func signedOut() {
        #expect(stage(.signedOut) == .welcome)
        #expect(stage(.signedOut, mode: .create) == .signIn(.create))
        #expect(stage(.signedOut, mode: .existing) == .signIn(.existing))
    }

    @Test("Signed in without a finished setup goes to the onboarding, even if locked")
    func setup() {
        #expect(stage(.signedIn(user)) == .setup)
        #expect(stage(.signedIn(user), locked: true) == .setup)
    }

    @Test("A set-up workspace is locked or open")
    func lockedOrApp() {
        #expect(stage(.signedIn(user), setup: true, locked: true) == .locked)
        #expect(stage(.signedIn(user), setup: true, locked: false) == .app)
    }

    @Test("A sign-in choice never overrides a signed-in session")
    func signedInIgnoresChoice() {
        #expect(stage(.signedIn(user), setup: true, mode: .create) == .app)
    }
}
