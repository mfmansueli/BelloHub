//
//  AuthProvider.swift
//  BelloHub
//

/// Phone sign-in of the professional (docs/04-ARCHITECTURE.md section 3). The real implementation talks to Firebase
/// Auth; `SessionService` is the only caller, so no screen reads an SDK for the user (CLAUDE.md section 9, point 2).
protocol AuthProvider: Sendable {
    /// The user the provider already holds from a previous launch, if any.
    func currentUser() async -> AuthUser?
    /// Sends the six-digit code to `phoneE164`.
    func requestCode(phoneE164: String) async throws
    /// Checks the code of the last request and signs in.
    func verify(code: String) async throws -> AuthUser
    func signOut() async throws
}
