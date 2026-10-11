//
//  AccountDeletionRequest.swift
//  BelloHub
//

/// What the server needs to delete her account: who she is and, when she signed in with Apple (D44), a **fresh**
/// authorization code taken right before the call, so the backend can revoke the Apple token
/// (`deleteAccount.appleAuthorizationCode`, docs/agent-notes/backend-decisions.md section 5). Codes expire in five
/// minutes and are single-use, which is why the code is taken at the moment of deletion and never stored.
struct AccountDeletionRequest: Equatable, Sendable {
    let userID: String
    let appleAuthorizationCode: String?

    init(userID: String, appleAuthorizationCode: String? = nil) {
        self.userID = userID
        self.appleAuthorizationCode = appleAuthorizationCode
    }
}
