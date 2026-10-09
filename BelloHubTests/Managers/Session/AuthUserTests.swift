//
//  AuthUserTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AuthUser")
struct AuthUserTests {
    @Test("A user saved before Apple sign-in existed decodes as a phone user")
    func legacyDecode() throws {
        let json = Data(#"{"id":"dev-1","phoneE164":"+5511987654321"}"#.utf8)
        let user = try JSONDecoder().decode(AuthUser.self, from: json)
        #expect(user == AuthUser(id: "dev-1", method: .phone, phoneE164: "+5511987654321"))
    }

    @Test("An Apple user has no phone and keeps its name through encoding")
    func appleRoundTrip() throws {
        let user = AuthUser(id: "a1", method: .apple, displayName: "Maria Silva")
        let decoded = try JSONDecoder().decode(AuthUser.self, from: JSONEncoder().encode(user))
        #expect(decoded == user)
        #expect(decoded.phoneE164 == nil)
    }

    @Test("The full name joins what Apple sent and is nil when it sent nothing")
    func fullName() {
        func credential(_ given: String?, _ family: String?) -> AppleCredential {
            AppleCredential(
                userID: "u", identityToken: "t", rawNonce: "n", authorizationCode: nil, givenName: given,
                familyName: family, email: nil
            )
        }
        #expect(credential("Maria", "Silva").fullName == "Maria Silva")
        #expect(credential("Maria", nil).fullName == "Maria")
        #expect(credential(" ", "").fullName == nil)
        #expect(credential(nil, nil).fullName == nil)
    }
}
