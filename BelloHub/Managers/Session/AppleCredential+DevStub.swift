//
//  AppleCredential+DevStub.swift
//  BelloHub
//

#if DEBUG
extension AppleCredential {
    /// The fixed Apple user of UI tests (`-uiTesting`): the system sheet cannot be driven by XCUITest, so the sign-in
    /// button hands this to `LocalDevAuthProvider` with no UI, like the phone code `123456`. The authorization code
    /// is what the account deletion of a UI test sends to the fake server; nothing exchanges it. DEBUG only.
    static let devStub = AppleCredential(
        userID: "000000.devapple", identityToken: "dev-token", rawNonce: "dev-nonce", authorizationCode: "dev-code",
        givenName: "Helena", familyName: "Duarte", email: "maria@example.com"
    )
}
#endif
