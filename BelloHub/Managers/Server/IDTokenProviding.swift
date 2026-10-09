//
//  IDTokenProviding.swift
//  BelloHub
//

/// Where a call gets the professional's Firebase ID token. The app's implementation asks `SessionService`, which is the
/// only reader of the auth SDK; tests hand over a constant.
protocol IDTokenProviding: Sendable {
    /// A token that is valid now. Throws `ServerError.unauthenticated` when nobody is signed in.
    func idToken() async throws -> String
}
