//
//  FakeAuthProvider.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// A sign-in provider the test scripts: which errors it throws and which user it returns. Records what it was asked.
final class FakeAuthProvider: AuthProvider, Sendable {
    private struct State {
        var user: AuthUser?
        var requestError: AuthError?
        var verifyError: AuthError?
        var requestedPhones: [String] = []
        var verifiedCodes: [String] = []
        var appleError: AuthError?
        var appleCredentials: [AppleCredential] = []
        var signedOut = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init(user: AuthUser? = nil) {
        state.withLock { $0.user = user }
    }

    var requestError: AuthError? {
        get { state.withLock { $0.requestError } }
        set { state.withLock { $0.requestError = newValue } }
    }

    var verifyError: AuthError? {
        get { state.withLock { $0.verifyError } }
        set { state.withLock { $0.verifyError = newValue } }
    }

    var appleError: AuthError? {
        get { state.withLock { $0.appleError } }
        set { state.withLock { $0.appleError = newValue } }
    }

    var appleCredentials: [AppleCredential] { state.withLock { $0.appleCredentials } }
    var requestedPhones: [String] { state.withLock { $0.requestedPhones } }
    var verifiedCodes: [String] { state.withLock { $0.verifiedCodes } }
    var didSignOut: Bool { state.withLock { $0.signedOut } }

    func currentUser() async -> AuthUser? {
        state.withLock { $0.user }
    }

    func requestCode(phoneE164: String) async throws {
        try state.withLock { state in
            state.requestedPhones.append(phoneE164)
            if let error = state.requestError { throw error }
        }
    }

    func verify(code: String) async throws -> AuthUser {
        try state.withLock { state in
            state.verifiedCodes.append(code)
            if let error = state.verifyError { throw error }
            let user = AuthUser(id: "fake-user", method: .phone, phoneE164: state.requestedPhones.last ?? "+0")
            state.user = user
            return user
        }
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> AuthUser {
        try state.withLock { state in
            state.appleCredentials.append(credential)
            if let error = state.appleError { throw error }
            let user = AuthUser(id: "fake-apple-user", method: .apple, displayName: credential.fullName)
            state.user = user
            return user
        }
    }

    func signOut() async throws {
        state.withLock {
            $0.user = nil
            $0.signedOut = true
        }
    }
}
