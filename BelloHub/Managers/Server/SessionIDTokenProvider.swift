//
//  SessionIDTokenProvider.swift
//  BelloHub
//

/// Reads the token through the `SessionService` (the single owner of the signed-in user), so the callable client never
/// touches the auth SDK.
struct SessionIDTokenProvider: IDTokenProviding {
    let session: SessionService

    func idToken() async throws -> String {
        try await session.idToken()
    }
}
