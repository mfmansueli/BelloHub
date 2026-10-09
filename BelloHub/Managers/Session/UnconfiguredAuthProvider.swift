//
//  UnconfiguredAuthProvider.swift
//  BelloHub
//

/// What Release builds use until the Firebase provider exists (S8): every call says sign-in is unavailable, so a
/// Release build can never sign in with a development shortcut. Replaced by `FirebaseAuthProvider` in S8.
struct UnconfiguredAuthProvider: AuthProvider {
    func currentUser() async -> AuthUser? { nil }

    func requestCode(phoneE164: String) async throws {
        throw AuthError.unavailable
    }

    func verify(code: String) async throws -> AuthUser {
        throw AuthError.unavailable
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> AuthUser {
        throw AuthError.unavailable
    }

    func signOut() async throws {}
}
