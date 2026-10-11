//
//  FakeAppleCredentialProvider.swift
//  BelloHubTests
//

import AuthenticationServices
@testable import BelloHub

/// Answers the Apple button with a scripted credential or error, so no sheet is involved.
@MainActor
final class FakeAppleCredentialProvider: AppleCredentialProviding {
    var credential: AppleCredential?
    var error: AuthError?
    private(set) var preparedCount = 0

    init(credential: AppleCredential? = FakeAppleCredentialProvider.sample, error: AuthError? = nil) {
        self.credential = credential
        self.error = error
    }

    static let sample = AppleCredential(
        userID: "001.apple", identityToken: "token", rawNonce: "nonce", authorizationCode: "code",
        givenName: "Maria", familyName: "Silva", email: "maria@example.com"
    )

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        preparedCount += 1
    }

    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleCredential {
        if let error { throw error }
        if case .failure(let failure) = result { throw AppleSignInErrorMapper.map(failure) }
        guard let credential else { throw AuthError.appleFailed }
        return credential
    }
}
