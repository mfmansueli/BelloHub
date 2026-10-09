//
//  SystemAppleCredentialProvider.swift
//  BelloHub
//

import AuthenticationServices
import Foundation

/// The real implementation over `AuthenticationServices`. The native `SignInWithAppleButton` shows the sheet; this
/// type only configures its request and reads its answer.
@MainActor
final class SystemAppleCredentialProvider: AppleCredentialProviding {
    private let makeNonce: () -> AppleNonce
    private var pendingNonce: AppleNonce?

    init(makeNonce: @escaping () -> AppleNonce = { AppleNonce.make() }) {
        self.makeNonce = makeNonce
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = makeNonce()
        pendingNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce.hashed
    }

    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleCredential {
        let nonce = pendingNonce
        pendingNonce = nil
        switch result {
        case .failure(let error):
            throw AppleSignInErrorMapper.map(error)
        case .success(let authorization):
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce,
                  let tokenData = apple.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else { throw AuthError.appleFailed }
            return AppleCredential(
                userID: apple.user,
                identityToken: token,
                rawNonce: nonce.raw,
                authorizationCode: apple.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
                givenName: apple.fullName?.givenName,
                familyName: apple.fullName?.familyName,
                email: apple.email
            )
        }
    }
}
