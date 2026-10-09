//
//  AppleCredentialProviderTests.swift
//  BelloHubTests
//

import AuthenticationServices
@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("SystemAppleCredentialProvider")
struct AppleCredentialProviderTests {
    @Test("The request asks for name and e-mail and carries the hashed nonce")
    func prepare() {
        let provider = SystemAppleCredentialProvider(makeNonce: { AppleNonce(raw: "raw-nonce") })
        let request = ASAuthorizationAppleIDProvider().createRequest()

        provider.prepare(request)

        #expect(request.requestedScopes == [.fullName, .email])
        #expect(request.nonce == AppleNonce.sha256("raw-nonce"))
    }

    @Test("Closing the sheet is a cancel, not a failure")
    func cancel() {
        let provider = SystemAppleCredentialProvider()
        #expect(throws: AuthError.cancelled) {
            try provider.credential(from: .failure(ASAuthorizationError(.canceled)))
        }
    }

    @Test("Other Apple errors and unknown errors are failures; a lost connection is the network")
    func mapper() {
        #expect(AppleSignInErrorMapper.map(ASAuthorizationError(.canceled)) == .cancelled)
        #expect(AppleSignInErrorMapper.map(ASAuthorizationError(.failed)) == .appleFailed)
        #expect(AppleSignInErrorMapper.map(ASAuthorizationError(.unknown)) == .appleFailed)
        #expect(AppleSignInErrorMapper.map(URLError(.notConnectedToInternet)) == .network)
        #expect(AppleSignInErrorMapper.map(AuthError.unavailable) == .unavailable)
        #expect(AppleSignInErrorMapper.map(CocoaError(.fileNoSuchFile)) == .appleFailed)
    }
}
