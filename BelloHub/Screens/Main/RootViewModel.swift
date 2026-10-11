//
//  RootViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// Walks the app through its stages: reads the saved session, decides when the lock applies and loads her profile
/// once the vault is open. `RootView` stays a thin switch over `stage`.
@MainActor
@Observable
final class RootViewModel {
    private(set) var signInMode: SignInMode?

    private let session: SessionService
    private let appLock: AppLockService
    private let keyManager: KeyManager
    private let profile: ProfileService

    init(session: SessionService, appLock: AppLockService, keyManager: KeyManager, profile: ProfileService) {
        self.session = session
        self.appLock = appLock
        self.keyManager = keyManager
        self.profile = profile
    }

    var stage: RootStage {
        RootGate.stage(
            sessionState: session.state, hasCompletedSetup: session.hasCompletedSetup,
            isLocked: appLock.isLocked, signInMode: signInMode
        )
    }

    // MARK: - Launch

    /// Reads the saved session. A set-up workspace starts locked; a new one waits for the onboarding.
    func start() async {
        await session.restore()
        guard session.user != nil else { return }
        if session.hasCompletedSetup {
            appLock.prepareForLaunch()
            if !appLock.isLocked { await profile.load() }
        }
    }

    // MARK: - Welcome and sign-in

    func choose(_ mode: SignInMode) {
        signInMode = mode
    }

    func backToWelcome() {
        signInMode = nil
    }

    /// The code was accepted. A returning professional goes into her workspace; a new one gets a vault key first, and
    /// then the onboarding.
    func didSignIn() async {
        signInMode = nil
        if session.hasCompletedSetup {
            appLock.openAfterSignIn()
            await profile.load()
        } else {
            // A phone that has never had a key creates one now. A phone that lost its key must restore it instead
            // (S10): `createIfMissing` is only safe because no record can exist yet on a first sign-in.
            try? keyManager.prepare(createIfMissing: true)
        }
    }

    // MARK: - Setup and lock

    func didFinishSetup() {
        session.completeSetup()
    }

    /// The Locked screen opened the vault.
    func didUnlock() async {
        await profile.load()
    }

    func signOut() async {
        keyManager.lock()
        profile.clear()
        await session.signOut()
        signInMode = nil
    }
}
