//
//  SessionService.swift
//  BelloHub
//

import Foundation
import Observation

/// Owns the current professional. Nothing else reads the auth SDK (CLAUDE.md section 2). Created once at the root of
/// the app session and read through the environment.
@MainActor
@Observable
final class SessionService {
    enum State: Equatable {
        /// Not looked at yet (the first instant of a launch).
        case unknown
        case signedOut
        case signedIn(AuthUser)
    }

    private(set) var state: State = .unknown
    /// Whether the workspace setup finished for the signed-in user on this phone.
    private(set) var hasCompletedSetup = false

    private let provider: any AuthProvider
    private let defaults: UserDefaults

    init(provider: any AuthProvider = AuthProviderFactory.make(), defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
    }

    var user: AuthUser? {
        if case .signedIn(let user) = state { user } else { nil }
    }

    // MARK: - Lifecycle

    /// Reads the user the provider kept from the last launch. Call once, when the app starts.
    func restore() async {
        if let user = await provider.currentUser() {
            state = .signedIn(user)
        } else {
            state = .signedOut
        }
        refreshSetupFlag()
    }

    // MARK: - Sign-in

    /// Sends the six-digit code. Throws `AuthError`.
    func requestCode(phoneE164: String) async throws {
        try await provider.requestCode(phoneE164: phoneE164)
    }

    /// Checks the code and signs in. Throws `AuthError`.
    func verify(code: String) async throws {
        let user = try await provider.verify(code: code)
        state = .signedIn(user)
        refreshSetupFlag()
    }

    func signOut() async {
        try? await provider.signOut()
        state = .signedOut
        hasCompletedSetup = false
    }

    // MARK: - Setup

    /// Records that the setup finished for this user, so a relaunch goes to the lock screen and not to onboarding.
    func completeSetup() {
        guard let user else { return }
        defaults.set(user.id, forKey: DefaultsKey.setupCompletedUserID)
        hasCompletedSetup = true
    }

    private func refreshSetupFlag() {
        guard let user else {
            hasCompletedSetup = false
            return
        }
        hasCompletedSetup = defaults.string(forKey: DefaultsKey.setupCompletedUserID) == user.id
    }
}
