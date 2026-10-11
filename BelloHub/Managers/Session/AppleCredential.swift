//
//  AppleCredential.swift
//  BelloHub
//

import Foundation

/// What Apple handed back after the professional approved the sign-in, without any framework type, so the rest of the
/// app and the tests never touch `AuthenticationServices`.
struct AppleCredential: Equatable, Sendable {
    /// Apple's stable id for her in this app.
    let userID: String
    /// The signed JWT the auth backend verifies.
    let identityToken: String
    /// The unhashed nonce whose SHA-256 went into the request; the backend checks it against the token.
    let rawNonce: String
    /// Single-use code that account deletion (S10) exchanges to revoke the Apple token. It is not stored anywhere
    /// now: a code kept from sign-in would expire long before she deletes the account.
    let authorizationCode: String?
    /// Apple sends the name and the e-mail only on the very first authorization of this app.
    let givenName: String?
    let familyName: String?
    let email: String?

    /// "Maria Silva", or nil when Apple sent no name.
    var fullName: String? {
        let parts = [givenName, familyName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
