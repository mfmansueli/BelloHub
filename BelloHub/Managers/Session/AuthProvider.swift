//
//  AuthProvider.swift
//  BelloHub
//

/// Sign-in of the professional: Apple first, the phone code as the alternative (docs/04-ARCHITECTURE.md section 3).
/// The real implementation talks to Firebase Auth; `SessionService` is the only caller, so no screen reads an SDK
/// for the user (CLAUDE.md section 9, point 2).
protocol AuthProvider: Sendable {
    /// The user the provider already holds from a previous launch, if any.
    func currentUser() async -> AuthUser?
    /// Sends the six-digit code to `phoneE164`.
    func requestCode(phoneE164: String) async throws
    /// Checks the code of the last request and signs in.
    func verify(code: String) async throws -> AuthUser
    /// Signs in with what Apple returned. Throws `AuthError`.
    func signInWithApple(_ credential: AppleCredential) async throws -> AuthUser
    /// The Firebase ID token of the signed-in user, refreshed by the SDK when it is about to expire. Throws `AuthError`
    /// (`unavailable` when nobody is signed in or this build cannot sign in, `network` offline).
    func idToken() async throws -> String
    func signOut() async throws
}
