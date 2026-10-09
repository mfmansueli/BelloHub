//
//  AppleCredentialProviding.swift
//  BelloHub
//

import AuthenticationServices

/// The two halves of the native Sign in with Apple button: it asks us to fill the request, then hands back the result.
/// A protocol so the ViewModel is tested with a fake and no sheet is ever shown in a test.
@MainActor
protocol AppleCredentialProviding {
    /// Fills the request the button is about to show: scopes (name and e-mail) and a fresh hashed nonce.
    func prepare(_ request: ASAuthorizationAppleIDRequest)
    /// Turns the button's result into a credential. A cancel by the user throws `AuthError.cancelled`.
    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleCredential
}
