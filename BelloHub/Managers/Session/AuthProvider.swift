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
    func signOut() async throws
}
